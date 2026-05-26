//
//  EnhancedStoriesService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

// 📖 Enterprise-Grade Stories Backend Service
// Industry-standard stories platform with ML integration
@MainActor
class EnhancedStoriesService: ObservableObject {
    static let shared = EnhancedStoriesService()
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var stories: [EnhancedStory] = []
    @Published var userStories: [EnhancedStory] = []
    
    // Performance tracking
    private let cache = NSCache<NSString, NSArray>()
    private var cancellables = Set<AnyCancellable>()
    
    // ML Services Integration
    private let contentModerationURL = "https://content-moderation-fkri6ifojq-uc.a.run.app"
    private let viralPredictionURL = "https://viral-prediction-fkri6ifojq-uc.a.run.app"
    private let recommendationURL = "https://recommendations-fkri6ifojq-uc.a.run.app"
    private let engagementPredictorURL = "https://engagement-predictor-fkri6ifojq-uc.a.run.app"
    private let trendingMLURL = "https://trending-ml-fkri6ifojq-uc.a.run.app"
    private let storyRankingURL = "https://story-ranking-fkri6ifojq-uc.a.run.app"
    
    private init() {
        setupCache()
        startPerformanceTracking()
    }
    
    // MARK: - Configuration
    
    private func setupCache() {
        cache.countLimit = 500 // Cache up to 500 stories
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB cache limit
    }
    
    private func startPerformanceTracking() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                self.updatePerformanceMetrics()
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        // Track stories performance metrics
        MonitoringDashboardManager.shared.updateMetric("stories_cache_size", value: Double(cache.totalCostLimit))
        MonitoringDashboardManager.shared.updateMetric("stories_loaded_count", value: Double(stories.count))
    }
    
    // MARK: - Stories Loading with ML Enhancement
    
    func loadStories(userId: String, limit: Int = 50) async throws -> [EnhancedStory] {
        let startTime = Date()
        
        // Start performance tracking
        PerformanceMonitoringManager.shared.startTrace(name: "stories_load", attributes: [
            "user_id": userId,
            "limit": String(limit)
        ])
        
        // Update monitoring metrics
        MonitoringDashboardManager.shared.incrementCounter("stories_requests")
        
        defer {
            let loadTime = Date().timeIntervalSince(startTime)
            PerformanceMonitoringManager.shared.stopTrace(name: "stories_load", metrics: [
                "load_time_ms": Int64(loadTime * 1000)
            ])
            MonitoringDashboardManager.shared.recordLatency("stories_load_time", latency: loadTime)
        }
        
        // Check cache first
        let cacheKey = "stories_\(userId)_\(limit)" as NSString
        if let cachedResults = cache.object(forKey: cacheKey) as? [EnhancedStory] {
            EnhancedAnalyticsManager.shared.logEvent("stories_cache_hit", parameters: [
                "user_id": userId,
                "cached_count": cachedResults.count
            ])
            return cachedResults
        }
        
        isLoading = true
        error = nil
        
        do {
            // Load stories from multiple sources
            let loadedStories = try await loadStoriesFromSources(userId: userId, limit: limit)
            
            // Apply ML-powered ranking and filtering
            let rankedStories = await applyMLRanking(stories: loadedStories, userId: userId)
            let moderatedStories = await applyContentModeration(rankedStories)
            
            // Cache results
            cache.setObject(moderatedStories as NSArray, forKey: cacheKey)
            
            // Track analytics
            EnhancedAnalyticsManager.shared.logEvent("stories_loaded", parameters: [
                "user_id": userId,
                "loaded_count": moderatedStories.count,
                "load_time_ms": Date().timeIntervalSince(startTime) * 1000,
                "source": "enhanced_service"
            ])
            
            stories = moderatedStories
            isLoading = false
            return moderatedStories
            
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            
            // Report error
            ErrorReportingManager.shared.reportError(
                error,
                context: "StoriesLoad",
                severity: .warning,
                metadata: [
                    "user_id": userId,
                    "limit": limit
                ]
            )
            
            MonitoringDashboardManager.shared.incrementCounter("stories_errors")
            throw error
        }
    }
    
    private func loadStoriesFromSources(userId: String, limit: Int) async throws -> [EnhancedStory] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Get user's following list for personalized stories
        let followingSnapshot = try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .getDocuments()
        
        let followingIds = followingSnapshot.documents.map { $0.documentID }
        
        // Load stories from followed users + trending stories
        var allStories: [EnhancedStory] = []
        
        // 1. Stories from followed users (priority)
        if !followingIds.isEmpty {
            let followedStoriesQuery = db.collection("stories")
                .whereField("creatorId", in: Array(followingIds.prefix(10))) // Firestore limit
                .whereField("isActive", isEqualTo: true)
                .whereField("expiresAt", isGreaterThan: Timestamp(date: Date()))
                .order(by: "createdAt", descending: true)
                .limit(to: limit * 2 / 3) // 2/3 from followed users
            
            let followedSnapshot = try await followedStoriesQuery.getDocuments()
            let followedStories = followedSnapshot.documents.compactMap { doc in
                parseStoryFromDocument(doc)
            }
            allStories.append(contentsOf: followedStories)
        }
        
        // 2. Trending/Popular stories to fill remaining slots
        let remainingLimit = limit - allStories.count
        if remainingLimit > 0 {
            let trendingQuery = db.collection("stories")
                .whereField("isActive", isEqualTo: true)
                .whereField("isPublic", isEqualTo: true)
                .whereField("expiresAt", isGreaterThan: Timestamp(date: Date()))
                .order(by: "engagementScore", descending: true)
                .limit(to: remainingLimit)
            
            let trendingSnapshot = try await trendingQuery.getDocuments()
            let trendingStories = trendingSnapshot.documents.compactMap { doc in
                parseStoryFromDocument(doc)
            }
            
            // Avoid duplicates
            let newStories = trendingStories.filter { trending in
                !allStories.contains { $0.id == trending.id }
            }
            allStories.append(contentsOf: newStories)
        }
        
        return allStories
        #else
        return []
        #endif
    }
    
    private func parseStoryFromDocument(_ doc: DocumentSnapshot) -> EnhancedStory? {
        let data = doc.data() ?? [:]
        
        guard let creatorId = data["creatorId"] as? String,
              let mediaURL = data["mediaURL"] as? String,
              let mediaType = data["mediaType"] as? String else {
            return nil
        }
        
        let creatorData = data["creator"] as? [String: Any] ?? [:]
        
        return EnhancedStory(
            id: doc.documentID,
            creatorId: creatorId,
            creatorUsername: creatorData["username"] as? String ?? "Unknown",
            creatorDisplayName: creatorData["displayName"] as? String ?? "Unknown",
            creatorAvatarURL: creatorData["profileImageURL"] as? String ?? "",
            mediaURL: mediaURL,
            mediaType: StoryMediaType(rawValue: mediaType) ?? .image,
            thumbnailURL: data["thumbnailURL"] as? String,
            duration: data["duration"] as? TimeInterval ?? 15.0,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            expiresAt: (data["expiresAt"] as? Timestamp)?.dateValue() ?? Date().addingTimeInterval(86400),
            viewCount: data["viewCount"] as? Int ?? 0,
            likeCount: data["likeCount"] as? Int ?? 0,
            commentCount: data["commentCount"] as? Int ?? 0,
            shareCount: data["shareCount"] as? Int ?? 0,
            engagementScore: data["engagementScore"] as? Double ?? 0.0,
            isPublic: data["isPublic"] as? Bool ?? true,
            isActive: data["isActive"] as? Bool ?? true,
            tags: data["tags"] as? [String] ?? [],
            location: data["location"] as? String,
            musicTrack: parseStoryMusicTrack(data["musicTrack"] as? [String: Any])
        )
    }
    
    private func parseStoryMusicTrack(_ data: [String: Any]?) -> StoryMusicTrack? {
        guard let data = data,
              let title = data["title"] as? String,
              let artist = data["artist"] as? String else {
            return nil
        }
        
        return StoryMusicTrack(
            title: title,
            artist: artist,
            albumArt: data["albumArt"] as? String ?? "",
            duration: data["duration"] as? TimeInterval ?? 30.0
        )
    }
    
    // MARK: - ML-Powered Features
    
    private func applyMLRanking(stories: [EnhancedStory], userId: String) async -> [EnhancedStory] {
        guard RemoteConfigManager.shared.isRecommendationEngineEnabled else {
            return stories.sorted { $0.createdAt > $1.createdAt }
        }
        
        do {
            let request = StoryRankingRequest(
                userId: userId,
                stories: stories.map { storyToMLData($0) },
                context: StoryContext(
                    timeOfDay: getCurrentTimeOfDay(),
                    dayOfWeek: getCurrentDayOfWeek(),
                    location: nil
                )
            )
            
            let response = try await performMLRequest(
                url: storyRankingURL + "/rank",
                request: request,
                responseType: StoryRankingResponse.self
            )
            
            // Reorder stories based on ML ranking
            let rankedStories = response.rankedStoryIds.compactMap { storyId in
                stories.first { $0.id == storyId }
            }
            
            // Add any unranked stories at the end
            let unrankedStories = stories.filter { story in
                !response.rankedStoryIds.contains(story.id)
            }
            
            return rankedStories + unrankedStories
            
        } catch {
            ErrorReportingManager.shared.reportMLServiceError(
                serviceName: "story_ranking",
                error: error,
                requestData: ["story_count": stories.count],
                responseTime: 0
            )
            return stories.sorted { $0.engagementScore > $1.engagementScore }
        }
    }
    
    private func applyContentModeration(_ stories: [EnhancedStory]) async -> [EnhancedStory] {
        guard RemoteConfigManager.shared.isContentModerationEnabled else {
            return stories
        }
        
        let moderatedStories = await withTaskGroup(of: (EnhancedStory, Bool).self) { group in
            for story in stories {
                group.addTask {
                    let isApproved = await self.moderateStory(story)
                    return (story, isApproved)
                }
            }
            
            var results: [EnhancedStory] = []
            for await (story, isApproved) in group {
                if isApproved {
                    results.append(story)
                }
            }
            return results
        }
        
        return moderatedStories
    }
    
    private func moderateStory(_ story: EnhancedStory) async -> Bool {
        do {
            let request = StoryModerationRequest(
                storyId: story.id,
                creatorId: story.creatorId,
                mediaURL: story.mediaURL,
                mediaType: story.mediaType.rawValue,
                tags: story.tags
            )
            
            let response = try await performMLRequest(
                url: contentModerationURL + "/moderate/story",
                request: request,
                responseType: StoryModerationResponse.self
            )
            
            return response.isApproved && response.confidenceScore > 0.8
            
        } catch {
            // Default to approved if moderation fails
            return true
        }
    }
    
    // MARK: - Story Upload & Management
    
    func uploadStory(
        mediaData: Data,
        mediaType: StoryMediaType,
        metadata: StoryUploadMetadata
    ) async throws -> String {
        let startTime = Date()
        let storyId = UUID().uuidString
        
        // Start performance tracking
        PerformanceMonitoringManager.shared.trackUploadPerformance(
            fileSize: Int64(mediaData.count),
            uploadTime: 0,
            contentType: "story"
        )
        
        // Track upload start
        EnhancedAnalyticsManager.shared.trackUploadStart(
            contentType: "story",
            fileSize: Int64(mediaData.count),
            estimatedDuration: metadata.duration
        )
        
        do {
            // Upload media to Firebase Storage
            let mediaURL = try await uploadStoryMedia(
                mediaData: mediaData,
                storyId: storyId,
                mediaType: mediaType
            )
            
            // Generate thumbnail if video
            let thumbnailURL = try await generateStoryThumbnail(
                mediaURL: mediaURL,
                mediaType: mediaType,
                storyId: storyId
            )
            
            // Create Firestore document
            let story = try await createStoryDocument(
                storyId: storyId,
                mediaURL: mediaURL,
                thumbnailURL: thumbnailURL,
                mediaType: mediaType,
                metadata: metadata
            )
            
            // Predict engagement and viral potential
            await predictStoryPerformance(story: story)
            
            // Track successful upload
            let uploadTime = Date().timeIntervalSince(startTime)
            EnhancedAnalyticsManager.shared.trackUploadComplete(
                contentId: storyId,
                contentType: "story",
                uploadDuration: uploadTime,
                fileSize: Int64(mediaData.count)
            )
            
            // Clear cache to refresh feed
            cache.removeAllObjects()
            
            return storyId
            
        } catch {
            ErrorReportingManager.shared.reportUploadError(
                error: error,
                fileSize: Int64(mediaData.count),
                contentType: "story",
                progress: 0.0
            )
            
            throw error
        }
    }
    
    private func uploadStoryMedia(
        mediaData: Data,
        storyId: String,
        mediaType: StoryMediaType
    ) async throws -> String {
        #if canImport(FirebaseStorage)
        let storage = Storage.storage()
        let fileExtension = mediaType == .video ? "mp4" : "jpg"
        let mediaRef = storage.reference().child("stories/\(storyId)/media.\(fileExtension)")
        
        let metadata = StorageMetadata()
        metadata.contentType = mediaType == .video ? "video/mp4" : "image/jpeg"
        metadata.customMetadata = [
            "storyId": storyId,
            "uploadedAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        let _ = try await mediaRef.putDataAsync(mediaData, metadata: metadata)
        let downloadURL = try await mediaRef.downloadURL()
        
        return downloadURL.absoluteString
        #else
        throw StoriesError.storageUnavailable
        #endif
    }
    
    private func generateStoryThumbnail(
        mediaURL: String,
        mediaType: StoryMediaType,
        storyId: String
    ) async throws -> String? {
        guard mediaType == .video else { return nil }
        
        // Use ML service to generate thumbnail
        let request = StoryThumbnailRequest(
            videoURL: mediaURL,
            timestamp: 1.0, // 1 second into video
            quality: "high"
        )
        
        let response = try await performMLRequest(
            url: "https://thumbnail-generator-fkri6ifojq-uc.a.run.app/generate/story",
            request: request,
            responseType: StoryThumbnailResponse.self
        )
        
        return response.thumbnailURL
    }
    
    private func createStoryDocument(
        storyId: String,
        mediaURL: String,
        thumbnailURL: String?,
        mediaType: StoryMediaType,
        metadata: StoryUploadMetadata
    ) async throws -> EnhancedStory {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let currentUser = getCurrentUser()
        
        var storyData: [String: Any] = [
            "id": storyId,
            "creatorId": currentUser?.id ?? "unknown",
            "mediaURL": mediaURL,
            "thumbnailURL": thumbnailURL ?? "",
            "mediaType": mediaType.rawValue,
            "duration": metadata.duration,
            "isPublic": metadata.isPublic,
            "tags": metadata.tags,
            "location": metadata.location ?? "",
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": Timestamp(date: Date().addingTimeInterval(86400)), // 24 hours
            "isActive": true,
            "viewCount": 0,
            "likeCount": 0,
            "commentCount": 0,
            "shareCount": 0,
            "engagementScore": 0.0,
            "creator": [
                "username": currentUser?.username ?? "unknown",
                "displayName": currentUser?.displayName ?? "Unknown",
                "profileImageURL": currentUser?.profileImageURL ?? ""
            ]
        ]
        
        if let musicTrack = metadata.musicTrack {
            storyData["musicTrack"] = [
                "title": musicTrack.title,
                "artist": musicTrack.artist,
                "albumArt": musicTrack.albumArt,
                "duration": musicTrack.duration
            ] as [String: Any]
        }
        
        try await db.collection("stories").document(storyId).setData(storyData)
        
        // Create the EnhancedStory object
        return EnhancedStory(
            id: storyId,
            creatorId: currentUser?.id ?? "unknown",
            creatorUsername: currentUser?.username ?? "unknown",
            creatorDisplayName: currentUser?.displayName ?? "Unknown",
            creatorAvatarURL: currentUser?.profileImageURL ?? "",
            mediaURL: mediaURL,
            mediaType: mediaType,
            thumbnailURL: thumbnailURL,
            duration: metadata.duration,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(86400),
            viewCount: 0,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            engagementScore: 0.0,
            isPublic: metadata.isPublic,
            isActive: true,
            tags: metadata.tags,
            location: metadata.location,
            musicTrack: metadata.musicTrack
        )
        #else
        throw StoriesError.firestoreUnavailable
        #endif
    }
    
    // MARK: - Analytics & Tracking
    
    func trackStoryView(storyId: String, viewDuration: TimeInterval) async {
        // Update view count in Firestore
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let storyRef = db.collection("stories").document(storyId)
        
        try? await storyRef.updateData([
            "viewCount": FieldValue.increment(Int64(1)),
            "totalViewTime": FieldValue.increment(Int64(viewDuration)),
            "lastViewed": FieldValue.serverTimestamp()
        ])
        #endif
        
        // Track in analytics
        EnhancedAnalyticsManager.shared.logEvent("story_viewed", parameters: [
            "story_id": storyId,
            "view_duration": viewDuration,
            "completion_rate": min(viewDuration / 15.0, 1.0), // Assuming 15s average
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Update engagement score
        await updateStoryEngagement(storyId: storyId, action: "view", value: viewDuration)
    }
    
    func trackStoryEngagement(storyId: String, action: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let storyRef = db.collection("stories").document(storyId)
        
        var updateData: [String: Any] = [:]
        
        switch action {
        case "like":
            updateData["likeCount"] = FieldValue.increment(Int64(1))
        case "unlike":
            updateData["likeCount"] = FieldValue.increment(Int64(-1))
        case "comment":
            updateData["commentCount"] = FieldValue.increment(Int64(1))
        case "share":
            updateData["shareCount"] = FieldValue.increment(Int64(1))
        default:
            break
        }
        
        if !updateData.isEmpty {
            try? await storyRef.updateData(updateData)
        }
        #endif
        
        // Track in analytics
        EnhancedAnalyticsManager.shared.logEvent("story_engagement", parameters: [
            "story_id": storyId,
            "action": action,
            "user_id": userId,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Update engagement score with higher weight for engagement
        let engagementWeight: Double = action == "like" ? 2.0 : action == "share" ? 3.0 : 1.0
        await updateStoryEngagement(storyId: storyId, action: action, value: engagementWeight)
    }
    
    private func updateStoryEngagement(storyId: String, action: String, value: Any) async {
        do {
            let request = StoryEngagementUpdateRequest(
                storyId: storyId,
                action: action,
                value: value,
                timestamp: Date().timeIntervalSince1970
            )
            
            let _ = try await performMLRequest(
                url: trendingMLURL + "/update/story",
                request: request,
                responseType: StoryEngagementUpdateResponse.self
            )
            
        } catch {
            // Non-critical error, don't throw
            print("Failed to update story engagement: \(error)")
        }
    }
    
    private func predictStoryPerformance(story: EnhancedStory) async {
        do {
            let request = StoryViralPredictionRequest(
                storyId: story.id,
                creatorId: story.creatorId,
                mediaType: story.mediaType.rawValue,
                duration: story.duration,
                tags: story.tags,
                uploadTime: story.createdAt.timeIntervalSince1970
            )
            
            let response = try await performMLRequest(
                url: viralPredictionURL + "/predict/story",
                request: request,
                responseType: StoryViralPredictionResponse.self
            )
            
            // Store prediction in Firestore
            #if canImport(FirebaseFirestore)
            let db = Firestore.firestore()
            try? await db.collection("stories").document(story.id).updateData([
                "viralScore": response.viralScore,
                "predictedViews": response.predictedViews,
                "engagementPrediction": response.prediction
            ])
            #endif
            
        } catch {
            print("Story performance prediction failed: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func performMLRequest<T: Encodable, R: Decodable>(
        url: String,
        request: T,
        responseType: R.Type
    ) async throws -> R {
        guard let requestURL = URL(string: url) else {
            throw StoriesError.invalidURL
        }
        
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.configured.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw StoriesError.serverError
        }
        
        return try JSONDecoder().decode(responseType, from: data)
    }
    
    private func storyToMLData(_ story: EnhancedStory) -> [String: Any] {
        return [
            "id": story.id,
            "creatorId": story.creatorId,
            "mediaType": story.mediaType.rawValue,
            "duration": story.duration,
            "viewCount": story.viewCount,
            "likeCount": story.likeCount,
            "commentCount": story.commentCount,
            "shareCount": story.shareCount,
            "engagementScore": story.engagementScore,
            "createdAt": story.createdAt.timeIntervalSince1970,
            "tags": story.tags,
            "isPublic": story.isPublic
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
    
    private func getCurrentUser() -> User? {
        return AppState.shared.currentUser
    }
}

// MARK: - Supporting Types

struct EnhancedStory: Identifiable, Codable {
    let id: String
    let creatorId: String
    let creatorUsername: String
    let creatorDisplayName: String
    let creatorAvatarURL: String
    let mediaURL: String
    let mediaType: StoryMediaType
    let thumbnailURL: String?
    let duration: TimeInterval
    let createdAt: Date
    let expiresAt: Date
    let viewCount: Int
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let engagementScore: Double
    let isPublic: Bool
    let isActive: Bool
    let tags: [String]
    let location: String?
    let musicTrack: StoryMusicTrack?
    
    // Convert to AssetStory for UI compatibility
    func toAssetStory() -> AssetStory {
        let media: AssetMedia = mediaType == .video ? .video(mediaURL) : .image(mediaURL)
        
        return AssetStory(
            id: id,
            media: media,
            username: creatorUsername,
            authorImageName: creatorAvatarURL,
            creatorId: creatorId,
            originalStoryId: id
        )
    }
}

enum StoryMediaType: String, Codable, CaseIterable {
    case image = "image"
    case video = "video"
}

struct StoryMusicTrack: Codable {
    let title: String
    let artist: String
    let albumArt: String
    let duration: TimeInterval
}

struct StoryUploadMetadata {
    let duration: TimeInterval
    let isPublic: Bool
    let tags: [String]
    let location: String?
    let musicTrack: StoryMusicTrack?
}

struct StoryContext: Codable {
    let timeOfDay: String
    let dayOfWeek: String
    let location: String?
}

// MARK: - ML Request/Response Types

struct StoryRankingRequest: Encodable {
    let userId: String
    let stories: [[String: Any]]
    let context: StoryContext
    
    enum CodingKeys: String, CodingKey {
        case userId, context
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(context, forKey: .context)
    }
}

struct StoryRankingResponse: Codable {
    let rankedStoryIds: [String]
    let scores: [String: Double]
}

struct StoryModerationRequest: Codable {
    let storyId: String
    let creatorId: String
    let mediaURL: String
    let mediaType: String
    let tags: [String]
}

struct StoryModerationResponse: Codable {
    let isApproved: Bool
    let confidenceScore: Double
    let flags: [String]
    let reason: String?
}

struct StoryThumbnailRequest: Codable {
    let videoURL: String
    let timestamp: Double
    let quality: String
}

struct StoryThumbnailResponse: Codable {
    let thumbnailURL: String
    let success: Bool
}

struct StoryViralPredictionRequest: Codable {
    let storyId: String
    let creatorId: String
    let mediaType: String
    let duration: TimeInterval
    let tags: [String]
    let uploadTime: TimeInterval
}

struct StoryViralPredictionResponse: Codable {
    let viralScore: Double
    let prediction: String
    let predictedViews: Int
    let confidence: Double
}

struct StoryEngagementUpdateRequest: Encodable {
    let storyId: String
    let action: String
    let value: Any
    let timestamp: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case storyId, action, timestamp
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(storyId, forKey: .storyId)
        try container.encode(action, forKey: .action)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

struct StoryEngagementUpdateResponse: Codable {
    let success: Bool
    let newEngagementScore: Double
}

// MARK: - Error Types

enum StoriesError: LocalizedError {
    case storageUnavailable
    case firestoreUnavailable
    case invalidURL
    case serverError
    case moderationFailed
    
    var errorDescription: String? {
        switch self {
        case .storageUnavailable:
            return "Firebase Storage is not available"
        case .firestoreUnavailable:
            return "Firestore is not available"
        case .invalidURL:
            return "Invalid service URL"
        case .serverError:
            return "Server error occurred"
        case .moderationFailed:
            return "Content moderation failed"
        }
    }
}
