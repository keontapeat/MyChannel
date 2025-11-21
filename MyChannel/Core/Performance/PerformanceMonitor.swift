//
//  PerformanceMonitor.swift
//  MyChannel
//
//  🔥 THERMONUCLEAR: Real-time performance monitoring
//  Track image loads, network requests, view renders, memory, FPS
//

import Foundation
import SwiftUI

@MainActor
final class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var metrics: PerformanceMetrics = .empty
    @Published var alerts: [PerformanceAlert] = []
    
    // MARK: - Metrics Model
    struct PerformanceMetrics {
        var avgImageLoadTime: TimeInterval = 0
        var avgNetworkRequestTime: TimeInterval = 0
        var avgViewRenderTime: TimeInterval = 0
        var cacheHitRate: Double = 0
        var currentFPS: Int = 60
        var memoryUsageMB: Int = 0
        var networkCacheHitRate: Double = 0
        
        // Counts
        var totalImageLoads: Int = 0
        var totalNetworkRequests: Int = 0
        var totalViewRenders: Int = 0
        var slowImageLoads: Int = 0
        var slowNetworkRequests: Int = 0
        var droppedFrames: Int = 0
        
        static let empty = PerformanceMetrics()
        
        var summary: String {
            """
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            📊 PERFORMANCE METRICS (LIVE)
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            Avg Image Load:    \(Int(avgImageLoadTime * 1000))ms
            Avg Network:       \(Int(avgNetworkRequestTime * 1000))ms
            Avg Render:        \(Int(avgViewRenderTime * 1000))ms
            Cache Hit Rate:    \(Int(cacheHitRate * 100))%
            Memory Usage:      \(memoryUsageMB)MB
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            Total Images:      \(totalImageLoads) (\(slowImageLoads) slow)
            Total Network:     \(totalNetworkRequests) (\(slowNetworkRequests) slow)
            Dropped Frames:    \(droppedFrames)
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            """
        }
    }
    
    struct PerformanceAlert: Identifiable {
        let id = UUID()
        let type: AlertType
        let message: String
        let timestamp: Date
        
        enum AlertType {
            case slowImage
            case slowNetwork
            case droppedFrame
            case memoryWarning
            case lowCacheHit
        }
    }
    
    // MARK: - Private State
    private var imageLoadTimes: [TimeInterval] = []
    private var networkRequestTimes: [TimeInterval] = []
    private var viewRenderTimes: [TimeInterval] = []
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    private var networkCacheHits: Int = 0
    private var networkCacheMisses: Int = 0
    
    private var updateTimer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        // Update metrics every 5 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
        
        print("⚡ [PerformanceMonitor] Started - tracking all performance metrics")
    }
    
    // MARK: - Image Load Tracking
    
    func measureImageLoad(_ duration: TimeInterval, fromCache: Bool) {
        imageLoadTimes.append(duration)
        
        if fromCache {
            cacheHits += 1
        } else {
            cacheMisses += 1
        }
        
        // Keep only last 100 measurements
        if imageLoadTimes.count > 100 {
            imageLoadTimes.removeFirst()
        }
        
        // Alert if slow (>200ms)
        if duration > 0.2 {
            metrics.slowImageLoads += 1
            addAlert(.slowImage, message: "Slow image load: \(Int(duration * 1000))ms")
        }
        
        metrics.totalImageLoads += 1
    }
    
    // MARK: - Network Request Tracking
    
    func measureNetworkRequest(_ url: URL, duration: TimeInterval, fromCache: Bool = false) {
        networkRequestTimes.append(duration)
        
        if fromCache {
            networkCacheHits += 1
        } else {
            networkCacheMisses += 1
        }
        
        if networkRequestTimes.count > 100 {
            networkRequestTimes.removeFirst()
        }
        
        // Alert if slow (>500ms)
        if duration > 0.5 {
            metrics.slowNetworkRequests += 1
            addAlert(.slowNetwork, message: "Slow network request: \(url.path) - \(Int(duration * 1000))ms")
        }
        
        metrics.totalNetworkRequests += 1
    }
    
    // MARK: - View Render Tracking
    
    func measureViewRender(_ viewName: String, duration: TimeInterval) {
        viewRenderTimes.append(duration)
        
        if viewRenderTimes.count > 100 {
            viewRenderTimes.removeFirst()
        }
        
        // Alert if dropped frame (>16ms = 60fps threshold)
        if duration > 0.016 {
            metrics.droppedFrames += 1
            addAlert(.droppedFrame, message: "Slow render: \(viewName) - \(Int(duration * 1000))ms")
        }
        
        metrics.totalViewRenders += 1
    }
    
    // MARK: - Memory Tracking
    
    func trackMemoryWarning() {
        addAlert(.memoryWarning, message: "Memory warning received - caches cleared")
    }
    
    // MARK: - Metrics Update
    
    private func updateMetrics() {
        // Calculate averages
        let avgImageLoad = imageLoadTimes.isEmpty ? 0 : imageLoadTimes.reduce(0, +) / Double(imageLoadTimes.count)
        let avgNetwork = networkRequestTimes.isEmpty ? 0 : networkRequestTimes.reduce(0, +) / Double(networkRequestTimes.count)
        let avgRender = viewRenderTimes.isEmpty ? 0 : viewRenderTimes.reduce(0, +) / Double(viewRenderTimes.count)
        
        // Calculate cache hit rates
        let totalCacheAttempts = cacheHits + cacheMisses
        let cacheHitRate = totalCacheAttempts == 0 ? 0 : Double(cacheHits) / Double(totalCacheAttempts)
        
        let totalNetworkCacheAttempts = networkCacheHits + networkCacheMisses
        let networkCacheHitRate = totalNetworkCacheAttempts == 0 ? 0 : Double(networkCacheHits) / Double(totalNetworkCacheAttempts)
        
        // Get current memory usage
        let memoryMB = Int(getMemoryUsage() / 1_000_000)
        
        // Update published metrics
        metrics.avgImageLoadTime = avgImageLoad
        metrics.avgNetworkRequestTime = avgNetwork
        metrics.avgViewRenderTime = avgRender
        metrics.cacheHitRate = cacheHitRate
        metrics.networkCacheHitRate = networkCacheHitRate
        metrics.memoryUsageMB = memoryMB
        
        // Alert if cache hit rate is low
        if cacheHitRate < 0.7 && totalCacheAttempts > 20 {
            addAlert(.lowCacheHit, message: "Low cache hit rate: \(Int(cacheHitRate * 100))%")
        }
        
        // Log summary every 5 updates
        if metrics.totalImageLoads % 50 == 0 && metrics.totalImageLoads > 0 {
            print(metrics.summary)
        }
    }
    
    // MARK: - Memory Usage
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    // MARK: - Alerts
    
    private func addAlert(_ type: PerformanceAlert.AlertType, message: String) {
        let alert = PerformanceAlert(type: type, message: message, timestamp: Date())
        alerts.append(alert)
        
        // Keep only last 20 alerts
        if alerts.count > 20 {
            alerts.removeFirst()
        }
        
        // Log to console
        switch type {
        case .slowImage:
            print("🐌 [Performance] \(message)")
        case .slowNetwork:
            print("🐌 [Performance] \(message)")
        case .droppedFrame:
            print("🎬 [Performance] \(message)")
        case .memoryWarning:
            print("⚠️ [Performance] \(message)")
        case .lowCacheHit:
            print("📊 [Performance] \(message)")
        }
    }
    
    // MARK: - Public API
    
    func getReport() -> String {
        return metrics.summary
    }
    
    func printReport() {
        print(metrics.summary)
    }
    
    func clearAlerts() {
        alerts.removeAll()
    }
    
    func reset() {
        imageLoadTimes.removeAll()
        networkRequestTimes.removeAll()
        viewRenderTimes.removeAll()
        cacheHits = 0
        cacheMisses = 0
        networkCacheHits = 0
        networkCacheMisses = 0
        metrics = .empty
        alerts.removeAll()
        
        print("🔄 [PerformanceMonitor] Reset all metrics")
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}

// MARK: - Helper Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
