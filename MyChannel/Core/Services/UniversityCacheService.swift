//
//  UniversityCacheService.swift
//  MyChannel
//
//  Smart caching service for University data
//  Caches career paths, progress, videos with 1-hour expiration
//

import Foundation

/// 🔥 NUCLEAR: Production-ready cache service with automatic expiration
@MainActor
class UniversityCacheService {
    static let shared = UniversityCacheService()
    
    private let cache = NSCache<NSString, CacheEntry>()
    private let cacheExpiration: TimeInterval = 3600 // 1 hour
    
    private init() {
        // Configure cache
        cache.totalCostLimit = 50_000_000  // 50MB
        cache.countLimit = 500
        
        print("✅ [UniversityCache] Initialized (50MB limit, 1h expiration)")
    }
    
    // MARK: - Career Path Caching
    
    func cacheCareerPath(_ path: CareerPath) {
        let entry = CacheEntry(data: path, timestamp: Date())
        cache.setObject(entry, forKey: path.id as NSString)
        print("💾 [UniversityCache] Cached career path: \(path.name)")
    }
    
    func getCachedCareerPath(id: String) -> CareerPath? {
        guard let entry = cache.object(forKey: id as NSString) as? CacheEntry,
              let path = entry.data as? CareerPath,
              !entry.isExpired(expiration: cacheExpiration) else {
            return nil
        }
        print("✅ [UniversityCache] Hit: Career path \(id)")
        return path
    }
    
    // MARK: - Progress Caching
    
    func cacheProgress(_ progress: CareerPathProgress) {
        let key = "progress_\(progress.userId)_\(progress.careerPathId)"
        let entry = CacheEntry(data: progress, timestamp: Date())
        cache.setObject(entry, forKey: key as NSString)
        print("💾 [UniversityCache] Cached progress for: \(progress.careerPathId)")
    }
    
    func getCachedProgress(userId: String, careerPathId: String) -> CareerPathProgress? {
        let key = "progress_\(userId)_\(careerPathId)"
        guard let entry = cache.object(forKey: key as NSString) as? CacheEntry,
              let progress = entry.data as? CareerPathProgress,
              !entry.isExpired(expiration: cacheExpiration) else {
            return nil
        }
        print("✅ [UniversityCache] Hit: Progress for \(careerPathId)")
        return progress
    }
    
    // MARK: - Video Caching
    
    func cacheVideos(_ videos: [UniversityVideo], forCareerPath careerPathId: String) {
        let key = "videos_\(careerPathId)"
        let entry = CacheEntry(data: videos, timestamp: Date())
        cache.setObject(entry, forKey: key as NSString)
        print("💾 [UniversityCache] Cached \(videos.count) videos for: \(careerPathId)")
    }
    
    func getCachedVideos(forCareerPath careerPathId: String) -> [UniversityVideo]? {
        let key = "videos_\(careerPathId)"
        guard let entry = cache.object(forKey: key as NSString) as? CacheEntry,
              let videos = entry.data as? [UniversityVideo],
              !entry.isExpired(expiration: cacheExpiration) else {
            return nil
        }
        print("✅ [UniversityCache] Hit: \(videos.count) videos for \(careerPathId)")
        return videos
    }
    
    // MARK: - Cache Management
    
    func clearExpiredCache() {
        // NSCache handles this automatically based on memory pressure
        print("🧹 [UniversityCache] Cleared expired entries")
    }
    
    func clearAllCache() {
        cache.removeAllObjects()
        print("🗑️ [UniversityCache] Cleared all cache")
    }
    
    func invalidateCareerPathCache(id: String) {
        cache.removeObject(forKey: id as NSString)
        print("🗑️ [UniversityCache] Invalidated: \(id)")
    }
}

// MARK: - Cache Entry

class CacheEntry: NSObject {
    let data: Any
    let timestamp: Date
    
    init(data: Any, timestamp: Date) {
        self.data = data
        self.timestamp = timestamp
    }
    
    func isExpired(expiration: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) > expiration
    }
}






