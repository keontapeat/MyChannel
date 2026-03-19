//
//  VideoPreloadManager.swift
//  MyChannel
//
//  Created by AI Assistant on 11/15/25.
//

import Foundation
import AVFoundation
import Combine

/// 🚀 YouTube-Level Video Preloading
/// Preloads next 3 videos in feed for instant playback
@MainActor
class VideoPreloadManager: ObservableObject {
    static let shared = VideoPreloadManager()
    
    // MARK: - Properties
    private var preloadedItems: [String: AVPlayerItem] = [:]
    private var preloadOrder: [String] = []
    private let maxPreloadItems = 5
    private var isPreloading = false
    
    // MARK: - Initialization
    private init() {
        print("✅ [Preload] VideoPreloadManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Preload videos that are likely to be watched next
    func preloadVideos(_ videos: [Video]) {
        guard !isPreloading else { return }
        isPreloading = true
        
        print("🚀 [Preload] Starting to preload \(videos.count) videos")
        
        // Preload first 3 videos in feed
        for video in videos.prefix(3) {
            preloadVideo(video)
        }
        
        isPreloading = false
    }
    
    /// Preload a single video by URL and ID (convenience for non-Video callers)
    func preloadVideo(url: URL, videoId: String) {
        guard preloadedItems[videoId] == nil else { return }

        print("📥 [Preload] Preloading: \(videoId)")

        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ])
        asset.resourceLoader.preloadsEligibleContentKeys = true

        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 3.0

        preloadedItems[videoId] = playerItem
        preloadOrder.append(videoId)

        if preloadedItems.count > maxPreloadItems {
            if let oldestId = preloadOrder.first {
                preloadedItems.removeValue(forKey: oldestId)
                preloadOrder.removeFirst()
            }
        }

        print("✅ [Preload] Cached item for: \(videoId)")
    }

    /// Preload a single video
    func preloadVideo(_ video: Video) {
        // Skip if already preloaded
        guard preloadedItems[video.id] == nil else {
            print("⏭️ [Preload] Already preloaded: \(video.title)")
            return
        }
        
        guard let url = URL(string: video.videoURL) else {
            print("❌ [Preload] Invalid URL for: \(video.title)")
            return
        }
        
        print("📥 [Preload] Preloading: \(video.title)")
        
        // Create asset with preloading enabled
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ])
        asset.resourceLoader.preloadsEligibleContentKeys = true
        
        // Create player item with minimal buffer (just for preloading)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 3.0 // 3 seconds for preload
        
        // Store in cache
        preloadedItems[video.id] = playerItem
        preloadOrder.append(video.id)
        
        // Enforce cache size limit
        if preloadedItems.count > maxPreloadItems {
            // Remove oldest
            if let oldestId = preloadOrder.first {
                preloadedItems.removeValue(forKey: oldestId)
                preloadOrder.removeFirst()
                print("🗑️ [Preload] Removed oldest preload: \(oldestId)")
            }
        }
        
        print("✅ [Preload] Cached item for: \(video.title)")
    }
    
    /// Get preloaded player item
    func getPreloadedItem(for videoId: String) -> AVPlayerItem? {
        let item = preloadedItems[videoId]
        
        if item != nil {
            print("🎯 [Preload] Hit! Using preloaded item for: \(videoId)")
        } else {
            print("⚠️ [Preload] Miss! No preloaded item for: \(videoId)")
        }
        
        return item
    }
    
    /// Clear all preloaded items
    func clearCache() {
        preloadedItems.removeAll()
        preloadOrder.removeAll()
        print("🧹 [Preload] Cache cleared")
    }
    
    /// Clear specific video from cache
    func clearPreload(for videoId: String) {
        preloadedItems.removeValue(forKey: videoId)
        if let index = preloadOrder.firstIndex(of: videoId) {
            preloadOrder.remove(at: index)
        }
        print("🗑️ [Preload] Cleared preload for: \(videoId)")
    }
    
    // MARK: - Cache Stats
    func getCacheStats() -> (cached: Int, max: Int) {
        return (preloadedItems.count, maxPreloadItems)
    }
    
    func printCacheStatus() {
        print("📊 [Preload] Cache: \(preloadedItems.count)/\(maxPreloadItems) items")
        print("📋 [Preload] Order: \(preloadOrder)")
    }
}

