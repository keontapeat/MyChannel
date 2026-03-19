//
//  VideoPlayerOptimizer.swift
//  MyChannel
//
//  📺 VIDEO PLAYER PERFORMANCE OPTIMIZATION
//  Player pooling, buffer management, and instant playback
//

import Foundation
import AVFoundation
import SwiftUI

// MARK: - Player Pool Manager
@MainActor
class VideoPlayerPool: ObservableObject {
    static let shared = VideoPlayerPool()
    
    private var availablePlayers: [AVPlayer] = []
    private var activePlayers: [String: AVPlayer] = [:]
    private let maxPoolSize = 3
    
    @Published var activePlayerCount: Int = 0
    
    private init() {
        setupPlayerPool()
    }
    
    // MARK: - Pool Management
    
    private func setupPlayerPool() {
        // Pre-create players for instant playback
        for _ in 0..<maxPoolSize {
            let player = createOptimizedPlayer()
            availablePlayers.append(player)
        }
        print("📺 [PlayerPool] Initialized with \(maxPoolSize) pre-warmed players")
    }
    
    private func createOptimizedPlayer() -> AVPlayer {
        let player = AVPlayer()
        
        // Optimize for low latency
        player.automaticallyWaitsToMinimizeStalling = false
        
        // Enable Picture-in-Picture
        if #available(iOS 14.0, *) {
            player.allowsExternalPlayback = true
        }
        
        return player
    }
    
    // MARK: - Player Acquisition
    
    func acquirePlayer(for videoId: String) -> AVPlayer {
        // Return existing player if already active
        if let existingPlayer = activePlayers[videoId] {
            return existingPlayer
        }
        
        // Get player from pool or create new one
        let player: AVPlayer
        if let pooledPlayer = availablePlayers.popLast() {
            player = pooledPlayer
            print("📺 [PlayerPool] Reusing pooled player for \(videoId)")
        } else {
            player = createOptimizedPlayer()
            print("📺 [PlayerPool] Creating new player for \(videoId)")
        }
        
        activePlayers[videoId] = player
        activePlayerCount = activePlayers.count
        
        return player
    }
    
    func releasePlayer(for videoId: String) {
        guard let player = activePlayers.removeValue(forKey: videoId) else { return }
        
        // Clean up player
        player.pause()
        player.replaceCurrentItem(with: nil)
        
        // Return to pool if not full
        if availablePlayers.count < maxPoolSize {
            availablePlayers.append(player)
            print("📺 [PlayerPool] Returned player to pool")
        }
        
        activePlayerCount = activePlayers.count
    }
    
    func releaseAllPlayers() {
        for (videoId, _) in activePlayers {
            releasePlayer(for: videoId)
        }
    }
}

// MARK: - Video Buffer Optimizer

class VideoBufferOptimizer {
    static let shared = VideoBufferOptimizer()
    
    private var bufferObservers: [String: Any] = [:]
    
    private init() {}
    
    func optimizeBuffer(for playerItem: AVPlayerItem, videoId: String) {
        // Configure buffer settings
        playerItem.preferredForwardBufferDuration = 10.0 // 10 seconds ahead
        
        // Monitor buffer status
        let observer = playerItem.observe(\.isPlaybackBufferFull, options: [.new]) { item, change in
            if let isFull = change.newValue, isFull {
                print("📺 [Buffer] Buffer full for \(videoId)")
            }
        }
        
        bufferObservers[videoId] = observer
    }
    
    func removeObserver(for videoId: String) {
        bufferObservers.removeValue(forKey: videoId)
    }
}

// MARK: - Seek Performance Optimizer

class SeekPerformanceOptimizer {
    static let shared = SeekPerformanceOptimizer()
    
    private var seekDebounceTimers: [String: Timer] = [:]
    
    private init() {}
    
    func optimizedSeek(
        player: AVPlayer,
        to time: CMTime,
        videoId: String,
        completion: @escaping () -> Void
    ) {
        // Cancel previous seek if still pending
        seekDebounceTimers[videoId]?.invalidate()
        
        // Debounce rapid seeks
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            let startTime = Date()
            
            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                if finished {
                    let seekTime = Date().timeIntervalSince(startTime)
                    print("📺 [Seek] Completed in \(Int(seekTime * 1000))ms")
                    completion()
                }
            }
            
            self?.seekDebounceTimers.removeValue(forKey: videoId)
        }
        
        seekDebounceTimers[videoId] = timer
    }
}

// MARK: - Adaptive Bitrate Manager

@MainActor
class AdaptiveBitrateManager: ObservableObject {
    static let shared = AdaptiveBitrateManager()
    
    @Published var currentQuality: VideoQuality = .auto
    @Published var availableQualities: [VideoQuality] = []
    
    enum VideoQuality: String, CaseIterable {
        case auto = "Auto"
        case p2160 = "2160p"
        case p1440 = "1440p"
        case p1080 = "1080p"
        case p720 = "720p"
        case p480 = "480p"
        case p360 = "360p"
        case p240 = "240p"
        case p144 = "144p"
        
        var bitrate: Double {
            switch self {
            case .auto: return 0
            case .p2160: return 20_000_000
            case .p1440: return 10_000_000
            case .p1080: return 5_000_000
            case .p720: return 2_500_000
            case .p480: return 1_000_000
            case .p360: return 500_000
            case .p240: return 300_000
            case .p144: return 150_000
            }
        }
    }
    
    private init() {}
    
    func selectOptimalQuality(networkSpeed: Double, deviceMemory: MemoryTier) -> VideoQuality {
        // Network-aware quality selection
        if networkSpeed > 15_000_000 && deviceMemory == .ultra {
            return .p1080
        } else if networkSpeed > 8_000_000 {
            return .p720
        } else if networkSpeed > 3_000_000 {
            return .p480
        } else {
            return .p360
        }
    }
    
    func configurePlayer(_ player: AVPlayer, quality: VideoQuality) {
        guard quality != .auto else { return }
        
        // Set preferred peak bitrate
        player.currentItem?.preferredPeakBitRate = quality.bitrate
        print("📺 [Quality] Set to \(quality.rawValue) (\(Int(quality.bitrate / 1_000_000))Mbps)")
    }
}

// MARK: - Performance Metrics

struct VideoPerformanceMetrics {
    var timeToFirstFrame: TimeInterval = 0
    var bufferingEvents: Int = 0
    var totalBufferingTime: TimeInterval = 0
    var averageSeekTime: TimeInterval = 0
    var droppedFrames: Int = 0
}

@MainActor
class VideoPerformanceTracker: ObservableObject {
    static let shared = VideoPerformanceTracker()
    
    @Published var metrics: [String: VideoPerformanceMetrics] = [:]
    
    private init() {}
    
    func trackFirstFrame(videoId: String, duration: TimeInterval) {
        var metric = metrics[videoId] ?? VideoPerformanceMetrics()
        metric.timeToFirstFrame = duration
        metrics[videoId] = metric
        
        print("📺 [Performance] First frame in \(Int(duration * 1000))ms")
    }
    
    func trackBufferingEvent(videoId: String, duration: TimeInterval) {
        var metric = metrics[videoId] ?? VideoPerformanceMetrics()
        metric.bufferingEvents += 1
        metric.totalBufferingTime += duration
        metrics[videoId] = metric
        
        print("📺 [Performance] Buffering event: \(Int(duration * 1000))ms")
    }
    
    func printSummary(videoId: String) {
        guard let metric = metrics[videoId] else { return }
        
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📺 VIDEO PERFORMANCE SUMMARY: \(videoId)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Time to First Frame:  \(Int(metric.timeToFirstFrame * 1000))ms")
        print("Buffering Events:     \(metric.bufferingEvents)")
        print("Total Buffering Time: \(Int(metric.totalBufferingTime * 1000))ms")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
}
