//
//  EnhancedSubscriptionService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// 📺 Enterprise-Grade Subscription Management Service
// Industry-standard subscriber backend with ML integration
@MainActor
class EnhancedSubscriptionService: ObservableObject {
    static let shared = EnhancedSubscriptionService()
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var subscribedChannels: [User] = []
    @Published var subscriptionVideos: [Video] = []
    @Published var subscriptionStats: EnhancedSubscriptionStats?
    
    // Performance tracking
    private let cache = NSCache<NSString, NSArray>()
    private var cancellables = Set<AnyCancellable>()
    private let batchSize = 50
    
    // ML Services Integration
    private let recommendationURL = "https://recommendations-fkri6ifojq-uc.a.run.app"
    private let feedPersonalizationURL = "https://feed-personalization-fkri6ifojq-uc.a.run.app"
    private let engagementPredictorURL = "https://engagement-predictor-fkri6ifojq-uc.a.run.app"
    private let churnPredictorURL = "https://churn-predictor-fkri6ifojq-uc.a.run.app"
    
    private init() {
        setupCache()
    }
    
    // MARK: - Configuration
    
    private func setupCache() {
        cache.countLimit = 1000 // Cache up to 1000 items
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB cache limit
    }
    
    // MARK: - Enhanced Subscription Loading
    
    func loadSubscriptionFeed(userId: String, page: Int = 0, limit: Int = 50) async throws -> [Video] {
        let startTime = Date()
        
        // Start performance tracking
        PerformanceMonitoringManager.shared.startTrace(name: "subscription_feed_load", attributes: [
            "user_id": userId,
            "page": String(page),
            "limit": String(limit)
        ])
        
        // Update monitoring metrics
        MonitoringDashboardManager.shared.incrementCounter("subscription_requests")
        
        defer {
            let loadTime = Date().timeIntervalSince(startTime)
            PerformanceMonitoringManager.shared.stopTrace(name: "subscription_feed_load", metrics: [
                "load_time_ms": Int64(loadTime * 1000)
            ])
            MonitoringDashboardManager.shared.recordLatency("subscription_load_time", latency: loadTime)
        }
        
        // Check cache first
        let cacheKey = "subscription_feed_\(userId)_\(page)_\(limit)" as NSString
        if let cachedResults = cache.object(forKey: cacheKey) as? [Video] {
            EnhancedAnalyticsManager.shared.logEvent("subscription_cache_hit", parameters: [
                "user_id": userId,
                "page": page,
                "cached_count": cachedResults.count
            ])
            return cachedResults
        }
        
        isLoading = true
        error = nil
        
        do {
            // 1. Get user's subscriptions with enhanced data
            let subscriptions = try await fetchEnhancedSubscriptions(userId: userId)
            
            // 2. Load videos from subscribed channels with ML ranking
            let videos = try await loadSubscriptionVideosWithML(
                subscriptions: subscriptions,
                userId: userId,
                page: page,
                limit: limit
            )
            
            // 3. Apply personalization
            let personalizedVideos = await personalizeSubscriptionFeed(
                videos: videos,
                userId: userId
            )
            
            // Cache results
            cache.setObject(personalizedVideos as NSArray, forKey: cacheKey)
            
            // Track analytics
            EnhancedAnalyticsManager.shared.logEvent("subscription_feed_loaded", parameters: [
                "user_id": userId,
                "page": page,
                "loaded_count": personalizedVideos.count,
                "load_time_ms": Date().timeIntervalSince(startTime) * 1000,
                "personalized": true
            ])
            
            isLoading = false
            return personalizedVideos
            
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            
            // Report error
            ErrorReportingManager.shared.reportError(
                error,
                context: "SubscriptionFeedLoad",
                severity: .warning,
                metadata: [
                    "user_id": userId,
                    "page": page,
                    "limit": limit
                ]
            )
            
            MonitoringDashboardManager.shared.incrementCounter("subscription_errors")
            throw error
        }
    }
    
    private func fetchEnhancedSubscriptions(userId: String) async throws -> [EnhancedSubscription] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .getDocuments()
        
        var subscriptions: [EnhancedSubscription] = []
        
        for doc in snapshot.documents {
            let data = doc.data()
            let subscription = EnhancedSubscription(
                channelId: doc.documentID,
                subscribedAt: (data["subscribedAt"] as? Timestamp)?.dateValue() ?? Date(),
                notificationLevel: NotificationLevel(rawValue: data["notificationLevel"] as? String ?? "all") ?? .all,
                engagementScore: data["engagementScore"] as? Double ?? 0.0,
                lastWatched: (data["lastWatched"] as? Timestamp)?.dateValue(),
                watchTimeTotal: data["watchTimeTotal"] as? TimeInterval ?? 0,
                videosWatched: data["videosWatched"] as? Int ?? 0,
                isActive: data["isActive"] as? Bool ?? true
            )
            subscriptions.append(subscription)
        }
        
        return subscriptions
        #else
        return []
        #endif
    }
    
    private func loadSubscriptionVideosWithML(
        subscriptions: [EnhancedSubscription],
        userId: String,
        page: Int,
        limit: Int
    ) async throws -> [Video] {
        var allVideos: [Video] = []
        
        // Sort subscriptions by engagement score and activity
        let sortedSubscriptions = subscriptions
            .filter { $0.isActive }
            .sorted { $0.engagementScore > $1.engagementScore }
        
        // Load videos from top channels first
        for subscription in sortedSubscriptions.prefix(20) { // Top 20 channels
            let channelVideos = await VideoFirestoreService.shared.fetchVideosByCreator(
                creatorId: subscription.channelId,
                limit: 10 // Up to 10 videos per channel
            )
            
            // Filter recent videos (last 30 days)
            let recentVideos = channelVideos.filter {
                $0.createdAt >= Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            }
            
            allVideos.append(contentsOf: recentVideos)
        }
        
        // Apply ML-powered ranking
        let rankedVideos = await applyMLRanking(videos: allVideos, userId: userId)
        
        // Pagination
        let startIndex = page * limit
        let endIndex = min(startIndex + limit, rankedVideos.count)
        
        return Array(rankedVideos[startIndex..<endIndex])
    }
    
    // MARK: - ML-Powered Features
    
    private func personalizeSubscriptionFeed(videos: [Video], userId: String) async -> [Video] {
        guard RemoteConfigManager.shared.isRecommendationEngineEnabled else {
            return videos
        }
        
        do {
            let request = FeedPersonalizationRequest(
                userId: userId,
                videos: videos.map { videoToMLData($0) },
                context: SubscriptionFeedContext(
                    feedType: "subscriptions",
                    timeOfDay: getCurrentTimeOfDay(),
                    dayOfWeek: getCurrentDayOfWeek(),
                    deviceType: UIDevice.current.model
                ),
                timestamp: Date().timeIntervalSince1970
            )
            
            let response = try await performMLRequest(
                url: feedPersonalizationURL + "/personalize",
                request: request,
                responseType: FeedPersonalizationResponse.self
            )
            
            // Reorder videos based on ML ranking
            let personalizedVideos = response.rankedContentIds.compactMap { contentId in
                videos.first { $0.id == contentId }
            }
            
            // Add any unranked videos at the end
            let unrankedVideos = videos.filter { video in
                !response.rankedContentIds.contains(video.id)
            }
            
            return personalizedVideos + unrankedVideos
            
        } catch {
            ErrorReportingManager.shared.reportMLServiceError(
                serviceName: "feed_personalization",
                error: error,
                requestData: ["video_count": videos.count],
                responseTime: 0
            )
            return videos
        }
    }
    
    private func applyMLRanking(videos: [Video], userId: String) async -> [Video] {
        do {
            let request = ContentRankingRequest(
                userId: userId,
                content: videos.map { videoToMLData($0) },
                context: "subscription_feed"
            )
            
            let response = try await performMLRequest(
                url: recommendationURL + "/rank",
                request: request,
                responseType: ContentRankingResponse.self
            )
            
            // Reorder based on ML scores
            return videos.sorted { video1, video2 in
                let score1 = response.scores[video1.id] ?? 0.0
                let score2 = response.scores[video2.id] ?? 0.0
                return score1 > score2
            }
            
        } catch {
            return videos.sorted { $0.createdAt > $1.createdAt } // Fallback to date sort
        }
    }
    
    // MARK: - Subscription Management
    
    func subscribeToChannel(userId: String, channelId: String) async throws {
        let startTime = Date()
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Create enhanced subscription record
        let subscriptionData: [String: Any] = [
            "subscribedAt": FieldValue.serverTimestamp(),
            "notificationLevel": NotificationLevel.all.rawValue,
            "engagementScore": 0.0,
            "watchTimeTotal": 0.0,
            "videosWatched": 0,
            "isActive": true,
            "source": "manual"
        ]
        
        try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .document(channelId)
            .setData(subscriptionData)
        
        // Update channel subscriber count
        try await db.collection("users")
            .document(channelId)
            .updateData([
                "subscriberCount": FieldValue.increment(Int64(1)),
                "lastSubscriberAt": FieldValue.serverTimestamp()
            ])
        
        // Track analytics
        let subscribeTime = Date().timeIntervalSince(startTime)
        EnhancedAnalyticsManager.shared.logEvent("channel_subscribed", parameters: [
            "user_id": userId,
            "channel_id": channelId,
            "subscribe_time_ms": subscribeTime * 1000
        ])
        
        // Clear cache
        clearUserCache(userId: userId)
        
        // Predict engagement
        await predictSubscriptionEngagement(userId: userId, channelId: channelId)
        #endif
    }
    
    func unsubscribeFromChannel(userId: String, channelId: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Remove subscription
        try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .document(channelId)
            .delete()
        
        // Update channel subscriber count
        try await db.collection("users")
            .document(channelId)
            .updateData([
                "subscriberCount": FieldValue.increment(Int64(-1))
            ])
        
        // Track analytics
        EnhancedAnalyticsManager.shared.logEvent("channel_unsubscribed", parameters: [
            "user_id": userId,
            "channel_id": channelId
        ])
        
        // Clear cache
        clearUserCache(userId: userId)
        #endif
    }
    
    func updateNotificationLevel(userId: String, channelId: String, level: NotificationLevel) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .document(channelId)
            .updateData([
                "notificationLevel": level.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        
        // Track analytics
        EnhancedAnalyticsManager.shared.logEvent("notification_level_changed", parameters: [
            "user_id": userId,
            "channel_id": channelId,
            "level": level.rawValue
        ])
        #endif
    }
    
    // MARK: - Analytics & Insights
    
    func trackVideoWatch(userId: String, videoId: String, channelId: String, watchTime: TimeInterval) async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Update subscription engagement
        try? await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .document(channelId)
            .updateData([
                "watchTimeTotal": FieldValue.increment(Int64(watchTime)),
                "videosWatched": FieldValue.increment(Int64(1)),
                "lastWatched": FieldValue.serverTimestamp(),
                "engagementScore": FieldValue.increment(Int64(watchTime * 0.1)) // Simple scoring
            ])
        #endif
        
        // Track in analytics
        EnhancedAnalyticsManager.shared.logEvent("subscription_video_watched", parameters: [
            "user_id": userId,
            "video_id": videoId,
            "channel_id": channelId,
            "watch_time": watchTime,
            "completion_rate": min(watchTime / 300.0, 1.0) // Assuming 5min average
        ])
    }
    
    func getSubscriptionStats(userId: String) async throws -> EnhancedSubscriptionStats {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .getDocuments()
        
        var totalWatchTime: TimeInterval = 0
        var totalVideosWatched = 0
        var activeSubscriptions = 0
        var engagementScores: [Double] = []
        
        for doc in snapshot.documents {
            let data = doc.data()
            
            if data["isActive"] as? Bool ?? true {
                activeSubscriptions += 1
            }
            
            totalWatchTime += data["watchTimeTotal"] as? TimeInterval ?? 0
            totalVideosWatched += data["videosWatched"] as? Int ?? 0
            
            let engagement = data["engagementScore"] as? Double ?? 0
            engagementScores.append(engagement)
        }
        
        let avgEngagement = engagementScores.isEmpty ? 0 : engagementScores.reduce(0, +) / Double(engagementScores.count)
        
        return EnhancedSubscriptionStats(
            totalSubscriptions: snapshot.documents.count,
            activeSubscriptions: activeSubscriptions,
            totalWatchTime: totalWatchTime,
            totalVideosWatched: totalVideosWatched,
            averageEngagement: avgEngagement,
            lastUpdated: Date()
        )
        #else
        return EnhancedSubscriptionStats(
            totalSubscriptions: 0,
            activeSubscriptions: 0,
            totalWatchTime: 0,
            totalVideosWatched: 0,
            averageEngagement: 0,
            lastUpdated: Date()
        )
        #endif
    }
    
    // MARK: - ML Predictions
    
    private func predictSubscriptionEngagement(userId: String, channelId: String) async {
        do {
            let request = EngagementPredictionRequest(
                userId: userId,
                channelId: channelId,
                subscriptionContext: "new_subscription"
            )
            
            let response = try await performMLRequest(
                url: engagementPredictorURL + "/predict",
                request: request,
                responseType: EngagementPredictionResponse.self
            )
            
            // Store prediction in Firestore
            #if canImport(FirebaseFirestore)
            let db = Firestore.firestore()
            try? await db.collection("users")
                .document(userId)
                .collection("subscriptions")
                .document(channelId)
                .updateData([
                    "predictedEngagement": response.engagementScore,
                    "engagementPrediction": response.prediction,
                    "predictionConfidence": response.confidence
                ])
            #endif
            
        } catch {
            print("Engagement prediction failed: \(error)")
        }
    }
    
    func predictChurnRisk(userId: String) async throws -> SubscriptionChurnPredictionResult {
        let request = ChurnPredictionRequest(
            userId: userId,
            subscriptionData: await getSubscriptionMLData(userId: userId)
        )
        
        let response = try await performMLRequest(
            url: churnPredictorURL + "/predict",
            request: request,
            responseType: ChurnPredictionResponse.self
        )
        
        return SubscriptionChurnPredictionResult(
            riskScore: response.riskScore,
            riskLevel: response.riskLevel,
            factors: response.factors,
            recommendations: response.recommendations
        )
    }
    
    // MARK: - Batch Operations
    
    func batchUpdateSubscriptions(userId: String, updates: [SubscriptionUpdate]) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let batch = db.batch()
        
        for update in updates {
            let ref = db.collection("users")
                .document(userId)
                .collection("subscriptions")
                .document(update.channelId)
            
            batch.updateData(update.data, forDocument: ref)
        }
        
        try await batch.commit()
        
        // Clear cache after batch update
        clearUserCache(userId: userId)
        #endif
    }
    
    // MARK: - Helper Methods
    
    private func performMLRequest<T: Encodable, R: Decodable>(
        url: String,
        request: T,
        responseType: R.Type
    ) async throws -> R {
        guard let requestURL = URL(string: url) else {
            throw EnhancedSubscriptionError.invalidURL
        }
        
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw EnhancedSubscriptionError.serverError
        }
        
        return try JSONDecoder().decode(responseType, from: data)
    }
    
    private func videoToMLData(_ video: Video) -> [String: Any] {
        return [
            "id": video.id,
            "title": video.title,
            "description": video.description,
            "duration": video.duration,
            "viewCount": video.viewCount,
            "likeCount": video.likeCount,
            "commentCount": video.commentCount,
            "createdAt": video.createdAt.timeIntervalSince1970,
            "creatorId": video.creator.id,
            "category": video.category.rawValue,
            "tags": video.tags
        ]
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
    
    private func clearUserCache(userId: String) {
        let keysToRemove = ["subscription_feed_\(userId)", "subscription_channels_\(userId)"]
        for key in keysToRemove {
            cache.removeObject(forKey: key as NSString)
        }
    }
    
    private func getSubscriptionMLData(userId: String) async -> [String: Any] {
        // Get user's subscription data for ML analysis
        do {
            let stats = try await getSubscriptionStats(userId: userId)
            return [
                "total_subscriptions": stats.totalSubscriptions,
                "active_subscriptions": stats.activeSubscriptions,
                "total_watch_time": stats.totalWatchTime,
                "videos_watched": stats.totalVideosWatched,
                "avg_engagement": stats.averageEngagement
            ]
        } catch {
            return [:]
        }
    }
}

// MARK: - Supporting Types

struct EnhancedSubscription {
    let channelId: String
    let subscribedAt: Date
    let notificationLevel: NotificationLevel
    let engagementScore: Double
    let lastWatched: Date?
    let watchTimeTotal: TimeInterval
    let videosWatched: Int
    let isActive: Bool
}

enum NotificationLevel: String, CaseIterable, Codable {
    case all = "all"
    case personalized = "personalized"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .all: return "All notifications"
        case .personalized: return "Personalized"
        case .none: return "None"
        }
    }
}

struct EnhancedSubscriptionStats {
    let totalSubscriptions: Int
    let activeSubscriptions: Int
    let totalWatchTime: TimeInterval
    let totalVideosWatched: Int
    let averageEngagement: Double
    let lastUpdated: Date
}

struct SubscriptionUpdate {
    let channelId: String
    let data: [String: Any]
}

struct SubscriptionChurnPredictionResult {
    let riskScore: Double
    let riskLevel: String
    let factors: [String]
    let recommendations: [String]
}

// MARK: - ML Request/Response Types

struct FeedPersonalizationRequest: Codable {
    let userId: String
    let videos: [[String: Any]]
    let context: SubscriptionFeedContext
    let timestamp: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case userId, videos, context, timestamp
    }
    
    init(userId: String, videos: [[String: Any]], context: SubscriptionFeedContext, timestamp: TimeInterval) {
        self.userId = userId
        self.videos = videos
        self.context = context
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        context = try container.decode(SubscriptionFeedContext.self, forKey: .context)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        
        // Decode videos as JSON array and convert to [String: Any]
        let videosData = try container.decode([ContentData].self, forKey: .videos)
        videos = videosData.map { $0.toDictionary() }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(context, forKey: .context)
        try container.encode(timestamp, forKey: .timestamp)
        
        // Convert [String: Any] to encodable format
        let videosData = videos.map { ContentData(from: $0) }
        try container.encode(videosData, forKey: .videos)
    }
}

// Helper struct for encoding/decoding [String: Any]
struct ContentData: Codable {
    let data: [String: JSONValue]
    
    init(from dictionary: [String: Any]) {
        data = dictionary.mapValues { JSONValue(from: $0) }
    }
    
    func toDictionary() -> [String: Any] {
        return data.mapValues { $0.toAny() }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decodedData = try container.decode([String: JSONValue].self)
        data = decodedData
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
}

struct FeedPersonalizationResponse: Codable {
    let rankedContentIds: [String]
    let scores: [String: Double]
}

struct SubscriptionFeedContext: Codable {
    let feedType: String
    let timeOfDay: String
    let dayOfWeek: String
    let deviceType: String
    
    init(feedType: String = "subscriptions", timeOfDay: String, dayOfWeek: String, deviceType: String) {
        self.feedType = feedType
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek
        self.deviceType = deviceType
    }
}

struct ContentRankingRequest: Encodable {
    let userId: String
    let content: [[String: Any]]
    let context: String
    
    enum CodingKeys: String, CodingKey {
        case userId, context
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(context, forKey: .context)
    }
}

struct ContentRankingResponse: Codable {
    let scores: [String: Double]
}

struct EngagementPredictionRequest: Codable {
    let userId: String
    let channelId: String
    let subscriptionContext: String
}

struct EngagementPredictionResponse: Codable {
    let engagementScore: Double
    let prediction: String
    let confidence: Double
}

struct ChurnPredictionRequest: Encodable {
    let userId: String
    let subscriptionData: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case userId
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
    }
}

struct ChurnPredictionResponse: Codable {
    let riskScore: Double
    let riskLevel: String
    let factors: [String]
    let recommendations: [String]
}

// MARK: - Error Types

enum EnhancedSubscriptionError: LocalizedError {
    case invalidURL
    case serverError
    case networkError
    case dataCorruption
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid service URL"
        case .serverError:
            return "Server error occurred"
        case .networkError:
            return "Network error"
        case .dataCorruption:
            return "Data corruption detected"
        }
    }
}
