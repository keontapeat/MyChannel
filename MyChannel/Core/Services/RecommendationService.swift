//
//  RecommendationService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import Combine

// MARK: - Recommendation Models
struct RecommendationContext {
    let userId: String
    let currentVideo: Video?
    let watchHistory: [Video]
    let likedVideos: [Video]
    let subscriptions: [String] // Creator IDs
    let searchHistory: [String]
    let categories: [VideoCategory]
    let timeOfDay: Date
    let deviceType: DeviceType
    
    enum DeviceType {
        case phone, tablet, desktop
    }
}

struct RecommendationResult {
    let videos: [Video]
    let reason: RecommendationReason
    let confidence: Double // 0.0 to 1.0
    let source: RecommendationSource
}

enum RecommendationReason: String, CaseIterable {
    case trending = "Trending now"
    case basedOnHistory = "Based on your watch history"
    case fromSubscriptions = "From your subscriptions"
    case similarContent = "Similar to what you watched"
    case popularInCategory = "Popular in %@"
    case newFromCreator = "New from creators you follow"
    case collaborative = "People also watched"
    case seasonal = "Popular this week"
    case personalizedMix = "Mixed for you"
}

enum RecommendationSource {
    case trending
    case collaborative
    case contentBased
    case social
    case contextual
    case hybrid
}

// MARK: - Recommendation Service Protocol
protocol RecommendationServiceProtocol {
    func getHomeRecommendations(for userId: String, limit: Int) async throws -> [RecommendationResult]
    func getSimilarVideos(to video: Video, limit: Int) async throws -> [Video]
    func getTrendingVideos(category: VideoCategory?, limit: Int) async throws -> [Video]
    func getRecommendationsAfterVideo(_ video: Video, userId: String, limit: Int) async throws -> [Video]
    func getPersonalizedFeed(context: RecommendationContext, limit: Int) async throws -> [RecommendationResult]
    func trackUserInteraction(_ interaction: UserInteraction)
    func updateRecommendationModel(userId: String) async throws
}

// MARK: - User Interaction Tracking
struct UserInteraction {
    let userId: String
    let videoId: String
    let interactionType: InteractionType
    let duration: TimeInterval?
    let timestamp: Date
    let context: InteractionContext?
    
    enum InteractionType {
        case view, like, dislike, comment, share, skip, watchComplete
        case addToPlaylist, saveToWatchLater, subscribe
    }
    
    struct InteractionContext {
        let source: String // "home", "search", "related", etc.
        let position: Int? // Position in list/grid
        let sessionId: String
    }
}

// MARK: - Smart Recommendation Service
class SmartRecommendationService: RecommendationServiceProtocol, ObservableObject {
    @Published var isLoading = false
    
    private var userInteractions: [UserInteraction] = []
    private var userProfiles: [String: RecommendationUserProfile] = [:]
    
    // MARK: - Public Methods
    func getHomeRecommendations(for userId: String, limit: Int) async throws -> [RecommendationResult] {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        let profile = getRecommendationUserProfile(userId: userId)
        var recommendations: [RecommendationResult] = []
        
        // 1. Trending videos (20% of recommendations)
        let trendingCount = max(1, limit / 5)
        let trendingVideos = try await getTrendingVideos(category: nil, limit: trendingCount)
        recommendations.append(RecommendationResult(
            videos: trendingVideos,
            reason: .trending,
            confidence: 0.8,
            source: .trending
        ))
        
        // 2. Based on subscriptions (30% of recommendations)
        let subscriptionCount = max(1, (limit * 3) / 10)
        let subscriptionVideos = getVideosFromSubscriptions(profile: profile, limit: subscriptionCount)
        recommendations.append(RecommendationResult(
            videos: subscriptionVideos,
            reason: .fromSubscriptions,
            confidence: 0.9,
            source: .social
        ))
        
        // 3. Similar to watch history (25% of recommendations)
        let historyCount = max(1, limit / 4)
        let historyVideos = getVideosBasedOnHistory(profile: profile, limit: historyCount)
        recommendations.append(RecommendationResult(
            videos: historyVideos,
            reason: .basedOnHistory,
            confidence: 0.85,
            source: .contentBased
        ))
        
        // 4. Popular in favorite categories (25% of recommendations)
        let categoryCount = limit - trendingCount - subscriptionCount - historyCount
        let categoryVideos = getPopularInCategories(profile: profile, limit: categoryCount)
        recommendations.append(RecommendationResult(
            videos: categoryVideos,
            reason: .popularInCategory,
            confidence: 0.75,
            source: .contextual
        ))
        
        return recommendations
    }
    
    func getSimilarVideos(to video: Video, limit: Int) async throws -> [Video] {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Find videos with similar attributes
        var similarVideos = Video.sampleVideos.filter { candidate in
            candidate.id != video.id && (
                candidate.category == video.category ||
                candidate.creator.id == video.creator.id ||
                !Set(candidate.tags).isDisjoint(with: Set(video.tags))
            )
        }
        
        // Sort by similarity score
        similarVideos = similarVideos.sorted { video1, video2 in
            let score1 = calculateSimilarityScore(video1, to: video)
            let score2 = calculateSimilarityScore(video2, to: video)
            return score1 > score2
        }
        
        return Array(similarVideos.prefix(limit))
    }
    
    func getTrendingVideos(category: VideoCategory?, limit: Int) async throws -> [Video] {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        var videos = Video.sampleVideos
        
        if let category = category {
            videos = videos.filter { $0.category == category }
        }
        
        // Sort by trending score (views + recent engagement)
        videos = videos.sorted { video1, video2 in
            let trend1 = calculateTrendingScore(video1)
            let trend2 = calculateTrendingScore(video2)
            return trend1 > trend2
        }
        
        return Array(videos.prefix(limit))
    }
    
    func getRecommendationsAfterVideo(_ video: Video, userId: String, limit: Int) async throws -> [Video] {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        let profile = getRecommendationUserProfile(userId: userId)
        
        // Mix of similar videos and personalized recommendations
        let similarCount = limit / 2
        let personalizedCount = limit - similarCount
        
        async let similarVideos = getSimilarVideos(to: video, limit: similarCount)
        let personalizedVideos = getVideosBasedOnHistory(profile: profile, limit: personalizedCount)
        
        let similar = try await similarVideos
        let combined = similar + personalizedVideos
        
        // Remove duplicates and shuffle
        let uniqueVideos = Array(Set(combined))
        return Array(uniqueVideos.shuffled().prefix(limit))
    }
    
    func getPersonalizedFeed(context: RecommendationContext, limit: Int) async throws -> [RecommendationResult] {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 second
        
        let profile = getRecommendationUserProfile(userId: context.userId)
        var recommendations: [RecommendationResult] = []
        
        // Time-based recommendations
        let timeBasedVideos = getTimeBasedRecommendations(context: context, limit: limit / 4)
        recommendations.append(RecommendationResult(
            videos: timeBasedVideos,
            reason: .seasonal,
            confidence: 0.7,
            source: .contextual
        ))
        
        // Collaborative filtering
        let collaborativeVideos = getCollaborativeRecommendations(profile: profile, limit: limit / 4)
        recommendations.append(RecommendationResult(
            videos: collaborativeVideos,
            reason: .collaborative,
            confidence: 0.8,
            source: .collaborative
        ))
        
        // Hybrid recommendations
        let hybridVideos = getHybridRecommendations(context: context, limit: limit / 2)
        recommendations.append(RecommendationResult(
            videos: hybridVideos,
            reason: .personalizedMix,
            confidence: 0.9,
            source: .hybrid
        ))
        
        return recommendations
    }
    
    func trackUserInteraction(_ interaction: UserInteraction) {
        userInteractions.append(interaction)
        
        // Update user profile based on interaction
        var profile = getRecommendationUserProfile(userId: interaction.userId)
        profile.updateWithInteraction(interaction)
        userProfiles[interaction.userId] = profile
        
        // In a real app, this would be sent to analytics service
        print("Tracked interaction: \(interaction.interactionType) for video \(interaction.videoId)")
    }
    
    func updateRecommendationModel(userId: String) async throws {
        // In a real app, this would retrain the ML model
        print("Updating recommendation model for user \(userId)")
    }
    
    // MARK: - Private Helper Methods
    private func getRecommendationUserProfile(userId: String) -> RecommendationUserProfile {
        return userProfiles[userId] ?? RecommendationUserProfile(userId: userId)
    }
    
    private func getVideosFromSubscriptions(profile: RecommendationUserProfile, limit: Int) -> [Video] {
        let subscriptionVideos = Video.sampleVideos.filter { video in
            profile.subscriptions.contains(video.creator.id)
        }
        
        return Array(subscriptionVideos.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }
    
    private func getVideosBasedOnHistory(profile: RecommendationUserProfile, limit: Int) -> [Video] {
        var recommendedVideos: [Video] = []
        
        // Based on favorite categories
        for category in profile.favoriteCategories.prefix(3) {
            let categoryVideos = Video.sampleVideos.filter { $0.category == category }
            recommendedVideos.append(contentsOf: categoryVideos.prefix(limit / 3))
        }
        
        // Based on liked creators
        for creatorId in profile.likedCreators.prefix(2) {
            let creatorVideos = Video.sampleVideos.filter { $0.creator.id == creatorId }
            recommendedVideos.append(contentsOf: creatorVideos.prefix(2))
        }
        
        return Array(Set(recommendedVideos).prefix(limit))
    }
    
    private func getPopularInCategories(profile: RecommendationUserProfile, limit: Int) -> [Video] {
        let categories = profile.favoriteCategories.isEmpty ? 
            [VideoCategory.entertainment, VideoCategory.technology, VideoCategory.education] :
            Array(profile.favoriteCategories.prefix(3))
        
        var popularVideos: [Video] = []
        
        for category in categories {
            let categoryVideos = Video.sampleVideos
                .filter { $0.category == category }
                .sorted { $0.viewCount > $1.viewCount }
            
            popularVideos.append(contentsOf: categoryVideos.prefix(limit / categories.count))
        }
        
        return Array(popularVideos.prefix(limit))
    }
    
    private func getTimeBasedRecommendations(context: RecommendationContext, limit: Int) -> [Video] {
        let hour = Calendar.current.component(.hour, from: context.timeOfDay)
        
        // Different content for different times of day
        let preferredCategories: [VideoCategory] = {
            switch hour {
            case 6...9: // Morning
                return [.news, .education, .fitness]
            case 10...17: // Day
                return [.technology, .education, .business]
            case 18...22: // Evening
                return [.entertainment, .gaming, .music]
            case 23...5: // Night
                return [.music, .comedy, .entertainment]
            default:
                return [.entertainment, .technology, .music]
            }
        }()
        
        let timeBasedVideos = Video.sampleVideos.filter { video in
            preferredCategories.contains(video.category)
        }
        
        return Array(timeBasedVideos.shuffled().prefix(limit))
    }
    
    private func getCollaborativeRecommendations(profile: RecommendationUserProfile, limit: Int) -> [Video] {
        // Find users with similar preferences
        let similarUsers = userProfiles.values.filter { otherProfile in
            otherProfile.userId != profile.userId &&
            !Set(otherProfile.favoriteCategories).isDisjoint(with: Set(profile.favoriteCategories))
        }
        
        var collaborativeVideos: [Video] = []
        
        for similarUser in similarUsers.prefix(3) {
            let theirWatchedVideos = similarUser.watchHistory.filter { video in
                !profile.watchHistory.contains { $0.id == video.id }
            }
            collaborativeVideos.append(contentsOf: theirWatchedVideos.prefix(limit / 3))
        }
        
        return Array(Set(collaborativeVideos).prefix(limit))
    }
    
    private func getHybridRecommendations(context: RecommendationContext, limit: Int) -> [Video] {
        // Combine multiple recommendation strategies
        let historyWeight = 0.4
        let trendingWeight = 0.3
        let collaborativeWeight = 0.3
        
        let profile = getRecommendationUserProfile(userId: context.userId)
        
        let historyCount = Int(Double(limit) * historyWeight)
        let trendingCount = Int(Double(limit) * trendingWeight)
        let collaborativeCount = limit - historyCount - trendingCount
        
        var hybridVideos: [Video] = []
        hybridVideos.append(contentsOf: getVideosBasedOnHistory(profile: profile, limit: historyCount))
        hybridVideos.append(contentsOf: Video.sampleVideos.sorted { $0.viewCount > $1.viewCount }.prefix(trendingCount))
        hybridVideos.append(contentsOf: getCollaborativeRecommendations(profile: profile, limit: collaborativeCount))
        
        return Array(Set(hybridVideos).shuffled().prefix(limit))
    }
    
    private func calculateSimilarityScore(_ video1: Video, to video2: Video) -> Double {
        var score = 0.0
        
        // Category match
        if video1.category == video2.category {
            score += 0.4
        }
        
        // Creator match
        if video1.creator.id == video2.creator.id {
            score += 0.3
        }
        
        // Tag overlap
        let commonTags = Set(video1.tags).intersection(Set(video2.tags))
        let tagScore = Double(commonTags.count) / Double(max(video1.tags.count, video2.tags.count, 1))
        score += tagScore * 0.2
        
        // Duration similarity
        let durationDiff = abs(video1.duration - video2.duration)
        let maxDuration = max(video1.duration, video2.duration)
        let durationScore = maxDuration > 0 ? 1.0 - (durationDiff / maxDuration) : 1.0
        score += durationScore * 0.1
        
        return score
    }
    
    private func calculateTrendingScore(_ video: Video) -> Double {
        let viewWeight = 0.4
        let likeWeight = 0.3
        let recencyWeight = 0.2
        let engagementWeight = 0.1
        
        let normalizedViews = min(Double(video.viewCount) / 1_000_000, 1.0)
        let normalizedLikes = min(Double(video.likeCount) / 100_000, 1.0)
        
        let daysSinceCreated = Date().timeIntervalSince(video.createdAt) / (24 * 60 * 60)
        let recencyScore = max(0, 1.0 - (daysSinceCreated / 30.0)) // Decay over 30 days
        
        let engagementRate = video.viewCount > 0 ? 
            Double(video.likeCount + video.commentCount) / Double(video.viewCount) : 0
        let normalizedEngagement = min(engagementRate * 100, 1.0)
        
        return (normalizedViews * viewWeight) +
               (normalizedLikes * likeWeight) +
               (recencyScore * recencyWeight) +
               (normalizedEngagement * engagementWeight)
    }
}

// MARK: - User Profile Model
struct RecommendationRecommendationUserProfile {
    let userId: String
    var favoriteCategories: [VideoCategory] = []
    var likedCreators: [String] = []
    var subscriptions: [String] = []
    var watchHistory: [Video] = []
    var searchHistory: [String] = []
    var averageWatchTime: TimeInterval = 0
    var preferredVideoLength: VideoLength = .medium
    var activeHours: [Int] = [] // Hours of day when most active
    var devicePreference: RecommendationContext.DeviceType = .phone
    
    enum VideoLength {
        case short, medium, long
    }
    
    init(userId: String) {
        self.userId = userId
        
        // Initialize with some default preferences
        self.favoriteCategories = [.entertainment, .technology, .education]
        self.activeHours = [9, 10, 11, 18, 19, 20, 21]
    }
    
    mutating func updateWithInteraction(_ interaction: UserInteraction) {
        // Update profile based on user interaction
        switch interaction.interactionType {
        case .view, .watchComplete:
            if let video = Video.sampleVideos.first(where: { $0.id == interaction.videoId }) {
                // Update favorite categories
                if !favoriteCategories.contains(video.category) {
                    favoriteCategories.append(video.category)
                }
                
                // Update liked creators
                if !likedCreators.contains(video.creator.id) {
                    likedCreators.append(video.creator.id)
                }
                
                // Update watch history
                if !watchHistory.contains(where: { $0.id == video.id }) {
                    watchHistory.append(video)
                }
            }
            
        case .like:
            if let video = Video.sampleVideos.first(where: { $0.id == interaction.videoId }) {
                // Boost category and creator preferences
                if let index = favoriteCategories.firstIndex(of: video.category) {
                    favoriteCategories.remove(at: index)
                    favoriteCategories.insert(video.category, at: 0)
                }
                
                if let index = likedCreators.firstIndex(of: video.creator.id) {
                    likedCreators.remove(at: index)
                    likedCreators.insert(video.creator.id, at: 0)
                }
            }
            
        case .subscribe:
            if let video = Video.sampleVideos.first(where: { $0.id == interaction.videoId }) {
                if !subscriptions.contains(video.creator.id) {
                    subscriptions.append(video.creator.id)
                }
            }
            
        default:
            break
        }
        
        // Update active hours
        let hour = Calendar.current.component(.hour, from: interaction.timestamp)
        if !activeHours.contains(hour) {
            activeHours.append(hour)
        }
    }
}

// MARK: - Sample Data and Extensions
extension SmartRecommendationService {
    static let shared = SmartRecommendationService()
    
    func initializeSampleData() {
        // Initialize some sample user profiles
        var sampleProfile = RecommendationUserProfile(userId: "user-1")
        sampleProfile.favoriteCategories = [.technology, .gaming, .education]
        sampleProfile.likedCreators = Array(User.sampleUsers.prefix(2).map { $0.id })
        sampleProfile.subscriptions = Array(User.sampleUsers.map { $0.id })
        sampleProfile.watchHistory = Array(Video.sampleVideos.prefix(5))
        
        userProfiles["user-1"] = sampleProfile
    }
}

#Preview {
    VStack {
        Text("Smart Recommendation Engine")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Features")
                .font(.headline)
            
            ForEach([
                "🎯 Personalized home feed",
                "🔥 Trending content detection", 
                "👥 Collaborative filtering",
                "🏷️ Content-based recommendations",
                "⏰ Time-aware suggestions",
                "📊 Real-time user interaction tracking",
                "🤖 Hybrid ML algorithms",
                "🎨 Category-based recommendations"
            ], id: \.self) { feature in
                HStack {
                    Text(feature)
                        .font(.body)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        
        Spacer()
    }
    .padding()
}