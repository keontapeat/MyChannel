//
//  EnhancedFlicksViewModel.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import SwiftUI
import Combine

// 🚀 Enhanced Flicks ViewModel with Industry-Standard Backend
// Integrates all enterprise services with existing FlicksView
@MainActor
class EnhancedFlicksViewModel: ObservableObject {
    @Published var flicks: [NuclearFlick] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    @Published var currentPage = 0
    
    // UI State
    @Published var commentsFlick: NuclearFlick?
    @Published var shareFlick: NuclearFlick?
    @Published var selectedCreatorProfile: User?
    @Published var albumArtRotation: Double = 0
    
    // User Interactions
    @Published var likedFlicks: Set<String> = []
    @Published var followedCreators: Set<String> = []
    
    // Backend Services
    private let backendService = FlicksBackendService.shared
    private let cdnService = FlicksCDNService.shared
    private let mlService = FlicksMLService.shared
    private let performanceMonitor = FlicksPerformanceMonitor()
    
    // Performance Tracking
    private var loadStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    // Album art rotation timer
    private var rotationTimer: Timer?
    
    init() {
        setupAlbumArtRotation()
        loadUserPreferences()
    }
    
    deinit {
        rotationTimer?.invalidate()
    }
    
    // MARK: - Initialization
    
    private func setupAlbumArtRotation() {
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.albumArtRotation += 2.0
                if self.albumArtRotation >= 360 {
                    self.albumArtRotation = 0
                }
            }
        }
    }
    
    private func loadUserPreferences() {
        // Load user's liked flicks and followed creators
        if let userId = getCurrentUserId() {
            Task {
                await loadUserInteractions(userId: userId)
            }
        }
    }
    
    // MARK: - Data Loading
    
    func loadInitialFlicks() async {
        guard !isLoading else { return }
        
        loadStartTime = Date()
        isLoading = true
        error = nil
        currentPage = 0
        
        // Track screen load
        if let startTime = loadStartTime {
            PerformanceMonitoringManager.shared.trackScreenLoad(
                screenName: "FlicksView",
                loadTime: Date().timeIntervalSince(startTime)
            )
        }
        
        do {
            // Load flicks with ML-powered ranking and CDN optimization
            let loadedFlicks = try await backendService.loadFlicks(page: 0, limit: 50)
            
            // Apply personalization if user is logged in
            let personalizedFlicks = await personalizeFlicks(loadedFlicks)
            
            // Preload content for smooth playback
            await preloadFlicksContent(personalizedFlicks.prefix(5))
            
            flicks = personalizedFlicks
            currentPage = 1
            
            // Track successful load
            EnhancedAnalyticsManager.shared.logEvent("flicks_feed_loaded", parameters: [
                "flick_count": flicks.count,
                "load_time_ms": (loadStartTime?.timeIntervalSinceNow ?? 0) * -1000,
                "personalized": getCurrentUserId() != nil
            ])
            
        } catch {
            self.error = error.localizedDescription
            
            // Report error with context
            ErrorReportingManager.shared.reportError(
                error,
                context: "FlicksInitialLoad",
                severity: .error,
                metadata: [
                    "page": 0,
                    "user_id": getCurrentUserId() ?? "anonymous"
                ]
            )
        }
        
        isLoading = false
    }
    
    func loadMoreFlicks() async {
        guard !isLoadingMore && !isLoading else { return }
        
        isLoadingMore = true
        
        do {
            let moreFlicks = try await backendService.loadFlicks(
                page: currentPage,
                limit: 20
            )
            
            let personalizedFlicks = await personalizeFlicks(moreFlicks)
            
            // Preload next batch
            await preloadFlicksContent(personalizedFlicks.prefix(3))
            
            flicks.append(contentsOf: personalizedFlicks)
            currentPage += 1
            
            // Track pagination
            EnhancedAnalyticsManager.shared.logEvent("flicks_pagination", parameters: [
                "page": currentPage,
                "new_flicks_count": personalizedFlicks.count,
                "total_flicks": flicks.count
            ])
            
        } catch {
            // Non-critical error for pagination
            print("Failed to load more flicks: \(error)")
        }
        
        isLoadingMore = false
    }
    
    // MARK: - ML-Powered Personalization
    
    private func personalizeFlicks(_ flicks: [NuclearFlick]) async -> [NuclearFlick] {
        guard let userId = getCurrentUserId(),
              RemoteConfigManager.shared.isRecommendationEngineEnabled else {
            return flicks
        }
        
        do {
            let context = FeedContext(
                timeOfDay: getCurrentTimeOfDay(),
                dayOfWeek: getCurrentDayOfWeek(),
                location: nil,
                deviceType: UIDevice.current.model,
                networkType: "wifi" // Would detect actual network type
            )
            
            return try await mlService.personalizeFlicksFeed(
                flicks: flicks,
                userId: userId,
                context: context
            )
            
        } catch {
            // Return original flicks if personalization fails
            return flicks
        }
    }
    
    // MARK: - Content Preloading
    
    private func preloadFlicksContent(_ flicks: ArraySlice<NuclearFlick>) async {
        let flicksArray = Array(flicks)
        await cdnService.preloadFlicks(flicksArray, priority: .normal)
    }
    
    func preloadVideos(around index: Int, count: Int) {
        let startIndex = max(0, index - count/2)
        let endIndex = min(flicks.count - 1, index + count/2)
        
        let flicksToPreload = Array(flicks[startIndex...endIndex])
        
        Task {
            await cdnService.preloadFlicks(flicksToPreload, priority: .high)
        }
    }
    
    // MARK: - User Interactions
    
    func toggleLike(flick: NuclearFlick) {
        let wasLiked = likedFlicks.contains(flick.id)
        
        if wasLiked {
            likedFlicks.remove(flick.id)
        } else {
            likedFlicks.insert(flick.id)
        }
        
        // Update flick in array
        if let index = flicks.firstIndex(where: { $0.id == flick.id }) {
            // Create updated flick (since NuclearFlick is immutable)
            let updatedFlick = NuclearFlick(
                id: flick.id,
                videoURL: flick.videoURL,
                thumbnailURL: flick.thumbnailURL,
                title: flick.title,
                description: flick.description,
                duration: flick.duration,
                viewCount: flick.viewCount,
                likeCount: wasLiked ? flick.likeCount - 1 : flick.likeCount + 1,
                commentCount: flick.commentCount,
                shareCount: flick.shareCount,
                createdAt: flick.createdAt,
                creator: flick.creator,
                tags: flick.tags,
                musicTrack: flick.musicTrack,
                contentSource: flick.contentSource,
                externalID: flick.externalID
            )
            flicks[index] = updatedFlick
        }
        
        // Track engagement
        Task {
            await backendService.trackFlickEngagement(
                flickId: flick.id,
                action: wasLiked ? "unlike" : "like"
            )
        }
        
        // Save user preference
        saveUserInteraction(type: "like", flickId: flick.id, value: !wasLiked)
    }
    
    func toggleFollow(creator: FlickCreator) {
        if followedCreators.contains(creator.id) {
            followedCreators.remove(creator.id)
        } else {
            followedCreators.insert(creator.id)
        }
        
        // Track follow action
        EnhancedAnalyticsManager.shared.logEvent("creator_follow_toggle", parameters: [
            "creator_id": creator.id,
            "action": followedCreators.contains(creator.id) ? "follow" : "unfollow"
        ])
        
        // Save user preference
        saveUserInteraction(
            type: "follow",
            flickId: creator.id,
            value: followedCreators.contains(creator.id)
        )
    }
    
    func isLiked(flickId: String) -> Bool {
        return likedFlicks.contains(flickId)
    }
    
    func isFollowing(creatorId: String) -> Bool {
        return followedCreators.contains(creatorId)
    }
    
    // MARK: - Navigation
    
    func openComments(flick: NuclearFlick) {
        commentsFlick = flick
        
        EnhancedAnalyticsManager.shared.logEvent("flicks_comments_opened", parameters: [
            "flick_id": flick.id
        ])
    }
    
    func openShare(flick: NuclearFlick) {
        shareFlick = flick
        
        EnhancedAnalyticsManager.shared.logEvent("flicks_share_opened", parameters: [
            "flick_id": flick.id
        ])
    }
    
    func navigateToCreator(_ creator: FlickCreator) {
        let user = User(
            username: creator.username,
            displayName: creator.displayName,
            email: "",
            profileImageURL: creator.profileImageURL,
            bannerImageURL: nil,
            bio: nil,
            subscriberCount: 0,
            videoCount: 0,
            isVerified: creator.isVerified,
            isCreator: true
        )
        
        selectedCreatorProfile = user
        
        EnhancedAnalyticsManager.shared.logEvent("flicks_creator_profile_opened", parameters: [
            "creator_id": creator.id
        ])
    }
    
    func openMoreOptions(flick: NuclearFlick) {
        // Handle more options (report, not interested, etc.)
        EnhancedAnalyticsManager.shared.logEvent("flicks_more_options", parameters: [
            "flick_id": flick.id
        ])
    }
    
    // MARK: - Analytics Tracking
    
    func trackView(flick: NuclearFlick) async {
        await backendService.trackFlickView(flickId: flick.id, watchTime: 1.0)
        
        // Track in enhanced analytics
        EnhancedAnalyticsManager.shared.logEvent("flick_impression", parameters: [
            "flick_id": flick.id,
            "creator_id": flick.creator.id,
            "duration": flick.duration,
            "tags": flick.tags.joined(separator: ",")
        ])
    }
    
    func trackWatchTime(flickId: String, duration: TimeInterval) async {
        await backendService.trackFlickView(flickId: flickId, watchTime: duration)
        
        // Update performance monitoring
        MonitoringDashboardManager.shared.updateMetric("flicks_avg_watch_time", value: duration)
        
        // Track detailed watch analytics
        EnhancedAnalyticsManager.shared.logEvent("flick_watch_time", parameters: [
            "flick_id": flickId,
            "watch_duration": duration,
            "completion_rate": min(duration / 30.0, 1.0) // Assuming 30s average
        ])
    }
    
    // MARK: - Content Moderation
    
    func moderateFlick(_ flick: NuclearFlick) async {
        guard RemoteConfigManager.shared.isContentModerationEnabled else { return }
        
        do {
            let moderationResult = try await mlService.moderateFlick(flick)
            
            if !moderationResult.isApproved {
                // Remove flick from feed
                flicks.removeAll { $0.id == flick.id }
                
                // Log moderation action
                EnhancedAnalyticsManager.shared.logEvent("flick_moderated", parameters: [
                    "flick_id": flick.id,
                    "reason": moderationResult.reason ?? "unknown",
                    "confidence": moderationResult.confidenceScore
                ])
            }
            
        } catch {
            // Non-critical error
            print("Moderation failed for flick \(flick.id): \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserId() -> String? {
        return AppState.shared.currentUser?.id
    }
    
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }
    
    private func getCurrentDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date()).lowercased()
    }
    
    private func loadUserInteractions(userId: String) async {
        // Load user's liked flicks and followed creators from backend
        // This would typically come from a user preferences service
    }
    
    private func saveUserInteraction(type: String, flickId: String, value: Bool) {
        // Save user interaction to backend
        Task {
            // Implementation would save to Firestore or user preferences service
        }
    }
}

// MARK: - Integration Extensions

extension EnhancedFlicksViewModel {
    
    // Method to replace existing ViewModel in FlicksView
    static func createForFlicksView() -> EnhancedFlicksViewModel {
        let viewModel = EnhancedFlicksViewModel()
        
        // Initialize with performance tracking
        Task { @MainActor in
            await viewModel.loadInitialFlicks()
        }
        
        return viewModel
    }
    
    // Compatibility methods for existing FlicksView
    var isLoadingInitial: Bool { isLoading }
    var hasError: Bool { error != nil }
    var errorMessage: String { error ?? "" }
    
    func refreshFeed() async {
        await loadInitialFlicks()
    }
}
