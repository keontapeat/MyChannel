//
//  StoriesIntegrationService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import SwiftUI

// 🔗 Stories Integration Service
// Seamless integration layer for existing Stories UI with enterprise backend
@MainActor
class StoriesIntegrationService: ObservableObject {
    static let shared = StoriesIntegrationService()
    
    @Published var enhancedStories: [EnhancedStory] = []
    @Published var isLoading = false
    @Published var error: String?
    
    // Backend services
    private let enhancedService = EnhancedStoriesService.shared
    private let cdnService = StoriesCDNService.shared
    
    // Story tracking
    private var viewedStories: Set<String> = []
    private var currentStoryIndex = 0
    
    private init() {}
    
    // MARK: - Integration Methods
    
    /// Load stories with enterprise backend while maintaining UI compatibility
    func loadStoriesForHomeView(userId: String) async -> [AssetStory] {
        do {
            // Load enhanced stories from backend
            let enhancedStories = try await enhancedService.loadStories(userId: userId, limit: 50)
            
            // Preload first 5 stories for smooth experience
            await cdnService.preloadStories(Array(enhancedStories.prefix(5)), priority: .high)
            
            // Convert to AssetStory for UI compatibility
            let assetStories = enhancedStories.map { $0.toAssetStory() }
            
            // Update local state
            self.enhancedStories = enhancedStories
            
            // Track analytics
            EnhancedAnalyticsManager.shared.logEvent("stories_loaded_for_home", parameters: [
                "user_id": userId,
                "stories_count": assetStories.count,
                "enhanced_backend": true
            ])
            
            return assetStories
            
        } catch {
            self.error = error.localizedDescription
            
            // Fallback to empty array for graceful degradation
            return []
        }
    }
    
    /// Handle story tap with enhanced tracking
    func handleStoryTap(_ story: AssetStory, allStories: [AssetStory]) {
        // Find enhanced story for detailed tracking
        if let enhancedStory = enhancedStories.first(where: { $0.id == story.creatorId || $0.creatorUsername == story.username }) {
            
            // Track story view start
            Task {
                await enhancedService.trackStoryView(storyId: enhancedStory.id, viewDuration: 0)
            }
            
            // Preload next stories in sequence
            if let currentIndex = allStories.firstIndex(where: { $0.id == story.id }) {
                let nextStories = Array(allStories.dropFirst(currentIndex + 1).prefix(3))
                let nextEnhancedStories = nextStories.compactMap { assetStory in
                    enhancedStories.first { $0.creatorUsername == assetStory.username }
                }
                
                Task {
                    await cdnService.preloadStories(nextEnhancedStories, priority: .normal)
                }
            }
        }
        
        // Mark as viewed
        viewedStories.insert(story.id.uuidString)
        
        // Update seen tracker for UI
        StorySeenTracker.shared.markSeen(userId: AppState.shared.currentUser?.id ?? "anonymous", storyId: story.id.uuidString, creatorId: story.creatorId)
    }
    
    /// Handle story upload with enterprise backend
    func uploadStory(mediaData: Data, mediaType: StoryMediaType, metadata: StoryUploadMetadata) async throws -> String {
        return try await enhancedService.uploadStory(
            mediaData: mediaData,
            mediaType: mediaType,
            metadata: metadata
        )
    }
    
    /// Get optimized story image for UI
    func getOptimizedStoryImage(url: String, size: CGSize = CGSize(width: 400, height: 700)) async -> UIImage? {
        do {
            return try await cdnService.loadStoryImage(url: url, size: size)
        } catch {
            return nil
        }
    }
    
    /// Track story engagement (like, share, etc.)
    func trackStoryEngagement(storyId: String, action: String, userId: String) async {
        await enhancedService.trackStoryEngagement(storyId: storyId, action: action, userId: userId)
    }
    
    /// Optimize for Stories viewing session
    func startStoriesSession() {
        cdnService.optimizeForStoriesViewing()
        
        EnhancedAnalyticsManager.shared.logEvent("stories_session_started", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Clean up after Stories session
    func endStoriesSession() {
        cdnService.resetOptimizations()
        
        EnhancedAnalyticsManager.shared.logEvent("stories_session_ended", parameters: [
            "stories_viewed": viewedStories.count,
            "session_duration": 0 // Would track actual duration
        ])
        
        // Reset session data
        viewedStories.removeAll()
        currentStoryIndex = 0
    }
    
    /// Get Stories performance statistics
    func getStoriesStatistics() -> StoriesStatistics {
        let cacheStats = cdnService.getStoriesCacheStatistics()
        
        return StoriesStatistics(
            totalStoriesLoaded: enhancedStories.count,
            storiesViewed: viewedStories.count,
            cacheHitRate: cacheStats.hitRate,
            averageLoadTime: cacheStats.averageLoadTime,
            totalCacheSize: cacheStats.totalCacheSize
        )
    }
}

// MARK: - Enhanced AssetStory Extension

extension AssetStory {
    /// Create AssetStory from EnhancedStory for backward compatibility
    static func from(enhancedStory: EnhancedStory) -> AssetStory {
        let media: AssetMedia = enhancedStory.mediaType == .video 
            ? .video(enhancedStory.mediaURL) 
            : .image(enhancedStory.mediaURL)
        
        var assetStory = AssetStory(
            media: media,
            username: enhancedStory.creatorUsername,
            authorImageName: enhancedStory.creatorAvatarURL
        )
        assetStory.creatorId = enhancedStory.creatorId
        return assetStory
    }
}

// MARK: - Story Seen Tracker Enhancement

extension StorySeenTracker {
    /// Enhanced tracking with backend sync
    func markAsSeenWithSync(username: String, storyId: String) {
        markSeen(userId: getCurrentUserId(), storyId: storyId, creatorId: username)
        
        // Sync with backend analytics
        Task {
            await StoriesIntegrationService.shared.trackStoryEngagement(
                storyId: storyId,
                action: "viewed_complete",
                userId: getCurrentUserId()
            )
        }
    }
    
    @MainActor private func getCurrentUserId() -> String {
        return AppState.shared.currentUser?.id ?? "anonymous"
    }
}

// MARK: - Supporting Types

struct StoriesStatistics {
    let totalStoriesLoaded: Int
    let storiesViewed: Int
    let cacheHitRate: Double
    let averageLoadTime: TimeInterval
    let totalCacheSize: Int64
}

// MARK: - HomeView Integration Helper

extension StoriesIntegrationService {
    /// Get stories for HomeView with all enterprise features
    func getStoriesForHomeView(userId: String) async -> [AssetStory] {
        isLoading = true
        error = nil
        
        let stories = await loadStoriesForHomeView(userId: userId)
        
        isLoading = false
        return stories
    }
    
    /// Handle add story action with enterprise upload
    func handleAddStoryAction(completion: @escaping (Result<String, Error>) -> Void) {
        // This would integrate with camera/photo picker
        // For now, we'll just track the intent
        EnhancedAnalyticsManager.shared.logEvent("story_creation_initiated", parameters: [
            "source": "home_view",
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // In a real implementation, this would:
        // 1. Present camera/photo picker
        // 2. Allow user to select media
        // 3. Apply filters/effects
        // 4. Upload using uploadStory method
        // 5. Call completion with result
    }
}
