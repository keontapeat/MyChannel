//
//  PlayerPoolManager.swift
//  MyChannel
//
//  Created by AI Assistant on 11/15/25.
//

import Foundation
import AVFoundation

/// ♻️ YouTube-Level Player Pooling
/// Reuses AVPlayer instances for better performance
@MainActor
class PlayerPoolManager {
    static let shared = PlayerPoolManager()
    
    // MARK: - Properties
    private var playerPool: [AVPlayer] = []
    private var itemCache: [String: AVPlayerItem] = [:]
    private var itemOrder: [String] = []
    private let maxPoolSize = 3
    private let maxCacheSize = 10
    
    // MARK: - Initialization
    private init() {
        print("✅ [PlayerPool] PlayerPoolManager initialized")
    }
    
    // MARK: - Player Management
    
    /// Get or create a player from pool
    func getPlayer() -> AVPlayer {
        if let player = playerPool.popLast() {
            print("♻️ [PlayerPool] Reusing player from pool (pool size: \(playerPool.count))")
            return player
        }
        
        // Create new player with optimized settings
        let player = AVPlayer()
        player.automaticallyWaitsToMinimizeStalling = true
        player.allowsExternalPlayback = true
        
        print("✨ [PlayerPool] Created new player (pool empty)")
        return player
    }
    
    /// Return player to pool for reuse
    func returnPlayer(_ player: AVPlayer) {
        guard playerPool.count < maxPoolSize else {
            print("🗑️ [PlayerPool] Pool full (\(maxPoolSize)), discarding player")
            cleanupPlayer(player)
            return
        }
        
        // Clean up player state
        player.pause()
        player.replaceCurrentItem(with: nil)
        player.rate = 0
        
        // Add back to pool
        playerPool.append(player)
        print("♻️ [PlayerPool] Returned player to pool (pool size: \(playerPool.count))")
    }
    
    /// Cleanup player completely
    private func cleanupPlayer(_ player: AVPlayer) {
        player.pause()
        player.replaceCurrentItem(with: nil)
        player.cancelPendingPrerolls()
    }
    
    // MARK: - AVPlayerItem Caching
    
    /// Cache AVPlayerItem for instant replay
    func cacheItem(_ item: AVPlayerItem, for videoId: String) {
        // Add to cache
        itemCache[videoId] = item
        itemOrder.append(videoId)
        
        // Enforce cache size limit (LRU)
        if itemOrder.count > maxCacheSize {
            // Remove oldest
            let oldestId = itemOrder.removeFirst()
            itemCache.removeValue(forKey: oldestId)
            print("🗑️ [PlayerPool] Evicted oldest cached item: \(oldestId)")
        }
        
        print("💾 [PlayerPool] Cached item for: \(videoId) (cache size: \(itemCache.count))")
    }
    
    /// Get cached AVPlayerItem
    func getCachedItem(for videoId: String) -> AVPlayerItem? {
        let item = itemCache[videoId]
        
        if item != nil {
            print("🎯 [PlayerPool] Cache hit for: \(videoId)")
        }
        
        return item
    }
    
    /// Clear cached item
    func clearCachedItem(for videoId: String) {
        itemCache.removeValue(forKey: videoId)
        if let index = itemOrder.firstIndex(of: videoId) {
            itemOrder.remove(at: index)
        }
        print("🗑️ [PlayerPool] Cleared cached item: \(videoId)")
    }
    
    /// Clear all cached items
    func clearAllCachedItems() {
        itemCache.removeAll()
        itemOrder.removeAll()
        print("🧹 [PlayerPool] Cleared all cached items")
    }
    
    /// Clear entire pool
    func clearPool() {
        // Cleanup all players
        playerPool.forEach { cleanupPlayer($0) }
        playerPool.removeAll()
        
        // Clear caches
        clearAllCachedItems()
        
        print("🧹 [PlayerPool] Cleared entire pool")
    }
    
    // MARK: - Cache Statistics
    func getPoolStats() -> (poolSize: Int, maxPoolSize: Int, cacheSize: Int, maxCacheSize: Int) {
        return (playerPool.count, maxPoolSize, itemCache.count, maxCacheSize)
    }
    
    func printPoolStats() {
        let stats = getPoolStats()
        print("📊 [PlayerPool] Players: \(stats.poolSize)/\(stats.maxPoolSize), Cache: \(stats.cacheSize)/\(stats.maxCacheSize)")
    }
    
    deinit {
        clearPool()
    }
}

