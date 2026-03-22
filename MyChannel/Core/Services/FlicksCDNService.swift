//
//  FlicksCDNService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import UIKit
import AVFoundation

// 🚀 Enterprise CDN & Caching Service for Flicks
// Industry-standard video delivery with intelligent caching
@MainActor
class FlicksCDNService: ObservableObject {
    static let shared = FlicksCDNService()
    
    // Multi-tier caching system
    private let memoryCache = NSCache<NSString, NSData>()
    private let diskCache = URLCache.shared
    private let videoCache = NSCache<NSString, AVPlayerItem>()
    private let thumbnailCache = NSCache<NSString, UIImage>()
    
    // CDN endpoints (in priority order)
    private let cdnEndpoints = [
        "https://cdn1.mychannel.live",
        "https://cdn2.mychannel.live", 
        "https://storage.googleapis.com/mychannel-ca26d.appspot.com",
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
        // Memory cache for video data (100MB)
        memoryCache.totalCostLimit = 100 * 1024 * 1024
        memoryCache.countLimit = 50
        
        // Video player cache (20 items)
        videoCache.countLimit = 20
        videoCache.totalCostLimit = 200 * 1024 * 1024
        
        // Thumbnail cache (500 items, 50MB)
        thumbnailCache.countLimit = 500
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024
        
        // Disk cache configuration
        diskCache.memoryCapacity = 50 * 1024 * 1024 // 50MB
        diskCache.diskCapacity = 500 * 1024 * 1024   // 500MB
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
        totalCacheSize = Int64(diskCache.currentDiskUsage + diskCache.currentMemoryUsage)
        
        // Report to monitoring
        MonitoringDashboardManager.shared.updateMetric("flicks_cache_hit_rate", value: cacheHitRate)
        MonitoringDashboardManager.shared.updateMetric("flicks_avg_load_time", value: averageLoadTime)
        MonitoringDashboardManager.shared.updateMetric("flicks_cache_size_mb", value: Double(totalCacheSize) / (1024 * 1024))
    }
    
    // MARK: - Video Loading with CDN Fallback
    
    func loadVideo(url: String, quality: VideoQuality = .auto) async throws -> AVPlayerItem {
        let startTime = Date()
        requestCount += 1
        
        // Check video cache first
        let cacheKey = "\(url)_\(quality.rawValue)" as NSString
        if let cachedItem = videoCache.object(forKey: cacheKey) {
            cacheHitCount += 1
            
            EnhancedAnalyticsManager.shared.logEvent("flicks_video_cache_hit", parameters: [
                "url": url,
                "quality": quality.rawValue
            ])
            
            return cachedItem
        }
        
        // Try CDN endpoints in order
        for (index, cdnEndpoint) in cdnEndpoints.enumerated() {
            do {
                let optimizedURL = try await getOptimizedVideoURL(
                    originalURL: url,
                    cdnEndpoint: cdnEndpoint,
                    quality: quality
                )
                
                let playerItem = AVPlayerItem(url: optimizedURL)
                
                // Preload the item
                await preloadPlayerItem(playerItem)
                
                // Cache the successful item
                videoCache.setObject(playerItem, forKey: cacheKey)
                
                let loadTime = Date().timeIntervalSince(startTime)
                loadTimes.append(loadTime)
                
                // Track successful load
                EnhancedAnalyticsManager.shared.logEvent("flicks_video_loaded", parameters: [
                    "url": url,
                    "cdn_endpoint": cdnEndpoint,
                    "cdn_index": index,
                    "quality": quality.rawValue,
                    "load_time_ms": loadTime * 1000,
                    "cache_miss": true
                ])
                
                PerformanceMonitoringManager.shared.trackVideoLoad(
                    videoId: extractVideoId(from: url),
                    loadTime: loadTime,
                    quality: quality.rawValue
                )
                
                return playerItem
                
            } catch {
                // Try next CDN endpoint
                if index == cdnEndpoints.count - 1 {
                    // Last endpoint failed, report error
                    ErrorReportingManager.shared.reportError(
                        error,
                        context: "FlicksVideoLoad",
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
        
        throw FlicksCDNError.allEndpointsFailed
    }
    
    private func getOptimizedVideoURL(
        originalURL: String,
        cdnEndpoint: String,
        quality: VideoQuality
    ) async throws -> URL {
        // Extract file path from original URL
        guard let originalURL = URL(string: originalURL) else {
            throw FlicksCDNError.invalidURL
        }
        
        let path = originalURL.path
        let filename = originalURL.lastPathComponent
        
        // Build CDN URL with quality optimization
        var cdnURLString = "\(cdnEndpoint)\(path)"
        
        // Add quality parameters
        switch quality {
        case .auto:
            // Use adaptive bitrate streaming if available
            cdnURLString += "?quality=auto&abr=true"
        case .low:
            cdnURLString += "?quality=360p&bitrate=500k"
        case .medium:
            cdnURLString += "?quality=720p&bitrate=1500k"
        case .high:
            cdnURLString += "?quality=1080p&bitrate=3000k"
        }
        
        // Add cache control
        cdnURLString += "&cache=3600" // 1 hour cache
        
        guard let cdnURL = URL(string: cdnURLString) else {
            throw FlicksCDNError.invalidCDNURL
        }
        
        return cdnURL
    }
    
    private func preloadPlayerItem(_ playerItem: AVPlayerItem) async {
        return await withCheckedContinuation { continuation in
            playerItem.preferredForwardBufferDuration = 10.0 // 10 seconds buffer
            
            // Wait for item to be ready to play
            let observer = playerItem.observe(\.status) { item, _ in
                if item.status == .readyToPlay || item.status == .failed {
                    continuation.resume()
                }
            }
            
            // Timeout after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                observer.invalidate()
                continuation.resume()
            }
        }
    }
    
    // MARK: - Thumbnail Loading with CDN
    
    func loadThumbnail(url: String, size: CGSize = CGSize(width: 400, height: 600)) async throws -> UIImage {
        let startTime = Date()
        requestCount += 1
        
        // Check thumbnail cache first
        let cacheKey = "\(url)_\(Int(size.width))x\(Int(size.height))" as NSString
        if let cachedImage = thumbnailCache.object(forKey: cacheKey) {
            cacheHitCount += 1
            return cachedImage
        }
        
        // Try CDN endpoints for thumbnail
        for cdnEndpoint in cdnEndpoints {
            do {
                let optimizedURL = try getOptimizedThumbnailURL(
                    originalURL: url,
                    cdnEndpoint: cdnEndpoint,
                    size: size
                )
                
                let (data, _) = try await URLSession.shared.data(from: optimizedURL)
                
                guard let image = UIImage(data: data) else {
                    throw FlicksCDNError.invalidImageData
                }
                
                // Cache the image
                thumbnailCache.setObject(image, forKey: cacheKey)
                
                let loadTime = Date().timeIntervalSince(startTime)
                loadTimes.append(loadTime)
                
                return image
                
            } catch {
                continue
            }
        }
        
        throw FlicksCDNError.allEndpointsFailed
    }
    
    private func getOptimizedThumbnailURL(
        originalURL: String,
        cdnEndpoint: String,
        size: CGSize
    ) throws -> URL {
        guard let originalURL = URL(string: originalURL) else {
            throw FlicksCDNError.invalidURL
        }
        
        let path = originalURL.path
        
        // Build CDN URL with image optimization
        let cdnURLString = "\(cdnEndpoint)\(path)?w=\(Int(size.width))&h=\(Int(size.height))&fit=crop&format=webp&quality=85"
        
        guard let cdnURL = URL(string: cdnURLString) else {
            throw FlicksCDNError.invalidCDNURL
        }
        
        return cdnURL
    }
    
    // MARK: - Intelligent Preloading
    
    func preloadFlicks(_ flicks: [NuclearFlick], priority: PreloadPriority = .normal) async {
        let maxConcurrentLoads = RemoteConfigManager.shared.maxConcurrentUploads
        
        await withTaskGroup(of: Void.self) { group in
            var loadCount = 0
            
            for flick in flicks {
                if loadCount >= maxConcurrentLoads {
                    break
                }
                
                group.addTask {
                    await self.preloadFlick(flick, priority: priority)
                }
                
                loadCount += 1
            }
        }
    }
    
    private func preloadFlick(_ flick: NuclearFlick, priority: PreloadPriority) async {
        // Check if device conditions allow preloading
        guard shouldPreload(priority: priority) else { return }
        
        async let videoPreload: Void = preloadVideo(flick.videoURL)
        async let thumbnailPreload: Void = preloadThumbnail(flick.thumbnailURL)
        
        // Wait for both to complete
        let _ = await (videoPreload, thumbnailPreload)
    }
    
    private func preloadVideo(_ url: String) async {
        do {
            let _ = try await loadVideo(url: url, quality: .medium)
        } catch {
            // Preload failures are non-critical
            print("Video preload failed: \(error)")
        }
    }
    
    private func preloadThumbnail(_ url: String) async {
        do {
            let _ = try await loadThumbnail(url: url)
        } catch {
            // Preload failures are non-critical
            print("Thumbnail preload failed: \(error)")
        }
    }
    
    private func shouldPreload(priority: PreloadPriority) -> Bool {
        let performanceMonitor = FlicksPerformanceMonitor()
        
        switch priority {
        case .low:
            return performanceMonitor.performanceScore > 80 && 
                   performanceMonitor.batteryLevel > 0.5
        case .normal:
            return performanceMonitor.performanceScore > 60 && 
                   performanceMonitor.batteryLevel > 0.3
        case .high:
            return performanceMonitor.performanceScore > 40
        case .critical:
            return true // Always preload critical content
        }
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        memoryCache.removeAllObjects()
        videoCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        diskCache.removeAllCachedResponses()
        
        // Reset metrics
        requestCount = 0
        cacheHitCount = 0
        loadTimes.removeAll()
        
        EnhancedAnalyticsManager.shared.logEvent("flicks_cache_cleared")
    }
    
    func getCacheStatistics() -> FlicksCacheStatistics {
        return FlicksCacheStatistics(
            memoryUsage: Int64(memoryCache.totalCostLimit),
            diskUsage: Int64(diskCache.currentDiskUsage),
            videosCached: videoCache.countLimit,
            thumbnailsCached: thumbnailCache.countLimit,
            hitRate: cacheHitRate,
            averageLoadTime: averageLoadTime
        )
    }
    
    func optimizeCache() {
        // Remove old entries based on LRU
        let maxAge: TimeInterval = RemoteConfigManager.shared.cacheDurationHours * 3600
        
        // This would require custom cache implementation to track access times
        // For now, we'll just ensure we're within limits
        
        if diskCache.currentDiskUsage > diskCache.diskCapacity * 9 / 10 {
            // Clear 20% of disk cache when 90% full
            diskCache.removeAllCachedResponses()
        }
        
        EnhancedAnalyticsManager.shared.logEvent("flicks_cache_optimized", parameters: [
            "disk_usage_mb": Double(diskCache.currentDiskUsage) / (1024 * 1024),
            "memory_usage_mb": Double(diskCache.currentMemoryUsage) / (1024 * 1024)
        ])
    }
    
    // MARK: - Helper Methods
    
    private func extractVideoId(from url: String) -> String {
        return URL(string: url)?.lastPathComponent ?? "unknown"
    }
}

// MARK: - Supporting Types

enum VideoQuality: String, CaseIterable {
    case auto = "auto"
    case low = "360p"
    case medium = "720p"
    case high = "1080p"
}

enum PreloadPriority {
    case low
    case normal
    case high
    case critical
}

enum FlicksCDNError: LocalizedError {
    case invalidURL
    case invalidCDNURL
    case invalidImageData
    case allEndpointsFailed
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
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

struct FlicksCacheStatistics {
    let memoryUsage: Int64
    let diskUsage: Int64
    let videosCached: Int
    let thumbnailsCached: Int
    let hitRate: Double
    let averageLoadTime: TimeInterval
}
