//
//  MultiLayerCacheSystem.swift
//  MyChannel
//
//  💾 MULTI-LAYER CACHING SYSTEM
//  Memory → Disk → Network with intelligent eviction
//

import Foundation
import UIKit

// MARK: - Cache Layer Protocol

protocol CacheLayer {
    associatedtype Key: Hashable
    associatedtype Value
    
    func get(_ key: Key) async -> Value?
    func set(_ key: Key, value: Value) async
    func remove(_ key: Key) async
    func clear() async
}

// MARK: - Memory Cache Layer

actor MemoryCacheLayer<Key: Hashable, Value>: CacheLayer {
    private var cache: [Key: CacheEntry] = [:]
    private let maxSize: Int
    private let ttl: TimeInterval
    
    struct CacheEntry {
        let value: Value
        let timestamp: Date
        let size: Int
    }
    
    init(maxSize: Int = 100 * 1024 * 1024, ttl: TimeInterval = 300) {
        self.maxSize = maxSize
        self.ttl = ttl
    }
    
    func get(_ key: Key) async -> Value? {
        guard let entry = cache[key] else { return nil }
        
        // Check if expired
        if Date().timeIntervalSince(entry.timestamp) > ttl {
            cache.removeValue(forKey: key)
            return nil
        }
        
        return entry.value
    }
    
    func set(_ key: Key, value: Value) async {
        let size = estimateSize(value)
        let entry = CacheEntry(value: value, timestamp: Date(), size: size)
        cache[key] = entry
        
        // Evict if over size limit
        await evictIfNeeded()
    }
    
    func remove(_ key: Key) async {
        cache.removeValue(forKey: key)
    }
    
    func clear() async {
        cache.removeAll()
    }
    
    private func evictIfNeeded() async {
        let totalSize = cache.values.reduce(0) { $0 + $1.size }
        
        if totalSize > maxSize {
            // LRU eviction - remove oldest entries
            let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(cache.count / 4) // Remove 25%
            
            for (key, _) in toRemove {
                cache.removeValue(forKey: key)
            }
        }
    }
    
    private func estimateSize(_ value: Value) -> Int {
        // Rough size estimation
        return 1024 // 1KB default
    }
}

// MARK: - Disk Cache Layer

actor DiskCacheLayer<Key: Hashable, Value: Codable>: CacheLayer {
    private let cacheDirectory: URL
    private let maxDiskSize: Int
    private let fileManager = FileManager.default
    
    init(maxDiskSize: Int = 500 * 1024 * 1024) {
        self.maxDiskSize = maxDiskSize
        
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cacheDir.appendingPathComponent("MultiLayerCache")
        
        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func get(_ key: Key) async -> Value? {
        let fileURL = cacheURL(for: key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let value = try JSONDecoder().decode(Value.self, from: data)
            return value
        } catch {
            return nil
        }
    }
    
    func set(_ key: Key, value: Value) async {
        let fileURL = cacheURL(for: key)
        
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL)
            
            await evictIfNeeded()
        } catch {
            print("⚠️ [DiskCache] Failed to write: \(error)")
        }
    }
    
    func remove(_ key: Key) async {
        let fileURL = cacheURL(for: key)
        try? fileManager.removeItem(at: fileURL)
    }
    
    func clear() async {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    private func cacheURL(for key: Key) -> URL {
        let filename = String(describing: key).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "cache"
        return cacheDirectory.appendingPathComponent(filename)
    }
    
    private func evictIfNeeded() async {
        let totalSize = await calculateDiskSize()
        
        if totalSize > maxDiskSize {
            // Remove oldest files
            await removeOldestFiles(percentage: 0.25)
        }
    }
    
    private func calculateDiskSize() async -> Int {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + size
        }
    }
    
    private func removeOldestFiles(percentage: Double) async {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        
        let sorted = files.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return date1 < date2
        }
        
        let removeCount = Int(Double(sorted.count) * percentage)
        for url in sorted.prefix(removeCount) {
            try? fileManager.removeItem(at: url)
        }
    }
}

// MARK: - Multi-Layer Cache Manager

@MainActor
class MultiLayerCacheManager<Key: Hashable, Value: Codable>: ObservableObject {
    private let memoryCache: MemoryCacheLayer<Key, Value>
    private let diskCache: DiskCacheLayer<Key, Value>
    
    @Published var stats = CacheStats()
    
    struct CacheStats {
        var memoryHits: Int = 0
        var diskHits: Int = 0
        var misses: Int = 0
        var totalRequests: Int = 0
        
        var hitRate: Double {
            guard totalRequests > 0 else { return 0 }
            return Double(memoryHits + diskHits) / Double(totalRequests)
        }
    }
    
    init(
        memorySize: Int = 100 * 1024 * 1024,
        diskSize: Int = 500 * 1024 * 1024,
        ttl: TimeInterval = 300
    ) {
        self.memoryCache = MemoryCacheLayer(maxSize: memorySize, ttl: ttl)
        self.diskCache = DiskCacheLayer(maxDiskSize: diskSize)
    }
    
    // MARK: - Cache Operations
    
    func get(_ key: Key) async -> Value? {
        stats.totalRequests += 1
        
        // Try memory cache first
        if let value = await memoryCache.get(key) {
            stats.memoryHits += 1
            return value
        }
        
        // Try disk cache
        if let value = await diskCache.get(key) {
            stats.diskHits += 1
            
            // Promote to memory cache
            await memoryCache.set(key, value: value)
            
            return value
        }
        
        stats.misses += 1
        return nil
    }
    
    func set(_ key: Key, value: Value) async {
        // Write to both layers
        await memoryCache.set(key, value: value)
        await diskCache.set(key, value: value)
    }
    
    func remove(_ key: Key) async {
        await memoryCache.remove(key)
        await diskCache.remove(key)
    }
    
    func clear() async {
        await memoryCache.clear()
        await diskCache.clear()
        stats = CacheStats()
    }
    
    // MARK: - Statistics
    
    func printStats() {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("💾 CACHE STATISTICS")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Total Requests:   \(stats.totalRequests)")
        print("Memory Hits:      \(stats.memoryHits)")
        print("Disk Hits:        \(stats.diskHits)")
        print("Misses:           \(stats.misses)")
        print("Hit Rate:         \(Int(stats.hitRate * 100))%")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
}

// MARK: - Network Request Cache

@MainActor
class NetworkRequestCache: ObservableObject {
    static let shared = NetworkRequestCache()
    
    private let cache = MultiLayerCacheManager<String, CachedResponse>(
        memorySize: 50 * 1024 * 1024,
        diskSize: 250 * 1024 * 1024,
        ttl: 300
    )
    
    struct CachedResponse: Codable {
        let data: Data
        let statusCode: Int
        let headers: [String: String]
        let timestamp: Date
    }
    
    private init() {}
    
    func get(for url: URL) async -> CachedResponse? {
        return await cache.get(url.absoluteString)
    }
    
    func set(_ response: CachedResponse, for url: URL) async {
        await cache.set(url.absoluteString, value: response)
    }
    
    func clear() async {
        await cache.clear()
    }
    
    func printStats() {
        cache.printStats()
    }
}

// MARK: - Request Deduplication

actor RequestDeduplicator {
    static let shared = RequestDeduplicator()
    
    private var inFlightRequests: [String: Task<Data, Error>] = [:]
    
    func deduplicate<T>(
        key: String,
        request: @escaping () async throws -> T
    ) async throws -> T {
        // If request is already in flight, wait for it
        if let existingTask = inFlightRequests[key] as? Task<T, Error> {
            return try await existingTask.value
        }
        
        // Create new request
        let task = Task<T, Error> {
            defer {
                Task {
                    await removeRequest(key: key)
                }
            }
            return try await request()
        }
        
        inFlightRequests[key] = task as? Task<Data, Error>
        
        return try await task.value
    }
    
    private func removeRequest(key: String) {
        inFlightRequests.removeValue(forKey: key)
    }
}

// MARK: - Smart Cache Warming

@MainActor
class CacheWarmingManager: ObservableObject {
    static let shared = CacheWarmingManager()
    
    @Published var warmingProgress: Double = 0
    
    private init() {}
    
    func warmCriticalContent() async {
        print("🔥 [CacheWarming] Starting critical content warming...")
        
        // Warm up most accessed content
        let criticalURLs: [String] = [
            // Add your critical URLs here
        ]
        
        for (index, url) in criticalURLs.enumerated() {
            // Fetch and cache
            // Implementation would go here
            
            warmingProgress = Double(index + 1) / Double(criticalURLs.count)
        }
        
        print("✅ [CacheWarming] Completed - \(criticalURLs.count) items warmed")
    }
    
    func warmBasedOnUsagePatterns() async {
        // Analyze user behavior and pre-cache likely next requests
        // This would integrate with analytics
    }
}
