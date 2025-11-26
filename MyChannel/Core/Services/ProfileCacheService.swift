//
//  ProfileCacheService.swift
//  MyChannel
//
//  THERMONUCLEAR PERFORMANCE: Instant profile loading with caching
//

import Foundation
import SwiftUI

/// ⚡ PERFORMANCE: Cache profile data for instant display
/// Shows cached data immediately, refreshes in background
@MainActor
final class ProfileCacheService: ObservableObject {
    static let shared = ProfileCacheService()
    
    // MARK: - Cache Keys
    private let userCacheKey = "cached_profile_user"
    private let videosCacheKey = "cached_profile_videos"
    private let cacheTimestampKey = "cached_profile_timestamp"
    
    // MARK: - In-Memory Cache (fastest)
    private var memoryUserCache: User?
    private var memoryVideosCache: [Video] = []
    private var lastCacheTime: Date?
    
    // Cache validity: 5 minutes for memory, 1 hour for disk
    private let memoryCacheValidity: TimeInterval = 300 // 5 minutes
    private let diskCacheValidity: TimeInterval = 3600 // 1 hour
    
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    /// Get cached user (instant)
    func getCachedUser() -> User? {
        return memoryUserCache
    }
    
    /// Get cached videos (instant)
    func getCachedVideos() -> [Video] {
        return memoryVideosCache
    }
    
    /// Check if cache is valid (within 5 minutes)
    func isCacheValid() -> Bool {
        guard let lastCache = lastCacheTime else { return false }
        return Date().timeIntervalSince(lastCache) < memoryCacheValidity
    }
    
    /// Cache user and videos
    func cacheProfile(user: User, videos: [Video]) {
        // Memory cache (instant)
        memoryUserCache = user
        memoryVideosCache = videos
        lastCacheTime = Date()
        
        // Disk cache (background, for app restart)
        Task.detached(priority: .background) { [weak self] in
            await self?.saveToDisk(user: user, videos: videos)
        }
        
        print("✅ [ProfileCache] Cached \(videos.count) videos for \(user.displayName)")
    }
    
    /// Update just the videos (keeps user cached)
    func updateCachedVideos(_ videos: [Video]) {
        memoryVideosCache = videos
        lastCacheTime = Date()
        
        if let user = memoryUserCache {
            Task.detached(priority: .background) { [weak self] in
                await self?.saveToDisk(user: user, videos: videos)
            }
        }
    }
    
    /// Add a single video to cache (for uploads)
    func addVideoToCache(_ video: Video) {
        // Add to beginning (newest first)
        memoryVideosCache.insert(video, at: 0)
        
        if let user = memoryUserCache {
            Task.detached(priority: .background) { [weak self] in
                await self?.saveToDisk(user: user, videos: self?.memoryVideosCache ?? [])
            }
        }
        
        print("✅ [ProfileCache] Added new video to cache: \(video.title)")
    }
    
    /// Remove a video from cache (for deletes)
    func removeVideoFromCache(_ videoId: String) {
        memoryVideosCache.removeAll { $0.id == videoId }
        
        if let user = memoryUserCache {
            Task.detached(priority: .background) { [weak self] in
                await self?.saveToDisk(user: user, videos: self?.memoryVideosCache ?? [])
            }
        }
    }
    
    /// Clear all cache
    func clearCache() {
        memoryUserCache = nil
        memoryVideosCache = []
        lastCacheTime = nil
        
        UserDefaults.standard.removeObject(forKey: userCacheKey)
        UserDefaults.standard.removeObject(forKey: videosCacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
        
        print("🗑️ [ProfileCache] Cache cleared")
    }
    
    // MARK: - Disk Persistence
    
    private func saveToDisk(user: User, videos: [Video]) {
        do {
            let userEncoder = JSONEncoder()
            let userData = try userEncoder.encode(user)
            UserDefaults.standard.set(userData, forKey: userCacheKey)
            
            // Only cache first 50 videos to keep storage small
            let videosToCache = Array(videos.prefix(50))
            let videosEncoder = JSONEncoder()
            let videosData = try videosEncoder.encode(videosToCache)
            UserDefaults.standard.set(videosData, forKey: videosCacheKey)
            
            UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
            
            print("💾 [ProfileCache] Saved to disk: \(videosToCache.count) videos")
        } catch {
            print("🚨 [ProfileCache] Failed to save to disk: \(error)")
        }
    }
    
    private func loadFromDisk() {
        // Check timestamp first
        if let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date {
            // Skip if cache is too old
            if Date().timeIntervalSince(timestamp) > diskCacheValidity {
                print("⏰ [ProfileCache] Disk cache expired")
                return
            }
            lastCacheTime = timestamp
        }
        
        // Load user
        if let userData = UserDefaults.standard.data(forKey: userCacheKey) {
            do {
                let user = try JSONDecoder().decode(User.self, from: userData)
                memoryUserCache = user
                print("💾 [ProfileCache] Loaded user from disk: \(user.displayName)")
            } catch {
                print("🚨 [ProfileCache] Failed to load user from disk: \(error)")
            }
        }
        
        // Load videos
        if let videosData = UserDefaults.standard.data(forKey: videosCacheKey) {
            do {
                let videos = try JSONDecoder().decode([Video].self, from: videosData)
                memoryVideosCache = videos
                print("💾 [ProfileCache] Loaded \(videos.count) videos from disk")
            } catch {
                print("🚨 [ProfileCache] Failed to load videos from disk: \(error)")
            }
        }
    }
}

// MARK: - Video Skeleton View (for loading state)
struct ProfileVideoCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(shimmerGradient)
                .aspectRatio(16/9, contentMode: .fit)
            
            // Title skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(height: 14)
            
            // Metadata skeleton
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: 60, height: 12)
                
                Circle()
                    .fill(AppTheme.Colors.textTertiary.opacity(0.3))
                    .frame(width: 4, height: 4)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: 40, height: 12)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
    
    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppTheme.Colors.surface.opacity(0.6),
                AppTheme.Colors.surface.opacity(0.9),
                AppTheme.Colors.surface.opacity(0.6)
            ],
            startPoint: isAnimating ? .leading : .trailing,
            endPoint: isAnimating ? .trailing : .leading
        )
    }
}

// MARK: - List Video Skeleton
struct ProfileListVideoCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(shimmerGradient)
                .frame(width: 120, height: 68)
            
            VStack(alignment: .leading, spacing: 6) {
                // Title skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: 100, height: 14)
                
                // Metadata skeleton
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 60, height: 12)
                    
                    Circle()
                        .fill(AppTheme.Colors.textTertiary.opacity(0.3))
                        .frame(width: 4, height: 4)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 40, height: 12)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
    
    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppTheme.Colors.surface.opacity(0.6),
                AppTheme.Colors.surface.opacity(0.9),
                AppTheme.Colors.surface.opacity(0.6)
            ],
            startPoint: isAnimating ? .leading : .trailing,
            endPoint: isAnimating ? .trailing : .leading
        )
    }
}

// MARK: - Videos Loading Skeleton Grid
struct VideosLoadingSkeletonGrid: View {
    let count: Int
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                VideoCardSkeleton()
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Videos Loading Skeleton List
struct VideosLoadingSkeletonList: View {
    let count: Int
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                ProfileListVideoCardSkeleton()
            }
        }
    }
}

#Preview("Profile Video Card Skeleton") {
    VStack(spacing: 20) {
        ProfileVideoCardSkeleton()
            .frame(width: 180)
        
        ProfileListVideoCardSkeleton()
    }
    .padding()
    .background(AppTheme.Colors.background)
}

#Preview("Videos Loading Skeleton Grid") {
    ScrollView {
        VideosLoadingSkeletonGrid(count: 6)
    }
    .background(AppTheme.Colors.background)
}
