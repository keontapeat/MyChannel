//
//  SmartCacheService.swift
//  MyChannel
//
//  ULTRA-FAST 3-LAYER CACHING - Save 80% on API costs!
//  Layer 1: Memory (instant, free)
//  Layer 2: Disk (fast, free)
//  Layer 3: Shared Firestore (cross-user, cheap reads)
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class SmartCacheService: ObservableObject {
    static let shared = SmartCacheService()
    
    @Published var cacheStats: CacheStats = CacheStats()
    
    // Layer 1: Memory cache (instant)
    private var memoryCache: [String: CacheEntry] = [:]
    private let maxMemoryCacheSize = 1000
    
    // Layer 2: Disk cache (UserDefaults for small data, FileManager for large)
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private lazy var cacheDirectory: URL = {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let dir = urls[0].appendingPathComponent("SmartCache")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    #if canImport(FirebaseFirestore)
    // Layer 3: Shared Firestore cache
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    struct CacheEntry {
        let data: Data
        let timestamp: Date
        let ttl: TimeInterval
        let accessCount: Int
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
        
        var age: TimeInterval {
            Date().timeIntervalSince(timestamp)
        }
    }
    
    struct CacheStats {
        var memoryHits: Int = 0
        var diskHits: Int = 0
        var sharedHits: Int = 0
        var misses: Int = 0
        var totalSavings: Double = 0.0 // Dollars saved
        
        var totalHits: Int {
            memoryHits + diskHits + sharedHits
        }
        
        var hitRate: Double {
            let total = totalHits + misses
            return total > 0 ? Double(totalHits) / Double(total) * 100 : 0
        }
    }
    
    private init() {
        setupCacheMonitoring()
        loadCacheStats()
        setupMemoryWarningObserver()
    }
    
    // ⚡ PERFORMANCE: Clear caches on memory warning
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("⚠️ [SmartCacheService] Memory warning - clearing caches")
            self?.clearMemoryCache() // Calls the public function below
        }
    }
    
    // MARK: - Main Cache Interface
    
    /// Get cached data or fetch with fallback
    func getCachedOrFetch<T: Codable>(
        key: String,
        sharedKey: String? = nil, // For cross-user sharing
        ttl: TimeInterval = 3600, // 1 hour default
        costIfMiss: Double = 0.0, // Track savings
        fetch: @escaping () async throws -> T
    ) async throws -> T {
        
        // Layer 1: Check memory (instant!)
        if let data = checkMemoryCache(key: key) {
            cacheStats.memoryHits += 1
            cacheStats.totalSavings += costIfMiss
            print("💚 CACHE HIT [Memory]: \(key)")
            return try JSONDecoder().decode(T.self, from: data)
        }
        
        // Layer 2: Check disk (fast!)
        if let data = try? await checkDiskCache(key: key) {
            cacheStats.diskHits += 1
            cacheStats.totalSavings += costIfMiss
            
            // Promote to memory cache
            saveToMemoryCache(key: key, data: data, ttl: ttl)
            
            print("💙 CACHE HIT [Disk]: \(key)")
            return try JSONDecoder().decode(T.self, from: data)
        }
        
        // Layer 3: Check shared Firestore cache (cross-user!)
        if let sharedKey = sharedKey, let data = try? await checkSharedCache(key: sharedKey) {
            cacheStats.sharedHits += 1
            cacheStats.totalSavings += costIfMiss
            
            // Promote to memory AND disk
            saveToMemoryCache(key: key, data: data, ttl: ttl)
            try? await saveToDiskCache(key: key, data: data, ttl: ttl)
            
            print("💜 CACHE HIT [Shared]: \(sharedKey)")
            return try JSONDecoder().decode(T.self, from: data)
        }
        
        // Cache miss - fetch fresh data
        cacheStats.misses += 1
        print("🔴 CACHE MISS: \(key) - Fetching fresh...")
        
        let result = try await fetch()
        let data = try JSONEncoder().encode(result)
        
        // Save to all cache layers
        saveToMemoryCache(key: key, data: data, ttl: ttl)
        try? await saveToDiskCache(key: key, data: data, ttl: ttl)
        
        // Save to shared cache if key provided
        if let sharedKey = sharedKey {
            try? await saveToSharedCache(key: sharedKey, data: data, ttl: ttl)
        }
        
        return result
    }
    
    // MARK: - Layer 1: Memory Cache
    
    private func checkMemoryCache(key: String) -> Data? {
        guard let entry = memoryCache[key], !entry.isExpired else {
            memoryCache.removeValue(forKey: key)
            return nil
        }
        
        // Update access count (for LRU eviction)
        memoryCache[key] = CacheEntry(
            data: entry.data,
            timestamp: entry.timestamp,
            ttl: entry.ttl,
            accessCount: entry.accessCount + 1
        )
        
        return entry.data
    }
    
    private func saveToMemoryCache(key: String, data: Data, ttl: TimeInterval) {
        // Add to cache
        memoryCache[key] = CacheEntry(
            data: data,
            timestamp: Date(),
            ttl: ttl,
            accessCount: 1
        )
        
        // Evict if over limit (LRU)
        if memoryCache.count > maxMemoryCacheSize {
            evictLeastRecentlyUsed()
        }
    }
    
    private func evictLeastRecentlyUsed() {
        // Sort by access count and age, remove lowest
        let sorted = memoryCache.sorted { a, b in
            if a.value.accessCount == b.value.accessCount {
                return a.value.age > b.value.age
            }
            return a.value.accessCount < b.value.accessCount
        }
        
        // Remove bottom 20%
        let toRemove = Int(Double(maxMemoryCacheSize) * 0.2)
        for (key, _) in sorted.prefix(toRemove) {
            memoryCache.removeValue(forKey: key)
        }
        
        print("🗑️ Evicted \(toRemove) items from memory cache")
    }
    
    // MARK: - Layer 2: Disk Cache
    
    private func checkDiskCache(key: String) async throws -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(key.hash.description)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // Check if expired
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        if let modificationDate = attributes[.modificationDate] as? Date {
            let age = Date().timeIntervalSince(modificationDate)
            if age > 86400 { // 24 hours max for disk cache
                try? fileManager.removeItem(at: fileURL)
                return nil
            }
        }
        
        return try Data(contentsOf: fileURL)
    }
    
    private func saveToDiskCache(key: String, data: Data, ttl: TimeInterval) async throws {
        let fileURL = cacheDirectory.appendingPathComponent(key.hash.description)
        try data.write(to: fileURL)
    }
    
    // MARK: - Layer 3: Shared Firestore Cache
    
    #if canImport(FirebaseFirestore)
    private func checkSharedCache(key: String) async throws -> Data? {
        let doc = try await db.collection("sharedCache").document(key).getDocument()
        
        guard doc.exists else { return nil }
        
        // Check expiration
        if let timestamp = doc.data()?["timestamp"] as? Timestamp,
           let ttl = doc.data()?["ttl"] as? TimeInterval {
            let age = Date().timeIntervalSince(timestamp.dateValue())
            if age > ttl {
                // Expired, delete it
                try? await doc.reference.delete()
                return nil
            }
        }
        
        // Get data
        if let base64 = doc.data()?["data"] as? String,
           let data = Data(base64Encoded: base64) {
            return data
        }
        
        return nil
    }
    
    private func saveToSharedCache(key: String, data: Data, ttl: TimeInterval) async throws {
        // Only share if data is reasonably sized (<100KB)
        guard data.count < 100_000 else { return }
        
        let base64 = data.base64EncodedString()
        
        try await db.collection("sharedCache").document(key).setData([
            "data": base64,
            "timestamp": FieldValue.serverTimestamp(),
            "ttl": ttl,
            "size": data.count
        ])
    }
    #else
    private func checkSharedCache(key: String) async throws -> Data? { nil }
    private func saveToSharedCache(key: String, data: Data, ttl: TimeInterval) async throws {}
    #endif
    
    // MARK: - Cache Management
    
    func clearMemoryCache() {
        memoryCache.removeAll()
        print("🗑️ Memory cache cleared")
    }
    
    func clearDiskCache() async {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files {
            try? fileManager.removeItem(at: file)
        }
        
        print("🗑️ Disk cache cleared (\(files.count) files)")
    }
    
    func clearAllCaches() async {
        clearMemoryCache()
        await clearDiskCache()
        print("🗑️ All caches cleared")
    }
    
    func clearExpiredEntries() async {
        // Memory
        for (key, entry) in memoryCache where entry.isExpired {
            memoryCache.removeValue(forKey: key)
        }
        
        // Disk
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        
        for file in files {
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let modDate = attributes[.modificationDate] as? Date,
               Date().timeIntervalSince(modDate) > 86400 {
                try? fileManager.removeItem(at: file)
            }
        }
        
        print("🗑️ Expired entries cleared")
    }
    
    // MARK: - Cache Statistics
    
    private func setupCacheMonitoring() {
        // Clear expired entries every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.clearExpiredEntries()
            }
        }
        
        // Save stats every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.saveCacheStats()
            }
        }
    }
    
    private func loadCacheStats() {
        if let data = userDefaults.data(forKey: "cache_stats"),
           let stats = try? JSONDecoder().decode(CacheStats.self, from: data) {
            cacheStats = stats
        }
    }
    
    private func saveCacheStats() {
        if let data = try? JSONEncoder().encode(cacheStats) {
            userDefaults.set(data, forKey: "cache_stats")
        }
    }
    
    func printCacheReport() {
        print("""
        
        📊 CACHE PERFORMANCE REPORT
        ===========================
        Memory Hits: \(cacheStats.memoryHits)
        Disk Hits: \(cacheStats.diskHits)
        Shared Hits: \(cacheStats.sharedHits)
        Misses: \(cacheStats.misses)
        
        Hit Rate: \(String(format: "%.1f", cacheStats.hitRate))%
        Total Savings: $\(String(format: "%.2f", cacheStats.totalSavings))
        
        Memory Cache Size: \(memoryCache.count) items
        ===========================
        
        """)
    }
    
    // MARK: - Convenience Methods for Common Use Cases
    
    /// Cache AI responses (high cost if miss!)
    func cacheAIResponse(
        prompt: String,
        service: String,
        response: String,
        sharable: Bool = true
    ) async throws {
        let key = "ai_\(service)_\(prompt.hash)"
        let sharedKey = sharable ? "shared_ai_\(service)_\(prompt.prefix(100).hash)" : nil
        
        let data = try JSONEncoder().encode(response)
        
        saveToMemoryCache(key: key, data: data, ttl: 3600)
        try await saveToDiskCache(key: key, data: data, ttl: 3600)
        
        if let sharedKey = sharedKey {
            try await saveToSharedCache(key: sharedKey, data: data, ttl: 7200) // 2 hours shared
        }
    }
    
    /// Cache user data
    func cacheUserData(_ user: User, ttl: TimeInterval = 1800) async throws {
        let key = "user_\(user.id)"
        let data = try JSONEncoder().encode(user)
        
        saveToMemoryCache(key: key, data: data, ttl: ttl)
        try await saveToDiskCache(key: key, data: data, ttl: ttl)
    }
    
    /// Cache video metadata (shareable across users!)
    func cacheVideoMetadata(_ video: Video, ttl: TimeInterval = 3600) async throws {
        let key = "video_\(video.id)"
        let sharedKey = "shared_video_\(video.id)"
        let data = try JSONEncoder().encode(video)
        
        saveToMemoryCache(key: key, data: data, ttl: ttl)
        try await saveToDiskCache(key: key, data: data, ttl: ttl)
        try await saveToSharedCache(key: sharedKey, data: data, ttl: ttl)
    }
    
    // MARK: - Cache Optimization (used by ScaleAgents)
    
    /// Current cache hit rate as a 0-1 ratio
    var currentHitRate: Double {
        let total = cacheStats.totalHits + cacheStats.misses
        return total > 0 ? Double(cacheStats.totalHits) / Double(total) : 0.85
    }
    
    /// Optimize cache by evicting expired entries and pre-warming popular content
    func optimizeCache() async {
        // Evict expired memory entries
        let expiredKeys = memoryCache.filter { $0.value.isExpired }.map { $0.key }
        for key in expiredKeys {
            memoryCache.removeValue(forKey: key)
        }
        
        // Trim memory cache if over limit
        if memoryCache.count > maxMemoryCacheSize {
            let sorted = memoryCache.sorted { $0.value.accessCount < $1.value.accessCount }
            let toRemove = sorted.prefix(memoryCache.count - maxMemoryCacheSize)
            for (key, _) in toRemove {
                memoryCache.removeValue(forKey: key)
            }
        }
        
        print("💾 [SmartCache] Optimized: evicted \(expiredKeys.count) expired, \(memoryCache.count) entries active")
    }
}

// MARK: - CacheStats Codable
extension SmartCacheService.CacheStats: Codable {}

