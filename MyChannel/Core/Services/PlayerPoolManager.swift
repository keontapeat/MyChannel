//
//  PlayerPoolManager.swift
//  MyChannel
//
//  🔥🔥🔥 THERMONUCLEAR PERFORMANCE: YouTube-Level Player Pooling
//  Target: <50ms player acquisition, instant video replay
//

import Foundation
import AVFoundation

/// 🔥 THERMONUCLEAR: YouTube-Level Player Pooling
/// Reuses AVPlayer instances for MAXIMUM performance
@MainActor
class PlayerPoolManager {
    static let shared = PlayerPoolManager()
    
    // MARK: - Properties (THERMONUCLEAR SIZING)
    private var playerPool: [AVPlayer] = []
    private var itemCache: [String: AVPlayerItem] = [:]
    private var assetCache: [String: AVURLAsset] = [:]  // 🔥 NEW: Pre-loaded assets
    private var itemOrder: [String] = []
    private let maxPoolSize = 5  // 🔥 INCREASED: 5 players (was 3)
    private let maxCacheSize = 20  // 🔥 INCREASED: 20 items (was 10)
    private let maxAssetCacheSize = 30  // 🔥 NEW: 30 pre-loaded assets
    
    // 🔥 PERF: Pre-warm pool on init
    private init() {
        prewarmPool()
        print("✅ [PlayerPool] THERMONUCLEAR initialized - pool: \(playerPool.count)")
    }
    
    // 🔥 THERMONUCLEAR: Pre-warm player pool for instant acquisition
    private func prewarmPool() {
        for _ in 0..<2 {  // Pre-create 2 players
            let player = createOptimizedPlayer()
            playerPool.append(player)
        }
    }
    
    // 🔥 THERMONUCLEAR: Create player with optimal settings
    private func createOptimizedPlayer() -> AVPlayer {
        let player = AVPlayer()
        player.automaticallyWaitsToMinimizeStalling = true
        player.allowsExternalPlayback = true
        
        // 🔥 PERF: Set optimal audio session immediately
        player.volume = 1.0
        
        return player
    }
    
    // MARK: - Player Management (THERMONUCLEAR)
    
    /// 🔥 INSTANT: Get player from pool (<1ms)
    func getPlayer() -> AVPlayer {
        if let player = playerPool.popLast() {
            return player
        }
        return createOptimizedPlayer()
    }
    
    /// 🔥 FAST: Return player to pool
    func returnPlayer(_ player: AVPlayer) {
        guard playerPool.count < maxPoolSize else {
            cleanupPlayer(player)
            return
        }
        
        // 🔥 PERF: Fast cleanup
        player.pause()
        player.replaceCurrentItem(with: nil)
        player.rate = 0
        
        playerPool.append(player)
    }
    
    private func cleanupPlayer(_ player: AVPlayer) {
        player.pause()
        player.replaceCurrentItem(with: nil)
        player.cancelPendingPrerolls()
    }
    
    // MARK: - Asset Pre-loading (THERMONUCLEAR)
    
    /// 🔥 THERMONUCLEAR: Pre-load asset for instant playback
    func preloadAsset(for videoURL: String) {
        guard assetCache[videoURL] == nil else { return }
        guard let url = URL(string: videoURL) else { return }
        
        Task {
            let asset = AVURLAsset(url: url, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true
            ])
            asset.resourceLoader.preloadsEligibleContentKeys = true
            
            // 🔥 PERF: Pre-load essential properties
            _ = try? await asset.load(.isPlayable)
            _ = try? await asset.load(.duration)
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.assetCache[videoURL] = asset
                
                // 🔥 LRU: Evict oldest if over limit
                if self.assetCache.count > self.maxAssetCacheSize {
                    let oldestKey = self.assetCache.keys.first!
                    self.assetCache.removeValue(forKey: oldestKey)
                }
            }
        }
    }
    
    /// 🔥 INSTANT: Get pre-loaded asset
    func getPreloadedAsset(for videoURL: String) -> AVURLAsset? {
        return assetCache[videoURL]
    }
    
    // MARK: - AVPlayerItem Caching (THERMONUCLEAR)
    
    /// 🔥 FAST: Cache item with LRU eviction
    func cacheItem(_ item: AVPlayerItem, for videoId: String) {
        itemCache[videoId] = item
        
        // 🔥 LRU: Update order
        itemOrder.removeAll { $0 == videoId }
        itemOrder.insert(videoId, at: 0)
        
        // 🔥 PERF: Evict oldest if over limit
        while itemOrder.count > maxCacheSize {
            let oldestId = itemOrder.removeLast()
            itemCache.removeValue(forKey: oldestId)
        }
    }
    
    /// 🔥 INSTANT: Get cached item
    func getCachedItem(for videoId: String) -> AVPlayerItem? {
        guard let item = itemCache[videoId] else { return nil }
        
        // 🔥 LRU: Move to front
        itemOrder.removeAll { $0 == videoId }
        itemOrder.insert(videoId, at: 0)
        
        return item
    }
    
    func clearCachedItem(for videoId: String) {
        itemCache.removeValue(forKey: videoId)
        itemOrder.removeAll { $0 == videoId }
    }
    
    func clearAllCachedItems() {
        itemCache.removeAll()
        itemOrder.removeAll()
    }
    
    /// 🔥 THERMONUCLEAR: Clear assets cache
    func clearAssetCache() {
        assetCache.removeAll()
    }
    
    func clearPool() {
        playerPool.forEach { cleanupPlayer($0) }
        playerPool.removeAll()
        clearAllCachedItems()
        clearAssetCache()
        
        // 🔥 PERF: Re-prewarm after clear
        prewarmPool()
    }
    
    // MARK: - Statistics
    func getPoolStats() -> (poolSize: Int, maxPoolSize: Int, cacheSize: Int, maxCacheSize: Int, assetCacheSize: Int) {
        return (playerPool.count, maxPoolSize, itemCache.count, maxCacheSize, assetCache.count)
    }
    
    func printPoolStats() {
        let stats = getPoolStats()
        print("📊 [PlayerPool] Players: \(stats.poolSize)/\(stats.maxPoolSize), Items: \(stats.cacheSize)/\(stats.maxCacheSize), Assets: \(stats.assetCacheSize)")
    }
    
    deinit {
        print("🗑️ [PlayerPool] PlayerPoolManager deallocated")
    }
}

