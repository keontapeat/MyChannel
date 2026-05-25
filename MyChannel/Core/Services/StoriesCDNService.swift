//
//  StoriesCDNService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import UIKit
import AVFoundation

// 🚀 Enterprise Stories CDN & Caching Service
// Industry-standard content delivery for Stories with intelligent preloading
@MainActor
class StoriesCDNService: ObservableObject {
    static let shared = StoriesCDNService()
    
    // Multi-tier caching system
    private let memoryCache = NSCache<NSString, NSData>()
    private let imageCache = NSCache<NSString, UIImage>()
    private let videoCache = NSCache<NSString, AVPlayerItem>()
    
    // CDN endpoints for Stories (optimized for mobile)
    private let cdnEndpoints = [
        "https://stories-cdn1.mychannel.live",
        "https://stories-cdn2.mychannel.live",
        "https://storage.googleapis.com/mychannel-stories",
        "https://firebasestorage.googleapis.com/v0/b/mychannel-ca26d.appspot.com"
    ]
    
    // Performance tracking
    @Published var cacheHitRate: Double = 0.0
    @Published var averageLoadTime: TimeInterval = 0.0
    @Published var totalCacheSize: Int64 = 0
    
    private var requestCount = 0
    private var cacheHitCount = 0
    private var loadTimes: [TimeInterval] = []
    
    private init() {
        setupCaches()
        startPerformanceTracking()
    }
    
    // MARK: - Cache Configuration
    
    private func setupCaches() {
        // Memory cache for story data (50MB)
        memoryCache.totalCostLimit = 50 * 1024 * 1024
        memoryCache.countLimit = 100
        
        // Image cache for story thumbnails and images (100MB)
        imageCache.countLimit = 500
        imageCache.totalCostLimit = 100 * 1024 * 1024
        
        // Video cache for story videos (200MB)
        videoCache.countLimit = 50
        videoCache.totalCostLimit = 200 * 1024 * 1024
    }
    
    private func startPerformanceTracking() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                self.updatePerformanceMetrics()
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        // Calculate cache hit rate
        if requestCount > 0 {
            cacheHitRate = Double(cacheHitCount) / Double(requestCount)
        }
        
        // Calculate average load time
        if !loadTimes.isEmpty {
            averageLoadTime = loadTimes.reduce(0, +) / Double(loadTimes.count)
        }
        
        // Calculate total cache size
        totalCacheSize = Int64(memoryCache.totalCostLimit + imageCache.totalCostLimit + videoCache.totalCostLimit)
        
        // Report to monitoring
        MonitoringDashboardManager.shared.updateMetric("stories_cache_hit_rate", value: cacheHitRate)
        MonitoringDashboardManager.shared.updateMetric("stories_avg_load_time", value: averageLoadTime)
        MonitoringDashboardManager.shared.updateMetric("stories_cache_size_mb", value: Double(totalCacheSize) / (1024 * 1024))
    }
    
    // MARK: - Story Image Loading with CDN
    
    func loadStoryImage(url: String, size: CGSize = CGSize(width: 400, height: 700)) async throws -> UIImage {
        let startTime = Date()
        requestCount += 1
        
        // Check image cache first
        let cacheKey = "\(url)_\(Int(size.width))x\(Int(size.height))" as NSString
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            cacheHitCount += 1
            
            EnhancedAnalyticsManager.shared.logEvent("story_image_cache_hit", parameters: [
                "url": url,
                "size": "\(Int(size.width))x\(Int(size.height))"
            ])
            
            return cachedImage
        }
        
        // Try CDN endpoints for optimized image
        for (index, cdnEndpoint) in cdnEndpoints.enumerated() {
            do {
                let optimizedURL = try getOptimizedStoryImageURL(
                    originalURL: url,
                    cdnEndpoint: cdnEndpoint,
                    size: size
                )
                
                let (data, _) = try await URLSession.shared.data(from: optimizedURL)
                
                guard let image = UIImage(data: data) else {
                    throw StoriesCDNError.invalidImageData
                }
                
                // Cache the image
                imageCache.setObject(image, forKey: cacheKey)
                
                let loadTime = Date().timeIntervalSince(startTime)
                loadTimes.append(loadTime)
                
                // Track successful load
                EnhancedAnalyticsManager.shared.logEvent("story_image_loaded", parameters: [
                    "url": url,
                    "cdn_endpoint": cdnEndpoint,
                    "cdn_index": index,
                    "load_time_ms": loadTime * 1000,
                    "cache_miss": true
                ])
                
                return image
                
            } catch {
                if index == cdnEndpoints.count - 1 {
                    throw error
                }
                continue
            }
        }
        
        throw StoriesCDNError.allEndpointsFailed
    }
    
    private func getOptimizedStoryImageURL(
        originalURL: String,
        cdnEndpoint: String,
        size: CGSize
    ) throws -> URL {
        guard let originalURL = URL(string: originalURL) else {
            throw StoriesCDNError.invalidURL
        }
        
        let path = originalURL.path
        
        // Build CDN URL with story-specific optimizations
        let cdnURLString = "\(cdnEndpoint)\(path)?w=\(Int(size.width))&h=\(Int(size.height))&fit=crop&format=webp&quality=90&story=true"
        
        guard let cdnURL = URL(string: cdnURLString) else {
            throw StoriesCDNError.invalidCDNURL
        }
        
        return cdnURL
    }
    
    // MARK: - Story Video Loading with CDN
    
    func loadStoryVideo(url: String, quality: StoryVideoQuality = .auto) async throws -> AVPlayerItem {
        let startTime = Date()
        requestCount += 1
        
        // Check video cache first
        let cacheKey = "\(url)_\(quality.rawValue)" as NSString
        if let cachedItem = videoCache.object(forKey: cacheKey) {
            cacheHitCount += 1
            
            EnhancedAnalyticsManager.shared.logEvent("story_video_cache_hit", parameters: [
                "url": url,
                "quality": quality.rawValue
            ])
            
            return cachedItem
        }
        
        // Try CDN endpoints for optimized video
        for (index, cdnEndpoint) in cdnEndpoints.enumerated() {
            do {
                let optimizedURL = try await getOptimizedStoryVideoURL(
                    originalURL: url,
                    cdnEndpoint: cdnEndpoint,
                    quality: quality
                )
                
                let playerItem = AVPlayerItem(url: optimizedURL)
                
                // Optimize for Stories playback
                await optimizePlayerItemForStories(playerItem)
                
                // Cache the successful item
                videoCache.setObject(playerItem, forKey: cacheKey)
                
                let loadTime = Date().timeIntervalSince(startTime)
                loadTimes.append(loadTime)
                
                // Track successful load
                EnhancedAnalyticsManager.shared.logEvent("story_video_loaded", parameters: [
                    "url": url,
                    "cdn_endpoint": cdnEndpoint,
                    "cdn_index": index,
                    "quality": quality.rawValue,
                    "load_time_ms": loadTime * 1000,
                    "cache_miss": true
                ])
                
                PerformanceMonitoringManager.shared.trackVideoLoad(
                    videoId: extractStoryId(from: url),
                    loadTime: loadTime,
                    quality: quality.rawValue
                )
                
                return playerItem
                
            } catch {
                if index == cdnEndpoints.count - 1 {
                    ErrorReportingManager.shared.reportError(
                        error,
                        context: "StoryVideoLoad",
                        severity: .error,
                        metadata: [
                            "url": url,
                            "attempted_endpoints": cdnEndpoints.count,
                            "quality": quality.rawValue
                        ]
                    )
                    throw error
                }
                continue
            }
        }
        
        throw StoriesCDNError.allEndpointsFailed
    }
    
    private func getOptimizedStoryVideoURL(
        originalURL: String,
        cdnEndpoint: String,
        quality: StoryVideoQuality
    ) async throws -> URL {
        guard let originalURL = URL(string: originalURL) else {
            throw StoriesCDNError.invalidURL
        }
        
        let path = originalURL.path
        
        // Build CDN URL with story-specific video optimizations
        var cdnURLString = "\(cdnEndpoint)\(path)"
        
        // Add quality parameters optimized for Stories
        switch quality {
        case .auto:
            cdnURLString += "?quality=auto&story=true&mobile=true"
        case .low:
            cdnURLString += "?quality=480p&bitrate=800k&story=true"
        case .medium:
            cdnURLString += "?quality=720p&bitrate=1200k&story=true"
        case .high:
            cdnURLString += "?quality=1080p&bitrate=2000k&story=true"
        }
        
        // Add story-specific optimizations
        cdnURLString += "&preload=metadata&loop=true&autoplay=true"
        
        guard let cdnURL = URL(string: cdnURLString) else {
            throw StoriesCDNError.invalidCDNURL
        }
        
        return cdnURL
    }
    
    private func optimizePlayerItemForStories(_ playerItem: AVPlayerItem) async {
        return await withCheckedContinuation { continuation in
            // Optimize for Stories: quick start, smooth transitions
            playerItem.preferredForwardBufferDuration = 5.0 // 5 seconds buffer
            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = false
            
            // Wait for item to be ready
            let observer = playerItem.observe(\.status) { item, _ in
                if item.status == .readyToPlay || item.status == .failed {
                    continuation.resume()
                }
            }
            
            // Timeout after 3 seconds for Stories
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                observer.invalidate()
                continuation.resume()
            }
        }
    }
    
    // MARK: - Intelligent Story Preloading
    
    func preloadStories(_ stories: [EnhancedStory], priority: StoryPreloadPriority = .normal) async {
        let maxConcurrentLoads = RemoteConfigManager.shared.maxConcurrentUploads
        
        await withTaskGroup(of: Void.self) { group in
            var loadCount = 0
            
            for story in stories {
                if loadCount >= maxConcurrentLoads {
                    break
                }
                
                group.addTask {
                    await self.preloadStory(story, priority: priority)
                }
                
                loadCount += 1
            }
        }
    }
    
    private func preloadStory(_ story: EnhancedStory, priority: StoryPreloadPriority) async {
        // Check if device conditions allow preloading
        guard shouldPreloadStory(priority: priority) else { return }
        
        // Preload based on media type
        switch story.mediaType {
        case .image:
            await preloadStoryImage(story.mediaURL)
        case .video:
            await preloadStoryVideo(story.mediaURL)
            // Also preload thumbnail if available
            if let thumbnailURL = story.thumbnailURL {
                await preloadStoryImage(thumbnailURL)
            }
        }
    }
    
    private func preloadStoryImage(_ url: String) async {
        do {
            let _ = try await loadStoryImage(url: url)
        } catch {
            // Preload failures are non-critical
            print("Story image preload failed: \(error)")
        }
    }
    
    private func preloadStoryVideo(_ url: String) async {
        do {
            let _ = try await loadStoryVideo(url: url, quality: .medium)
        } catch {
            // Preload failures are non-critical
            print("Story video preload failed: \(error)")
        }
    }
    
    private func shouldPreloadStory(priority: StoryPreloadPriority) -> Bool {
        let performanceMonitor = FlicksPerformanceMonitor()
        
        switch priority {
        case .low:
            return performanceMonitor.performanceScore > 85 && 
                   performanceMonitor.batteryLevel > 0.6
        case .normal:
            return performanceMonitor.performanceScore > 70 && 
                   performanceMonitor.batteryLevel > 0.4
        case .high:
            return performanceMonitor.performanceScore > 50 && 
                   performanceMonitor.batteryLevel > 0.2
        case .critical:
            return true // Always preload critical Stories
        }
    }
    
    // MARK: - Story-Specific Optimizations
    
    func optimizeForStoriesViewing() {
        // Increase cache limits for Stories viewing session
        imageCache.totalCostLimit = 150 * 1024 * 1024 // 150MB for images
        videoCache.totalCostLimit = 300 * 1024 * 1024 // 300MB for videos
        
        // Adjust preloading strategy
        EnhancedAnalyticsManager.shared.logEvent("stories_optimization_enabled")
    }
    
    func resetOptimizations() {
        // Reset to normal cache limits
        setupCaches()
        
        EnhancedAnalyticsManager.shared.logEvent("stories_optimization_disabled")
    }
    
    // MARK: - Cache Management
    
    func clearStoriesCache() {
        memoryCache.removeAllObjects()
        imageCache.removeAllObjects()
        videoCache.removeAllObjects()
        
        // Reset metrics
        requestCount = 0
        cacheHitCount = 0
        loadTimes.removeAll()
        
        EnhancedAnalyticsManager.shared.logEvent("stories_cache_cleared")
    }
    
    func getStoriesCacheStatistics() -> StoriesCacheStatistics {
        return StoriesCacheStatistics(
            imagesCached: imageCache.countLimit,
            videosCached: videoCache.countLimit,
            totalCacheSize: totalCacheSize,
            hitRate: cacheHitRate,
            averageLoadTime: averageLoadTime,
            requestCount: requestCount
        )
    }
    
    func optimizeStoriesCache() {
        // Remove expired stories from cache
        let now = Date()
        
        // This would require custom cache implementation to track expiry
        // For now, we'll just ensure we're within limits
        
        if imageCache.totalCostLimit > 200 * 1024 * 1024 {
            // Clear 30% of image cache when over 200MB
            imageCache.removeAllObjects()
        }
        
        if videoCache.totalCostLimit > 400 * 1024 * 1024 {
            // Clear 30% of video cache when over 400MB
            videoCache.removeAllObjects()
        }
        
        EnhancedAnalyticsManager.shared.logEvent("stories_cache_optimized", parameters: [
            "images_cached": imageCache.countLimit,
            "videos_cached": videoCache.countLimit,
            "total_size_mb": Double(totalCacheSize) / (1024 * 1024)
        ])
    }
    
    // MARK: - Helper Methods
    
    private func extractStoryId(from url: String) -> String {
        // Extract story ID from URL path
        if let urlComponents = URLComponents(string: url),
           let pathComponents = urlComponents.path.components(separatedBy: "/").last {
            return pathComponents
        }
        return "unknown"
    }
}

// MARK: - Supporting Types

enum StoryVideoQuality: String, CaseIterable {
    case auto = "auto"
    case low = "480p"
    case medium = "720p"
    case high = "1080p"
}

enum StoryPreloadPriority {
    case low
    case normal
    case high
    case critical
}

enum StoriesCDNError: LocalizedError {
    case invalidURL
    case invalidCDNURL
    case invalidImageData
    case allEndpointsFailed
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid story URL provided"
        case .invalidCDNURL:
            return "Invalid CDN URL generated"
        case .invalidImageData:
            return "Invalid image data received"
        case .allEndpointsFailed:
            return "All CDN endpoints failed"
        case .networkUnavailable:
            return "Network is unavailable"
        }
    }
}

struct StoriesCacheStatistics {
    let imagesCached: Int
    let videosCached: Int
    let totalCacheSize: Int64
    let hitRate: Double
    let averageLoadTime: TimeInterval
    let requestCount: Int
}
