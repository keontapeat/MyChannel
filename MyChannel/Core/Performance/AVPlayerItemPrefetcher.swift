import Foundation
import AVFoundation

/// Intelligently pre-buffers the next videos in a feed to ensure instant playback without stalling.
actor AVPlayerItemPrefetcher {
    static let shared = AVPlayerItemPrefetcher()
    
    private var prefetchTasks: [String: Task<Void, Never>] = [:]
    
    private init() {}
    
    /// Prefetch a list of URLs (e.g., the next 3 videos in the infinite scroll feed)
    func prefetch(urls: [String]) {
        for url in urls {
            // If we are already prefetching this URL, skip
            guard prefetchTasks[url] == nil else { continue }
            
            // Start a low-priority task to warm up the asset in the cache
            let task = Task.detached(priority: .utility) {
                // This call goes to our LRU actor cache, which internally loads .tracks and .isPlayable
                _ = await LoopAssetCache.shared.asset(for: url)
            }
            prefetchTasks[url] = task
        }
    }
    
    /// Cancel prefetching for URLs that have fallen out of the prefetch window
    func cancelPrefetching(for urls: [String]) {
        for url in urls {
            if let task = prefetchTasks.removeValue(forKey: url) {
                task.cancel()
            }
        }
    }
    
    /// Clear all prefetch tasks (e.g., when the feed is closed)
    func clearAll() {
        for task in prefetchTasks.values {
            task.cancel()
        }
        prefetchTasks.removeAll()
    }
}
