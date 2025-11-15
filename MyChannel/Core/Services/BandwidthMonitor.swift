//
//  BandwidthMonitor.swift
//  MyChannel
//
//  Created by AI Assistant on 11/15/25.
//

import Foundation
import AVFoundation
import Combine

/// 📊 YouTube-Level Bandwidth Monitoring
/// Tracks available bandwidth and adjusts quality automatically
@MainActor
class BandwidthMonitor: ObservableObject {
    static let shared = BandwidthMonitor()
    
    // MARK: - Published Properties
    @Published var estimatedBandwidth: Double = 0 // bps
    @Published var isThrottled: Bool = false
    @Published var recommendedQuality: VideoQuality = .quality720p
    
    // MARK: - Private Properties
    private var observations: [Double] = []
    private var isMonitoring = false
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        print("✅ [Bandwidth] BandwidthMonitor initialized")
    }
    
    // MARK: - Monitoring
    
    /// Start monitoring bandwidth for a player
    func startMonitoring(player: AVPlayer) {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        print("📊 [Bandwidth] Starting bandwidth monitoring")
        
        // Monitor AVPlayerItem access log
        NotificationCenter.default.publisher(for: .AVPlayerItemNewAccessLogEntry, object: player.currentItem)
            .sink { [weak self] _ in
                self?.updateBandwidthEstimate(player: player)
            }
            .store(in: &cancellables)
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        isMonitoring = false
        cancellables.removeAll()
        print("🛑 [Bandwidth] Stopped bandwidth monitoring")
    }
    
    /// Update bandwidth estimate from player stats
    private func updateBandwidthEstimate(player: AVPlayer) {
        guard let accessLog = player.currentItem?.accessLog(),
              let lastEvent = accessLog.events.last else { return }
        
        // Get observed bitrate
        let observedBitrate = lastEvent.observedBitrate
        
        guard observedBitrate > 0 else { return }
        
        // Add to observations
        observations.append(observedBitrate)
        
        // Keep last 10 observations for smoothing
        if observations.count > 10 {
            observations.removeFirst()
        }
        
        // Calculate average bandwidth
        estimatedBandwidth = observations.reduce(0, +) / Double(observations.count)
        
        // Detect throttling (less than 1 Mbps)
        isThrottled = estimatedBandwidth < 1_000_000
        
        // Recommend quality based on bandwidth
        updateRecommendedQuality()
        
        print("📊 [Bandwidth] Estimated: \(String(format: "%.2f", estimatedBandwidth / 1_000_000)) Mbps, Throttled: \(isThrottled)")
    }
    
    /// Update recommended quality based on bandwidth
    private func updateRecommendedQuality() {
        let mbps = estimatedBandwidth / 1_000_000
        
        if mbps >= 8.0 {
            recommendedQuality = .quality1080p
        } else if mbps >= 5.0 {
            recommendedQuality = .quality720p
        } else if mbps >= 2.5 {
            recommendedQuality = .quality480p
        } else if mbps >= 1.0 {
            recommendedQuality = .quality360p
        } else {
            recommendedQuality = .quality240p
        }
        
        print("💡 [Bandwidth] Recommended quality: \(recommendedQuality.rawValue)")
    }
    
    /// Get bandwidth status for UI
    func getBandwidthStatus() -> String {
        let mbps = estimatedBandwidth / 1_000_000
        
        if mbps >= 10.0 {
            return "Excellent (\(String(format: "%.1f", mbps)) Mbps)"
        } else if mbps >= 5.0 {
            return "Good (\(String(format: "%.1f", mbps)) Mbps)"
        } else if mbps >= 2.0 {
            return "Fair (\(String(format: "%.1f", mbps)) Mbps)"
        } else if mbps > 0 {
            return "Poor (\(String(format: "%.1f", mbps)) Mbps)"
        } else {
            return "Unknown"
        }
    }
    
    deinit {
        stopMonitoring()
    }
}

