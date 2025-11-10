//
//  ImagePrefetcher.swift
//  MyChannel
//
//  ⚡ IMAGE PREFETCHER - Load images ahead of time for smooth scrolling
//

import Foundation
import UIKit

@MainActor
class ImagePrefetcher {
    static let shared = ImagePrefetcher()
    
    private var prefetchQueue: [URL] = []
    private var activePrefetches: Set<URL> = []
    private let maxConcurrentPrefetches = 3
    private var currentPrefetchTasks: [URL: Task<Void, Never>] = [:]
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    /// Prefetch an image URL (non-blocking)
    func prefetch(url: URL) {
        guard !activePrefetches.contains(url) else { return }
        
        activePrefetches.insert(url)
        
        let task = Task {
            defer {
                activePrefetches.remove(url)
                currentPrefetchTasks.removeValue(forKey: url)
            }
            
            // Check cache first
            if ImageCache.shared.hasImage(for: url) {
                return
            }
            
            // Prefetch image
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    ImageCache.shared.store(image, for: url)
                    print("✅ [ImagePrefetcher] Prefetched: \(url.lastPathComponent)")
                }
            } catch {
                // Silently fail - prefetching is best effort
            }
        }
        
        currentPrefetchTasks[url] = task
    }
    
    /// Prefetch multiple images (prioritized)
    func prefetch(urls: [URL], priority: Int = 0) {
        for url in urls.prefix(maxConcurrentPrefetches) {
            prefetch(url: url)
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
        // Note: Cannot call MainActor methods from deinit
        // Tasks will be cancelled automatically when ImagePrefetcher is deallocated
        // The collections will be cleared automatically
    }
}

// MARK: - Image Cache Helper (Shared across app)
class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSURL, UIImage>()
    private let maxCacheSize = 100 * 1024 * 1024 // 100MB
    
    private init() {
        cache.totalCostLimit = maxCacheSize
        cache.countLimit = 200 // Max 200 images
        setupMemoryWarningObserver()
    }
    
    // ⚡ PERFORMANCE: Clear cache on memory warning
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("⚠️ [ImageCache] Memory warning - clearing cache")
            self?.clearCache()
        }
    }
    
    func hasImage(for url: URL) -> Bool {
        return cache.object(forKey: url as NSURL) != nil
    }
    
    func store(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * 4) // Rough memory cost
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
    
    func image(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }
    
    func clearCache() {
        cache.removeAllObjects()
        print("✅ [ImageCache] Cache cleared")
    }
}

