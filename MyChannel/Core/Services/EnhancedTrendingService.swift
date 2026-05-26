//
//  EnhancedTrendingService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// 🔥 Enterprise Trending Service
// Industry-standard trending algorithm with ML-powered insights
@MainActor
class EnhancedTrendingService: ObservableObject {
    static let shared = EnhancedTrendingService()
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var trendingVideos: [TrendingVideo] = []
    @Published var trendingTopics: [TrendingTopic] = []
    @Published var trendingCreators: [TrendingCreator] = []
    @Published var trendingHashtags: [TrendingHashtag] = []
    
    // Performance tracking
    private let cache = NSCache<NSString, NSArray>()
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    
    // ML Services Integration
    private let trendingAnalysisURL = "https://trending-analysis-fkri6ifojq-uc.a.run.app"
    private let viralPredictionURL = "https://viral-prediction-fkri6ifojq-uc.a.run.app"
    private let topicExtractionURL = "https://topic-extraction-fkri6ifojq-uc.a.run.app"
    private let sentimentAnalysisURL = "https://sentiment-analysis-fkri6ifojq-uc.a.run.app"
    private let engagementPredictionURL = "https://engagement-prediction-fkri6ifojq-uc.a.run.app"
    private let trendingMLURL = "https://trending-ml-fkri6ifojq-uc.a.run.app"
    private let socialSignalsURL = "https://social-signals-fkri6ifojq-uc.a.run.app"
    
    private init() {
        setupCache()
        startRealtimeUpdates()
    }
    
    // MARK: - Configuration
    
    private func setupCache() {
        cache.countLimit = 1000 // Cache up to 1000 trending items
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB cache limit
    }
    
    private func startRealtimeUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                await self.refreshTrendingData()
            }
        }
    }
    
    // MARK: - Trending Videos
    
    func loadTrendingVideos(category: String = "all", region: String = "global", limit: Int = 50) async throws -> [TrendingVideo] {
        let startTime = Date()
        
        // Start performance tracking
        PerformanceMonitoringManager.shared.startTrace(name: "trending_videos_load", attributes: [
            "category": category,
            "region": region,
            "limit": String(limit)
        ])
        
        defer {
            let loadTime = Date().timeIntervalSince(startTime)
            PerformanceMonitoringManager.shared.stopTrace(name: "trending_videos_load", metrics: [
                "load_time_ms": Int64(loadTime * 1000)
            ])
        }
        
        // Check cache first
        let cacheKey = "trending_videos_\(category)_\(region)_\(limit)" as NSString
        if let cachedResults = cache.object(forKey: cacheKey) as? [TrendingVideo] {
            EnhancedAnalyticsManager.shared.logEvent("trending_cache_hit", parameters: [
                "type": "videos",
                "category": category,
                "region": region
            ])
            return cachedResults
        }
        
        isLoading = true
        error = nil
        
        do {
            // Load trending videos with ML enhancement
            let videos = try await loadTrendingVideosFromFirestore(category: category, region: region, limit: limit)
            let enhancedVideos = await enhanceVideosWithTrendingML(videos)
            let rankedVideos = await rankVideosByTrendingScore(enhancedVideos)
            
            // Cache results
            cache.setObject(rankedVideos as NSArray, forKey: cacheKey)
            
            // Update local state
            trendingVideos = rankedVideos
            
            // Track analytics
            EnhancedAnalyticsManager.shared.logEvent("trending_videos_loaded", parameters: [
                "category": category,
                "region": region,
                "count": rankedVideos.count,
                "load_time_ms": Date().timeIntervalSince(startTime) * 1000
            ])
            
            isLoading = false
            return rankedVideos
            
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            
            ErrorReportingManager.shared.reportError(
                error,
                context: "TrendingVideosLoad",
                severity: .warning,
                metadata: [
                    "category": category,
                    "region": region
                ]
            )
            
            throw error
        }
    }
    
    private func loadTrendingVideosFromFirestore(category: String, region: String, limit: Int) async throws -> [TrendingVideo] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Get videos from last 24 hours with high engagement
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60)
        
        var query = db.collection("videos")
            .whereField("publishedAt", isGreaterThan: Timestamp(date: cutoffDate))
            .whereField("status", isEqualTo: "published")
            .order(by: "trendingScore", descending: true)
            .limit(to: limit * 2) // Get more for ML filtering
        
        if category != "all" {
            query = query.whereField("category", isEqualTo: category)
        }
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { doc in
            parseTrendingVideoFromDocument(doc)
        }
        #else
        return []
        #endif
    }
    
    private func parseTrendingVideoFromDocument(_ doc: DocumentSnapshot) -> TrendingVideo? {
        let data = doc.data() ?? [:]
        
        guard let title = data["title"] as? String,
              let creatorId = data["creatorId"] as? String,
              let creatorName = data["creatorName"] as? String else {
            return nil
        }
        
        return TrendingVideo(
            id: doc.documentID,
            title: title,
            description: data["description"] as? String ?? "",
            thumbnailURL: data["thumbnailURL"] as? String ?? "",
            videoURL: data["videoURL"] as? String ?? "",
            duration: data["duration"] as? TimeInterval ?? 0,
            creatorId: creatorId,
            creatorName: creatorName,
            creatorAvatarURL: data["creatorAvatarURL"] as? String ?? "",
            viewCount: data["viewCount"] as? Int ?? 0,
            likeCount: data["likeCount"] as? Int ?? 0,
            commentCount: data["commentCount"] as? Int ?? 0,
            shareCount: data["shareCount"] as? Int ?? 0,
            publishedAt: (data["publishedAt"] as? Timestamp)?.dateValue() ?? Date(),
            category: data["category"] as? String ?? "",
            tags: data["tags"] as? [String] ?? [],
            trendingScore: data["trendingScore"] as? Double ?? 0.0,
            viralVelocity: data["viralVelocity"] as? Double ?? 0.0,
            engagementRate: data["engagementRate"] as? Double ?? 0.0,
            watchTimeRatio: data["watchTimeRatio"] as? Double ?? 0.0,
            socialSignals: data["socialSignals"] as? [String: Double] ?? [:],
            trendingRank: 0, // Will be set during ranking
            trendingCategory: TrendingCategory.general,
            mlInsights: nil // Will be populated by ML enhancement
        )
    }
    
    private func enhanceVideosWithTrendingML(_ videos: [TrendingVideo]) async -> [TrendingVideo] {
        guard RemoteConfigManager.shared.isMLEnhancementEnabled else {
            return videos
        }
        
        return await withTaskGroup(of: TrendingVideo.self) { group in
            for video in videos {
                group.addTask {
                    await self.enhanceVideoWithTrendingML(video)
                }
            }
            
            var enhancedVideos: [TrendingVideo] = []
            for await enhancedVideo in group {
                enhancedVideos.append(enhancedVideo)
            }
            
            // Maintain original order
            return videos.compactMap { originalVideo in
                enhancedVideos.first { $0.id == originalVideo.id }
            }
        }
    }
    
    private func enhanceVideoWithTrendingML(_ video: TrendingVideo) async -> TrendingVideo {
        do {
            let request = TrendingAnalysisRequest(
                videoId: video.id,
                videoMetadata: VideoTrendingMetadata(
                    title: video.title,
                    description: video.description,
                    tags: video.tags,
                    category: video.category,
                    duration: video.duration
                ),
                engagementData: VideoEngagementData(
                    views: video.viewCount,
                    likes: video.likeCount,
                    comments: video.commentCount,
                    shares: video.shareCount,
                    publishedAt: video.publishedAt
                ),
                socialSignals: video.socialSignals
            )
            
            let response = try await performMLRequest(
                url: trendingAnalysisURL + "/analyze",
                request: request,
                responseType: TrendingAnalysisResponse.self
            )
            
            var enhancedVideo = video
            enhancedVideo.trendingScore = response.trendingScore
            enhancedVideo.viralVelocity = response.viralVelocity
            enhancedVideo.trendingCategory = TrendingCategory(rawValue: response.category) ?? .general
            enhancedVideo.mlInsights = TrendingMLInsights(
                trendingScore: response.trendingScore,
                viralPotential: response.viralPotential,
                peakTime: response.predictedPeakTime,
                audienceMatch: response.audienceMatch,
                competitorComparison: response.competitorComparison,
                trendingFactors: response.trendingFactors,
                predictedLifespan: response.predictedLifespan
            )
            
            return enhancedVideo
            
        } catch {
            // Return original video if ML enhancement fails
            return video
        }
    }
    
    private func rankVideosByTrendingScore(_ videos: [TrendingVideo]) async -> [TrendingVideo] {
        let sortedVideos = videos.sorted { video1, video2 in
            // Primary sort by trending score
            if video1.trendingScore != video2.trendingScore {
                return video1.trendingScore > video2.trendingScore
            }
            
            // Secondary sort by viral velocity
            if video1.viralVelocity != video2.viralVelocity {
                return video1.viralVelocity > video2.viralVelocity
            }
            
            // Tertiary sort by engagement rate
            return video1.engagementRate > video2.engagementRate
        }
        
        // Assign trending ranks
        return sortedVideos.enumerated().map { index, video in
            var rankedVideo = video
            rankedVideo.trendingRank = index + 1
            return rankedVideo
        }
    }
    
    // MARK: - Trending Topics
    
    func loadTrendingTopics(limit: Int = 20) async throws -> [TrendingTopic] {
        let request = TopicExtractionRequest(
            timeRange: "24h",
            minMentions: 10,
            includeHashtags: true,
            includeKeywords: true
        )
        
        let response = try await performMLRequest(
            url: topicExtractionURL + "/trending",
            request: request,
            responseType: TopicExtractionResponse.self
        )
        
        let topics = response.topics.prefix(limit).enumerated().map { index, topic in
            TrendingTopic(
                id: topic.id,
                name: topic.name,
                mentions: topic.mentions,
                sentiment: topic.sentiment,
                category: topic.category,
                trendingScore: topic.trendingScore,
                growth: topic.growth,
                relatedVideos: topic.relatedVideos,
                rank: index + 1,
                isRising: topic.growth > 0.5,
                peakTime: topic.peakTime
            )
        }
        
        trendingTopics = Array(topics)
        
        // Track topic loading
        EnhancedAnalyticsManager.shared.logEvent("trending_topics_loaded", parameters: [
            "count": topics.count,
            "top_topic": topics.first?.name ?? "none"
        ])
        
        return Array(topics)
    }
    
    // MARK: - Trending Creators
    
    func loadTrendingCreators(limit: Int = 20) async throws -> [TrendingCreator] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Get creators with high growth in last 7 days
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        
        let snapshot = try await db.collection("creators")
            .whereField("lastActiveAt", isGreaterThan: Timestamp(date: cutoffDate))
            .order(by: "weeklyGrowthRate", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        let creators = snapshot.documents.enumerated().compactMap { index, doc -> TrendingCreator? in
            let data = doc.data()
            
            guard let name = data["name"] as? String,
                  let username = data["username"] as? String else {
                return nil
            }
            
            return TrendingCreator(
                id: doc.documentID,
                name: name,
                username: username,
                avatarURL: data["avatarURL"] as? String ?? "",
                subscriberCount: data["subscriberCount"] as? Int ?? 0,
                weeklyGrowth: data["weeklyGrowthRate"] as? Double ?? 0.0,
                category: data["category"] as? String ?? "",
                isVerified: data["isVerified"] as? Bool ?? false,
                rank: index + 1,
                trendingScore: data["trendingScore"] as? Double ?? 0.0,
                recentVideoCount: data["recentVideoCount"] as? Int ?? 0
            )
        }
        
        trendingCreators = creators
        
        return creators
        #else
        return []
        #endif
    }
    
    // MARK: - Trending Hashtags
    
    func loadTrendingHashtags(limit: Int = 30) async throws -> [TrendingHashtag] {
        let request = HashtagAnalysisRequest(
            timeRange: "24h",
            minUsage: 5,
            includeEmojis: true
        )
        
        let response = try await performMLRequest(
            url: socialSignalsURL + "/hashtags",
            request: request,
            responseType: HashtagAnalysisResponse.self
        )
        
        let hashtags = response.hashtags.prefix(limit).enumerated().map { index, hashtag in
            TrendingHashtag(
                id: hashtag.tag,
                tag: hashtag.tag,
                usage: hashtag.usage,
                growth: hashtag.growth,
                sentiment: hashtag.sentiment,
                category: hashtag.category,
                rank: index + 1,
                isRising: hashtag.growth > 0.3,
                relatedTags: hashtag.relatedTags
            )
        }
        
        trendingHashtags = Array(hashtags)
        
        return Array(hashtags)
    }
    
    // MARK: - Real-time Updates
    
    private func refreshTrendingData() async {
        do {
            // Refresh all trending data in parallel
            async let videos = loadTrendingVideos()
            async let topics = loadTrendingTopics()
            async let creators = loadTrendingCreators()
            async let hashtags = loadTrendingHashtags()
            
            let _ = try await (videos, topics, creators, hashtags)
            
            // Track refresh
            EnhancedAnalyticsManager.shared.logEvent("trending_data_refreshed", parameters: [
                "videos_count": trendingVideos.count,
                "topics_count": trendingTopics.count,
                "creators_count": trendingCreators.count,
                "hashtags_count": trendingHashtags.count
            ])
            
        } catch {
            ErrorReportingManager.shared.reportError(
                error,
                context: "TrendingDataRefresh",
                severity: .warning
            )
        }
    }
    
    // MARK: - Trending Predictions
    
    func predictTrendingPotential(videoId: String) async throws -> TrendingPrediction {
        let request = TrendingViralPredictionRequest(
            videoId: videoId,
            analysisDepth: "comprehensive",
            includeComparisons: true
        )
        
        let response = try await performMLRequest(
            url: viralPredictionURL + "/predict",
            request: request,
            responseType: TrendingViralPredictionResponse.self
        )
        
        return TrendingPrediction(
            videoId: videoId,
            trendingProbability: response.trendingProbability,
            peakViews: response.predictedPeakViews,
            timeToTrend: response.timeToTrend,
            trendingDuration: response.trendingDuration,
            confidenceScore: response.confidenceScore,
            factors: response.factors,
            recommendations: response.recommendations
        )
    }
    
    // MARK: - Helper Methods
    
    private func performMLRequest<T: Codable, R: Codable>(
        url: String,
        request: T,
        responseType: R.Type
    ) async throws -> R {
        guard let requestURL = URL(string: url) else {
            throw TrendingServiceError.invalidURL
        }
        
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.configured.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw TrendingServiceError.serverError
        }
        
        return try JSONDecoder().decode(responseType, from: data)
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}

// MARK: - Supporting Types

struct TrendingVideo: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: String
    let videoURL: String
    let duration: TimeInterval
    let creatorId: String
    let creatorName: String
    let creatorAvatarURL: String
    let viewCount: Int
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let publishedAt: Date
    let category: String
    let tags: [String]
    var trendingScore: Double
    var viralVelocity: Double
    let engagementRate: Double
    let watchTimeRatio: Double
    let socialSignals: [String: Double]
    var trendingRank: Int
    var trendingCategory: TrendingCategory
    var mlInsights: TrendingMLInsights?
    
    var formattedViewCount: String {
        if viewCount >= 1_000_000 {
            return String(format: "%.1fM views", Double(viewCount) / 1_000_000)
        } else if viewCount >= 1_000 {
            return String(format: "%.1fK views", Double(viewCount) / 1_000)
        } else {
            return "\(viewCount) views"
        }
    }
    
    var trendingBadge: String {
        switch trendingRank {
        case 1: return "🔥 #1 Trending"
        case 2...5: return "📈 Top 5"
        case 6...10: return "⭐ Top 10"
        default: return "🔥 Trending"
        }
    }
}

struct TrendingTopic: Identifiable, Codable {
    let id: String
    let name: String
    let mentions: Int
    let sentiment: Double
    let category: String
    let trendingScore: Double
    let growth: Double
    let relatedVideos: [String]
    let rank: Int
    let isRising: Bool
    let peakTime: Date?
}

struct TrendingCreator: Identifiable, Codable {
    let id: String
    let name: String
    let username: String
    let avatarURL: String
    let subscriberCount: Int
    let weeklyGrowth: Double
    let category: String
    let isVerified: Bool
    let rank: Int
    let trendingScore: Double
    let recentVideoCount: Int
    
    var formattedSubscriberCount: String {
        if subscriberCount >= 1_000_000 {
            return String(format: "%.1fM subscribers", Double(subscriberCount) / 1_000_000)
        } else if subscriberCount >= 1_000 {
            return String(format: "%.1fK subscribers", Double(subscriberCount) / 1_000)
        } else {
            return "\(subscriberCount) subscribers"
        }
    }
}

struct TrendingHashtag: Identifiable, Codable {
    let id: String
    let tag: String
    let usage: Int
    let growth: Double
    let sentiment: Double
    let category: String
    let rank: Int
    let isRising: Bool
    let relatedTags: [String]
}

enum TrendingCategory: String, Codable, CaseIterable {
    case general = "general"
    case music = "music"
    case gaming = "gaming"
    case sports = "sports"
    case news = "news"
    case entertainment = "entertainment"
    case education = "education"
    case technology = "technology"
    case lifestyle = "lifestyle"
    case comedy = "comedy"
}

struct TrendingMLInsights: Codable {
    let trendingScore: Double
    let viralPotential: Double
    let peakTime: Date?
    let audienceMatch: Double
    let competitorComparison: [String: Double]
    let trendingFactors: [String]
    let predictedLifespan: TimeInterval
}

struct TrendingPrediction: Codable {
    let videoId: String
    let trendingProbability: Double
    let peakViews: Int
    let timeToTrend: TimeInterval
    let trendingDuration: TimeInterval
    let confidenceScore: Double
    let factors: [String]
    let recommendations: [String]
}

// MARK: - ML Request/Response Types

struct TrendingAnalysisRequest: Codable {
    let videoId: String
    let videoMetadata: VideoTrendingMetadata
    let engagementData: VideoEngagementData
    let socialSignals: [String: Double]
}

struct VideoTrendingMetadata: Codable {
    let title: String
    let description: String
    let tags: [String]
    let category: String
    let duration: TimeInterval
}

struct VideoEngagementData: Codable {
    let views: Int
    let likes: Int
    let comments: Int
    let shares: Int
    let publishedAt: Date
}

struct TrendingAnalysisResponse: Codable {
    let trendingScore: Double
    let viralVelocity: Double
    let category: String
    let viralPotential: Double
    let predictedPeakTime: Date?
    let audienceMatch: Double
    let competitorComparison: [String: Double]
    let trendingFactors: [String]
    let predictedLifespan: TimeInterval
}

struct TopicExtractionRequest: Codable {
    let timeRange: String
    let minMentions: Int
    let includeHashtags: Bool
    let includeKeywords: Bool
}

struct TopicExtractionResponse: Codable {
    let topics: [MLTrendingTopic]
}

struct MLTrendingTopic: Codable {
    let id: String
    let name: String
    let mentions: Int
    let sentiment: Double
    let category: String
    let trendingScore: Double
    let growth: Double
    let relatedVideos: [String]
    let peakTime: Date?
}

struct HashtagAnalysisRequest: Codable {
    let timeRange: String
    let minUsage: Int
    let includeEmojis: Bool
}

struct HashtagAnalysisResponse: Codable {
    let hashtags: [MLTrendingHashtag]
}

struct MLTrendingHashtag: Codable {
    let tag: String
    let usage: Int
    let growth: Double
    let sentiment: Double
    let category: String
    let relatedTags: [String]
}

struct TrendingViralPredictionRequest: Codable {
    let videoId: String
    let analysisDepth: String
    let includeComparisons: Bool
}

struct TrendingViralPredictionResponse: Codable {
    let trendingProbability: Double
    let predictedPeakViews: Int
    let timeToTrend: TimeInterval
    let trendingDuration: TimeInterval
    let confidenceScore: Double
    let factors: [String]
    let recommendations: [String]
}

// MARK: - Error Types

enum TrendingServiceError: LocalizedError {
    case invalidURL
    case serverError
    case insufficientData
    case analysisUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid service URL"
        case .serverError:
            return "Server error occurred"
        case .insufficientData:
            return "Insufficient data for trending analysis"
        case .analysisUnavailable:
            return "Trending analysis service unavailable"
        }
    }
}
