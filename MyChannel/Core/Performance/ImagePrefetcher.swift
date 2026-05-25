//
//  ImagePrefetcher.swift
//  MyChannel
//
//  🔥🔥🔥 THERMONUCLEAR IMAGE PREFETCHER 🔥🔥🔥
//  Load images ahead of time for INSTANT scrolling
//

import Foundation
import UIKit

@MainActor
class ImagePrefetcher {
    static let shared = ImagePrefetcher()
    
    private var activePrefetches: Set<URL> = []
    private var currentPrefetchTasks: [URL: Task<Void, Never>] = [:]
    
    // 🔥 THERMONUCLEAR: High-performance shared session with aggressive connection pooling
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = 10 // 🔥 10 parallel connections!
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        config.urlCache = nil // No disk cache overhead
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpShouldUsePipelining = true // 🔥 HTTP pipelining for speed
        return URLSession(configuration: config)
    }()
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    /// 🔥 Prefetch a single image URL (non-blocking, deduplicated)
    func prefetch(url: URL) {
        // Skip if already prefetching or cached
        guard !activePrefetches.contains(url),
              !ImageCache.shared.hasImage(for: url) else { return }
        
        activePrefetches.insert(url)
        
        let task = Task { [weak self] in
            defer {
                Task { @MainActor [weak self] in
                    self?.activePrefetches.remove(url)
                    self?.currentPrefetchTasks.removeValue(forKey: url)
                }
            }
            
            // 🔥 Parse image on background thread
            do {
                let (data, _) = try await self?.session.data(from: url) ?? (Data(), URLResponse())
                
                // Parse on background thread for speed
                let image = await Task.detached(priority: .utility) {
                    UIImage(data: data)
                }.value
                
                if let image = image {
                    await MainActor.run {
                        ImageCache.shared.store(image, for: url)
                    }
                }
            } catch {
                // Silently fail - prefetching is best effort
            }
        }
        
        currentPrefetchTasks[url] = task
    }
    
    /// 🔥🔥🔥 THERMONUCLEAR BATCH PREFETCH - Load 20 images in PARALLEL! 🔥🔥🔥
    func prefetch(urls: [URL], priority: Int = 0) {
        // 🔥 Fire off all prefetches in parallel (up to 20)
        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in urls.prefix(20) {
                    group.addTask { @MainActor [weak self] in
                        self?.prefetch(url: url)
                    }
                }
            }
        }
    }
    
    /// 🔥🔥🔥 NUCLEAR VIEWPORT PREFETCH - 3 screens ahead! 🔥🔥🔥
    func prefetchViewport(urls: [URL], visibleRange: Range<Int>) {
        // Prefetch visible + next 36 items (3 screens ahead!)
        let prefetchEnd = min(urls.count, visibleRange.upperBound + 36)
        let prefetchStart = max(0, visibleRange.lowerBound - 12) // Also prefetch 1 screen behind
        let prefetchRange = prefetchStart..<prefetchEnd
        
        let urlsToPrefetch = prefetchRange.compactMap { index -> URL? in
            guard index < urls.count else { return nil }
            return urls[index]
        }
        
        prefetch(urls: urlsToPrefetch)
    }
    
    /// 🔥 INSTANT PREWARM - Load critical images before view appears
    func prewarmCritical(urls: [URL]) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in urls.prefix(10) {
                    // Skip if already cached
                    if ImageCache.shared.hasImage(for: url) { continue }
                    
                    group.addTask { [weak self] in
                        do {
                            let (data, _) = try await self?.session.data(from: url) ?? (Data(), URLResponse())
                            
                            let image = await Task.detached(priority: .userInitiated) {
                                UIImage(data: data)
                            }.value
                            
                            if let image = image {
                                await MainActor.run {
                                    ImageCache.shared.store(image, for: url)
                                }
                            }
                        } catch {}
                    }
                }
            }
            print("🔥🔥🔥 [ImagePrefetcher] Prewarmed \(min(urls.count, 10)) critical images!")
        }
    }
    
    /// Cancel all prefetches
    func cancelAll() {
        currentPrefetchTasks.values.forEach { $0.cancel() }
        currentPrefetchTasks.removeAll()
        activePrefetches.removeAll()
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.cancelAll()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - 🔥🔥🔥 THERMONUCLEAR IMAGE CACHE 🔥🔥🔥
class ImageCache {
    static let shared = ImageCache()
    
    // 🔥 Larger cache for more instant hits
    let cache = NSCache<NSURL, UIImage>()
    private let maxCacheSize = 150 * 1024 * 1024 // 150MB (was 100MB)
    
    // 🔥 Track cache stats for debugging
    private var hits = 0
    private var misses = 0
    
    private init() {
        cache.totalCostLimit = maxCacheSize
        cache.countLimit = 300 // Max 300 images (was 200)
        setupMemoryWarningObserver()
        print("🔥 [ImageCache] THERMONUCLEAR cache initialized: 150MB, 300 images")
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("⚠️ [ImageCache] Memory warning - clearing 50% of cache")
            // 🔥 Don't clear everything - just reduce
            self?.cache.totalCostLimit = self?.maxCacheSize ?? 0 / 2
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self?.cache.totalCostLimit = self?.maxCacheSize ?? 0
            }
        }
    }
    
    // 🔥 INSTANT: O(1) lookup
    func hasImage(for url: URL) -> Bool {
        let has = cache.object(forKey: url as NSURL) != nil
        return has
    }
    
    func store(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
    
    // 🔥 Track cache performance
    func image(for url: URL) -> UIImage? {
        if let img = cache.object(forKey: url as NSURL) {
            hits += 1
            return img
        }
        misses += 1
        return nil
    }
    
    func remove(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }

    func clearCache() {
        cache.removeAllObjects()
        print("✅ [ImageCache] Cache cleared (was \(hits) hits, \(misses) misses)")
        hits = 0
        misses = 0
    }
    
    // 🔥 Cache stats for debugging
    var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) : 0
    }
}

