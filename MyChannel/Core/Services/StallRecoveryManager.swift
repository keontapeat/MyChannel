//
//  StallRecoveryManager.swift
//  MyChannel
//
//  Created by AI Assistant on 11/15/25.
//

import Foundation
import AVFoundation

/// 🔄 YouTube-Level Stall Recovery
/// Automatically recovers from video stalls with smart retry logic
@MainActor
class StallRecoveryManager: ObservableObject {
    static let shared = StallRecoveryManager()
    
    // MARK: - Properties
    private var stallCount: [String: Int] = [:] // videoId -> stall count
    private var isRecovering: [String: Bool] = [:]
    private var stallTimer: [String: Timer] = [:]
    
    // MARK: - Initialization
    private init() {
        print("✅ [StallRecovery] StallRecoveryManager initialized")
    }
    
    // MARK: - Recovery Methods
    
    /// Handle video stall with automatic recovery
    func handleStall(player: AVPlayer, video: Video) {
        let videoId = video.id
        
        // Check if already recovering
        guard isRecovering[videoId] != true else {
            print("⏳ [StallRecovery] Already recovering for: \(video.title)")
            return
        }
        
        // Increment stall count
        let currentStallCount = (stallCount[videoId] ?? 0) + 1
        stallCount[videoId] = currentStallCount
        
        print("⚠️ [StallRecovery] Video stalled (attempt \(currentStallCount)) for: \(video.title)")
        
        isRecovering[videoId] = true
        
        // Apply recovery strategy based on stall count
        if currentStallCount == 1 {
            // First stall: Wait 2 seconds and retry
            recoverWithWait(player: player, videoId: videoId, waitTime: 2.0)
        } else if currentStallCount == 2 {
            // Second stall: Drop quality and retry
            recoverWithQualityDrop(player: player, video: video)
        } else if currentStallCount >= 3 {
            // Third+ stall: Reload video
            recoverWithReload(player: player, video: video)
        }
    }
    
    /// Recovery Strategy 1: Wait and retry
    private func recoverWithWait(player: AVPlayer, videoId: String, waitTime: TimeInterval) {
        print("⏰ [StallRecovery] Waiting \(waitTime)s before retry")
        
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            guard let self = self else { return }
            
            player.play()
            self.isRecovering[videoId] = false
            
            print("▶️ [StallRecovery] Resumed playback after wait")
        }
    }
    
    /// Recovery Strategy 2: Drop quality
    private func recoverWithQualityDrop(player: AVPlayer, video: Video) {
        print("📉 [StallRecovery] Dropping quality to recover")
        
        guard let playerItem = player.currentItem else {
            isRecovering[video.id] = false
            return
        }
        
        // Drop to 480p (1.5 Mbps)
        playerItem.preferredPeakBitRate = 1_500_000
        
        #if os(iOS)
        playerItem.preferredMaximumResolution = CGSize(width: 854, height: 480)
        #endif
        
        // Resume playback
        player.play()
        isRecovering[video.id] = false
        
        print("✅ [StallRecovery] Dropped to 480p and resumed")
    }
    
    /// Recovery Strategy 3: Reload video
    private func recoverWithReload(player: AVPlayer, video: Video) {
        print("🔄 [StallRecovery] Reloading video from current position")
        
        // Save current playback position
        let currentTime = player.currentTime()
        
        // Create new player item
        guard let url = URL(string: video.videoURL) else {
            isRecovering[video.id] = false
            stallCount[video.id] = 0
            return
        }
        
        let asset = AVURLAsset(url: url)
        let newItem = AVPlayerItem(asset: asset)
        newItem.preferredForwardBufferDuration = 2.0 // Conservative buffer
        newItem.preferredPeakBitRate = 1_500_000 // Start at lower quality
        
        // Replace item and seek to previous position
        player.replaceCurrentItem(with: newItem)
        player.seek(to: currentTime) { [weak self] finished in
            guard let self = self, finished else { return }
            
            player.play()
            self.isRecovering[video.id] = false
            
            print("✅ [StallRecovery] Reloaded video and resumed from \(CMTimeGetSeconds(currentTime))s")
        }
    }
    
    /// Reset stall count for video
    func resetStallCount(for videoId: String) {
        stallCount[videoId] = 0
        isRecovering[videoId] = false
        stallTimer[videoId]?.invalidate()
        stallTimer[videoId] = nil
        
        print("🔄 [StallRecovery] Reset stall count for: \(videoId)")
    }
    
    /// Monitor player for stalls
    func monitorForStalls(player: AVPlayer, video: Video) {
        let videoId = video.id
        
        // Invalidate existing timer
        stallTimer[videoId]?.invalidate()
        
        // Create timer to detect stalls
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, weak player] _ in
            guard let self = self, let player = player else { return }
            
            // Check if player is stalled
            let isStalled = player.rate == 0 && player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            
            if isStalled {
                self.handleStall(player: player, video: video)
            }
        }
        
        stallTimer[videoId] = timer
        
        print("👁️ [StallRecovery] Monitoring for stalls: \(video.title)")
    }
    
    /// Stop monitoring
    func stopMonitoring(for videoId: String) {
        stallTimer[videoId]?.invalidate()
        stallTimer[videoId] = nil
        
        print("🛑 [StallRecovery] Stopped monitoring: \(videoId)")
    }
    
    deinit {
        // Clean up all timers
        stallTimer.values.forEach { $0.invalidate() }
    }
}

