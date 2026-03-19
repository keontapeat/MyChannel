//
//  DynamicMemoryManager.swift
//  MyChannel
//
//  🧠 DYNAMIC MEMORY OPTIMIZATION
//  Adaptive cache sizing and intelligent memory management
//

import Foundation
import UIKit

// MARK: - Memory Tier
enum MemoryTier {
    case low        // <2GB devices
    case medium     // 2-4GB devices
    case high       // 4-6GB devices
    case ultra      // >6GB devices
    
    var imageCacheSize: Int {
        switch self {
        case .low: return 50 * 1024 * 1024      // 50MB
        case .medium: return 100 * 1024 * 1024  // 100MB
        case .high: return 150 * 1024 * 1024    // 150MB
        case .ultra: return 200 * 1024 * 1024   // 200MB
        }
    }
    
    var urlCacheMemory: Int {
        switch self {
        case .low: return 25 * 1024 * 1024      // 25MB
        case .medium: return 50 * 1024 * 1024   // 50MB
        case .high: return 100 * 1024 * 1024    // 100MB
        case .ultra: return 150 * 1024 * 1024   // 150MB
        }
    }
    
    var urlCacheDisk: Int {
        switch self {
        case .low: return 100 * 1024 * 1024     // 100MB
        case .medium: return 250 * 1024 * 1024  // 250MB
        case .high: return 500 * 1024 * 1024    // 500MB
        case .ultra: return 750 * 1024 * 1024   // 750MB
        }
    }
    
    var maxConcurrentOperations: Int {
        switch self {
        case .low: return 2
        case .medium: return 4
        case .high: return 6
        case .ultra: return 8
        }
    }
}

// MARK: - Dynamic Memory Manager
@MainActor
class DynamicMemoryManager: ObservableObject {
    static let shared = DynamicMemoryManager()
    
    @Published var currentMemoryUsage: Int64 = 0
    @Published var memoryTier: MemoryTier = .medium
    @Published var memoryPressureLevel: MemoryPressureLevel = .normal
    
    private var memoryMonitorTimer: Timer?
    private var lastMemoryWarningTime: Date?
    
    enum MemoryPressureLevel {
        case normal
        case warning
        case critical
    }
    
    private init() {
        detectMemoryTier()
        setupMemoryMonitoring()
        configureOptimalCaches()
        setupMemoryWarningObserver()
    }
    
    // MARK: - Memory Tier Detection
    
    private func detectMemoryTier() {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(physicalMemory) / (1024 * 1024 * 1024)
        
        if memoryGB < 2 {
            memoryTier = .low
        } else if memoryGB < 4 {
            memoryTier = .medium
        } else if memoryGB < 6 {
            memoryTier = .high
        } else {
            memoryTier = .ultra
        }
        
        print("🧠 [MemoryManager] Device memory: \(String(format: "%.1f", memoryGB))GB - Tier: \(memoryTier)")
    }
    
    // MARK: - Cache Configuration
    
    private func configureOptimalCaches() {
        // Configure URLCache based on memory tier
        let cache = URLCache(
            memoryCapacity: memoryTier.urlCacheMemory,
            diskCapacity: memoryTier.urlCacheDisk,
            diskPath: "MyChannelCache"
        )
        URLCache.shared = cache
        
        // Configure ImageCache
        ImageCache.shared.updateCacheLimit(memoryTier.imageCacheSize)
        
        print("🧠 [MemoryManager] Caches configured for \(memoryTier) tier")
        print("  - Image Cache: \(memoryTier.imageCacheSize / 1024 / 1024)MB")
        print("  - URL Cache Memory: \(memoryTier.urlCacheMemory / 1024 / 1024)MB")
        print("  - URL Cache Disk: \(memoryTier.urlCacheDisk / 1024 / 1024)MB")
    }
    
    // MARK: - Memory Monitoring
    
    private func setupMemoryMonitoring() {
        // Monitor memory usage every 5 seconds
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryMetrics()
            }
        }
    }
    
    private func updateMemoryMetrics() {
        currentMemoryUsage = getMemoryUsage()
        
        // Determine memory pressure level
        let memoryMB = currentMemoryUsage / 1_000_000
        let threshold = memoryTier == .low ? 150 : 200
        
        if memoryMB > threshold + 50 {
            memoryPressureLevel = .critical
            handleCriticalMemory()
        } else if memoryMB > threshold {
            memoryPressureLevel = .warning
            handleMemoryWarning()
        } else {
            memoryPressureLevel = .normal
        }
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info(
            virtual_size: 0,
            resident_size: 0,
            resident_size_max: 0,
            user_time: time_value_t(seconds: 0, microseconds: 0),
            system_time: time_value_t(seconds: 0, microseconds: 0),
            policy: 0,
            suspend_count: 0
        )
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 0 }
        return Int64(info.resident_size)
    }
    
    // MARK: - Memory Warning Handling
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSystemMemoryWarning()
            }
        }
    }
    
    private func handleSystemMemoryWarning() {
        lastMemoryWarningTime = Date()
        print("⚠️ [MemoryManager] System memory warning received")
        
        // Aggressive cleanup
        clearCaches(aggressive: true)
        
        // Cancel non-essential operations
        ImagePrefetcher.shared.cancelAll()
        
        // Notify performance monitor
        PerformanceMonitor.shared.trackMemoryWarning()
    }
    
    private func handleMemoryWarning() {
        // Moderate cleanup
        clearCaches(aggressive: false)
        print("⚠️ [MemoryManager] Memory warning - cleared 30% of caches")
    }
    
    private func handleCriticalMemory() {
        // Critical cleanup
        clearCaches(aggressive: true)
        
        // Cancel all prefetching
        ImagePrefetcher.shared.cancelAll()
        
        print("🚨 [MemoryManager] Critical memory - aggressive cleanup performed")
    }
    
    // MARK: - Cache Management
    
    private func clearCaches(aggressive: Bool) {
        if aggressive {
            // Clear 70% of caches
            ImageCache.shared.clearOldEntries(percentage: 0.7)
            URLCache.shared.removeAllCachedResponses()
        } else {
            // Clear 30% of caches
            ImageCache.shared.clearOldEntries(percentage: 0.3)
        }
    }
    
    // MARK: - Public API
    
    func shouldPrefetchImages() -> Bool {
        // Don't prefetch if memory is under pressure
        return memoryPressureLevel == .normal
    }
    
    func maxConcurrentImageLoads() -> Int {
        switch memoryPressureLevel {
        case .normal:
            return memoryTier.maxConcurrentOperations
        case .warning:
            return max(2, memoryTier.maxConcurrentOperations / 2)
        case .critical:
            return 1
        }
    }
    
    func optimizeForBackground() {
        // Reduce memory footprint when app goes to background
        clearCaches(aggressive: false)
        print("🧠 [MemoryManager] Optimized for background")
    }
    
    func optimizeForForeground() {
        // Restore caches when app comes to foreground
        configureOptimalCaches()
        print("🧠 [MemoryManager] Optimized for foreground")
    }
    
    deinit {
        memoryMonitorTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - ImageCache Extension

extension ImageCache {
    func updateCacheLimit(_ limit: Int) {
        cache.totalCostLimit = limit
        let maxImages = limit / (1024 * 1024) * 2 // Rough estimate
        cache.countLimit = maxImages
    }
    
    func clearOldEntries(percentage: Double = 0.5) {
        // Reduce cache size by percentage
        let currentLimit = cache.totalCostLimit
        let newLimit = Int(Double(currentLimit) * (1.0 - percentage))
        cache.totalCostLimit = newLimit
        
        // Restore limit after cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.cache.totalCostLimit = currentLimit
        }
    }
}
