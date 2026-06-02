//
//  FlicksBackendService.swift
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

// 🎬 Enterprise-Grade Flicks Backend Service
// Industry-standard short-form video backend with ML integration
@MainActor
class FlicksBackendService: ObservableObject {
    static let shared = FlicksBackendService()
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var cachedFlicks: [NuclearFlick] = []
    
    private let cache = NSCache<NSString, NSArray>()
    private let uploadQueue = OperationQueue()
    private var cancellables = Set<AnyCancellable>()
    
    // ML Services Integration
    private let contentModerationURL = "https://content-moderation-fkri6ifojq-uc.a.run.app"
    private let viralPredictionURL = "https://viral-prediction-fkri6ifojq-uc.a.run.app"
    private let thumbnailGeneratorURL = "https://thumbnail-generator-fkri6ifojq-uc.a.run.app"
    private let recommendationURL = "https://recommendations-fkri6ifojq-uc.a.run.app"
    private let trendingMLURL = "https://trending-ml-fkri6ifojq-uc.a.run.app"
    
    private init() {
        setupUploadQueue()
        setupCache()
    }
    
    // MARK: - Configuration
    
    private func setupUploadQueue() {
        uploadQueue.maxConcurrentOperationCount = RemoteConfigManager.shared.maxConcurrentUploads
        uploadQueue.qualityOfService = .userInitiated
    }
    
    private func setupCache() {
        cache.countLimit = 500 // Cache up to 500 flicks
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB cache limit
    }
    
    // MARK: - Flicks Loading
    
    func loadFlicks(page: Int = 0, limit: Int = 50) async throws -> [NuclearFlick] {
        let startTime = Date()
        
        // Start performance tracking
        PerformanceMonitoringManager.shared.startTrace(name: "flicks_load", attributes: [
            "page": String(page),
            "limit": String(limit)
        ])
        
        // Update monitoring metrics
        MonitoringDashboardManager.shared.incrementCounter("flicks_requests")
        
        defer {
            let loadTime = Date().timeIntervalSince(startTime)
            PerformanceMonitoringManager.shared.stopTrace(name: "flicks_load", metrics: [
                "load_time_ms": Int64(loadTime * 1000)
            ])
            MonitoringDashboardManager.shared.recordLatency("flicks_load_time", latency: loadTime)
        }
        
        // Check cache first
        let cacheKey = "flicks_page_\(page)_\(limit)" as NSString
        if let cachedResults = cache.object(forKey: cacheKey) as? [NuclearFlick] {
            EnhancedAnalyticsManager.shared.logEvent("flicks_cache_hit", parameters: [
                "page": page,
                "limit": limit,
                "cached_count": cachedResults.count
            ])
            return cachedResults
        }
        
        isLoading = true
        error = nil
        
        do {
            // Load from multiple sources with fallback
            let flicks = try await loadFlicksFromSources(page: page, limit: limit)
            
            // Apply ML-powered ranking and filtering
            let rankedFlicks = await applyMLRanking(flicks)
            let moderatedFlicks = await applyContentModeration(rankedFlicks)
            
            // Cache results
            cache.setObject(moderatedFlicks as NSArray, forKey: cacheKey)
            
            // Track analytics
            EnhancedAnalyticsManager.shared.logEvent("flicks_loaded", parameters: [
                "source": "firestore",
                "page": page,
                "limit": limit,
                "loaded_count": moderatedFlicks.count,
                "load_time_ms": Date().timeIntervalSince(startTime) * 1000
            ])
            
            isLoading = false
            return moderatedFlicks
            
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            
            // Report error
            ErrorReportingManager.shared.reportError(
                error,
                context: "FlicksLoad",
                severity: .warning,
                metadata: [
                    "page": page,
                    "limit": limit
                ]
            )
            
            MonitoringDashboardManager.shared.incrementCounter("flicks_errors")
            throw error
        }
    }
    
    private func loadFlicksFromSources(page: Int, limit: Int) async throws -> [NuclearFlick] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Try flicks collection first
        let shortsQuery = db.collection("flicks")
            .whereField("isPublic", isEqualTo: true)
            .whereField("status", isEqualTo: "published")
            .order(by: "trendingScore", descending: true)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        
        let shortsSnapshot = try await shortsQuery.getDocuments()
        
        if !shortsSnapshot.documents.isEmpty {
            return shortsSnapshot.documents.compactMap { doc in
                parseFlickFromDocument(doc)
            }
        }
        
        // Fallback to videos collection with portrait aspect ratio
        let videosQuery = db.collection("videos")
            .whereField("isPublic", isEqualTo: true)
            .whereField("aspectRatio", isEqualTo: "portrait")
            .whereField("duration", isLessThan: 180) // Max 3 minutes for shorts
            .order(by: "trendingScore", descending: true)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        
        let videosSnapshot = try await videosQuery.getDocuments()
        
        return videosSnapshot.documents.compactMap { doc in
            parseFlickFromDocument(doc)
        }
        #else
        throw FlicksError.firebaseUnavailable
        #endif
    }
    
    private func parseFlickFromDocument(_ doc: DocumentSnapshot) -> NuclearFlick? {
        let data = doc.data() ?? [:]
        
        guard let title = data["title"] as? String,
              let videoURL = data["videoURL"] as? String ?? data["videoUrl"] as? String,
              !videoURL.isEmpty else {
            return nil
        }
        
        let creatorData = data["creator"] as? [String: Any] ?? [:]
        let creator = FlickCreator(
            id: creatorData["id"] as? String ?? "unknown",
            username: creatorData["username"] as? String ?? "unknown",
            displayName: creatorData["displayName"] as? String ?? "Unknown Creator",
            profileImageURL: creatorData["profileImageURL"] as? String ?? "",
            isVerified: creatorData["isVerified"] as? Bool ?? false
        )
        
        let musicData = data["musicTrack"] as? [String: Any]
        let musicTrack = musicData != nil ? FlickMusicTrack(
            title: musicData!["title"] as? String ?? "",
            artist: musicData!["artist"] as? String ?? "",
            albumArt: musicData!["albumArt"] as? String ?? ""
        ) : nil
        
        return NuclearFlick(
            id: doc.documentID,
            videoURL: videoURL,
            thumbnailURL: data["thumbnailURL"] as? String ?? data["thumbnailUrl"] as? String ?? "",
            title: title,
            description: data["description"] as? String ?? "",
            duration: data["duration"] as? TimeInterval ?? 30.0,
            viewCount: data["viewCount"] as? Int ?? 0,
            likeCount: data["likeCount"] as? Int ?? 0,
            commentCount: data["commentCount"] as? Int ?? 0,
            shareCount: data["shareCount"] as? Int ?? 0,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            creator: creator,
            tags: data["tags"] as? [String] ?? [],
            musicTrack: musicTrack,
            contentSource: .userUploaded,
            externalID: data["externalID"] as? String
        )
    }
    
    // MARK: - ML-Powered Features
    
    private func applyMLRanking(_ flicks: [NuclearFlick]) async -> [NuclearFlick] {
        guard RemoteConfigManager.shared.isRecommendationEngineEnabled else {
            return flicks
        }
        
        do {
            let request = MLRankingRequest(
                flicks: flicks.map { flickToMLData($0) },
                userId: getCurrentUserId(),
                context: "flicks_feed"
            )
            
            let response = try await performMLRequest(
                url: recommendationURL + "/rank",
                request: request,
                responseType: MLRankingResponse.self
            )
            
            // Reorder flicks based on ML ranking
            let rankedFlicks = response.rankedIds.compactMap { id in
                flicks.first { $0.id == id }
            }
            
            // Add any flicks not in ranking at the end
            let unrankedFlicks = flicks.filter { flick in
                !response.rankedIds.contains(flick.id)
            }
            
            return rankedFlicks + unrankedFlicks as [NuclearFlick]
            
        } catch {
            ErrorReportingManager.shared.reportMLServiceError(
                serviceName: "recommendation_ranking",
                error: error,
                requestData: ["flick_count": flicks.count],
                responseTime: 0
            )
            return flicks
        }
    }
    
    private func applyContentModeration(_ flicks: [NuclearFlick]) async -> [NuclearFlick] {
        guard RemoteConfigManager.shared.isContentModerationEnabled else {
            return flicks
        }
        
        let moderatedFlicks = await withTaskGroup(of: (NuclearFlick, Bool).self) { group in
            for flick in flicks {
                group.addTask {
                    let isApproved = await self.moderateFlick(flick)
                    return (flick, isApproved)
                }
            }
            
            var results: [NuclearFlick] = []
            for await (flick, isApproved) in group {
                if isApproved {
                    results.append(flick)
                }
            }
            return results
        }
        
        return moderatedFlicks
    }
    
    private func moderateFlick(_ flick: NuclearFlick) async -> Bool {
        do {
            let request = ContentModerationRequest(
                contentId: flick.id,
                title: flick.title,
                description: flick.description,
                tags: flick.tags,
                thumbnailURL: flick.thumbnailURL
            )
            
            let response = try await performMLRequest(
                url: contentModerationURL + "/moderate",
                request: request,
                responseType: ContentModerationResponse.self
            )
            
            return response.isApproved && response.confidenceScore > 0.7
            
        } catch {
            // Default to approved if moderation fails
            return true
        }
    }
    
    // MARK: - Flicks Upload
    
    func uploadFlick(
        videoData: Data,
        thumbnailData: Data?,
        metadata: FlickUploadMetadata
    ) async throws -> String {
        let startTime = Date()
        let flickId = UUID().uuidString
        
        // Start performance tracking
        PerformanceMonitoringManager.shared.trackUploadPerformance(
            fileSize: Int64(videoData.count),
            uploadTime: 0,
            contentType: "flick"
        )
        
        // Track upload start
        EnhancedAnalyticsManager.shared.trackUploadStart(
            contentType: "flick",
            fileSize: Int64(videoData.count),
            estimatedDuration: metadata.duration
        )
        
        do {
            // Upload video to Firebase Storage
            let videoURL = try await uploadVideoToStorage(
                videoData: videoData,
                flickId: flickId
            )
            
            // Generate or upload thumbnail
            let thumbnailURL = try await uploadThumbnailToStorage(
                thumbnailData: thumbnailData,
                videoURL: videoURL,
                flickId: flickId
            )
            
            // Create Firestore document
            let flick = try await createFlickDocument(
                flickId: flickId,
                videoURL: videoURL,
                thumbnailURL: thumbnailURL,
                metadata: metadata
            )
            
            // Predict viral potential
            await predictViralPotential(flick: flick)
            
            // Track successful upload
            let uploadTime = Date().timeIntervalSince(startTime)
            EnhancedAnalyticsManager.shared.trackUploadComplete(
                contentId: flickId,
                contentType: "flick",
                uploadDuration: uploadTime,
                fileSize: Int64(videoData.count)
            )
            
            // Clear cache to refresh feed
            cache.removeAllObjects()
            
            return flickId
            
        } catch {
            ErrorReportingManager.shared.reportUploadError(
                error: error,
                fileSize: Int64(videoData.count),
                contentType: "flick",
                progress: 0.0
            )
            
            throw error
        }
    }
    
    private func uploadVideoToStorage(videoData: Data, flickId: String) async throws -> String {
        #if canImport(FirebaseStorage)
        let storage = Storage.storage()
        let videoRef = storage.reference().child("flicks/\(flickId)/video.mp4")
        
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        metadata.customMetadata = [
            "flickId": flickId,
            "uploadedAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        let _ = try await videoRef.putDataAsync(videoData, metadata: metadata)
        let downloadURL = try await videoRef.downloadURL()
        
        return downloadURL.absoluteString
        #else
        throw FlicksError.storageUnavailable
        #endif
    }
    
    private func uploadThumbnailToStorage(
        thumbnailData: Data?,
        videoURL: String,
        flickId: String
    ) async throws -> String {
        #if canImport(FirebaseStorage)
        let storage = Storage.storage()
        let thumbnailRef = storage.reference().child("flicks/\(flickId)/thumbnail.jpg")
        
        let finalThumbnailData: Data
        
        if let thumbnailData = thumbnailData {
            finalThumbnailData = thumbnailData
        } else {
            // Generate thumbnail using ML service
            finalThumbnailData = try await generateThumbnail(videoURL: videoURL)
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let _ = try await thumbnailRef.putDataAsync(finalThumbnailData, metadata: metadata)
        let downloadURL = try await thumbnailRef.downloadURL()
        
        return downloadURL.absoluteString
        #else
        throw FlicksError.storageUnavailable
        #endif
    }
    
    private func generateThumbnail(videoURL: String) async throws -> Data {
        let request = ThumbnailGenerationRequest(
            videoURL: videoURL,
            timestamp: 1.0, // 1 second into video
            quality: "high"
        )
        
        let response = try await performMLRequest(
            url: thumbnailGeneratorURL + "/generate",
            request: request,
            responseType: ThumbnailGenerationResponse.self
        )
        
        guard let thumbnailURL = URL(string: response.thumbnailURL),
              let thumbnailData = try? Data(contentsOf: thumbnailURL) else {
            throw FlicksError.thumbnailGenerationFailed
        }
        
        return thumbnailData
    }
    
    private func createFlickDocument(
        flickId: String,
        videoURL: String,
        thumbnailURL: String,
        metadata: FlickUploadMetadata
    ) async throws -> NuclearFlick {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let flickData: [String: Any] = [
            "id": flickId,
            "title": metadata.title,
            "description": metadata.description,
            "videoURL": videoURL,
            "thumbnailURL": thumbnailURL,
            "duration": metadata.duration,
            "tags": metadata.tags,
            "category": metadata.category,
            "isPublic": metadata.isPublic,
            "aspectRatio": "portrait",
            "contentSource": "userUploaded",
            "status": "published",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "viewCount": 0,
            "likeCount": 0,
            "commentCount": 0,
            "shareCount": 0,
            "trendingScore": 0.0,
            "creator": [
                "id": getCurrentUserId(),
                "username": getCurrentUser()?.username ?? "unknown",
                "displayName": getCurrentUser()?.displayName ?? "Unknown",
                "profileImageURL": getCurrentUser()?.profileImageURL ?? "",
                "isVerified": getCurrentUser()?.isVerified ?? false
            ]
        ]
        
        try await db.collection("flicks").document(flickId).setData(flickData)
        
        // Create the NuclearFlick object
        let creator = FlickCreator(
            id: getCurrentUserId(),
            username: getCurrentUser()?.username ?? "unknown",
            displayName: getCurrentUser()?.displayName ?? "Unknown",
            profileImageURL: getCurrentUser()?.profileImageURL ?? "",
            isVerified: getCurrentUser()?.isVerified ?? false
        )
        
        return NuclearFlick(
            id: flickId,
            videoURL: videoURL,
            thumbnailURL: thumbnailURL,
            title: metadata.title,
            description: metadata.description,
            duration: metadata.duration,
            viewCount: 0,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            createdAt: Date(),
            creator: creator,
            tags: metadata.tags,
            musicTrack: nil,
            contentSource: .userUploaded,
            externalID: nil
        )
        #else
        throw FlicksError.firestoreUnavailable
        #endif
    }
    
    // MARK: - Analytics & Tracking
    
    func trackFlickView(flickId: String, watchTime: TimeInterval) async {
        // Update view count in Firestore
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let flickRef = db.collection("flicks").document(flickId)
        
        try? await flickRef.updateData([
            "viewCount": FieldValue.increment(Int64(1)),
            "totalWatchTime": FieldValue.increment(Int64(watchTime)),
            "lastViewed": FieldValue.serverTimestamp()
        ])
        #endif
        
        // Track in analytics
        EnhancedAnalyticsManager.shared.logEvent("flick_viewed", parameters: [
            "flick_id": flickId,
            "watch_time": watchTime,
            "completion_rate": min(watchTime / 30.0, 1.0), // Assuming 30s average
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Update trending score
        await updateTrendingScore(flickId: flickId, engagement: "view", value: watchTime)
    }
    
    func trackFlickEngagement(flickId: String, action: String, value: Any? = nil) async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let flickRef = db.collection("flicks").document(flickId)
        
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
            try? await flickRef.updateData(updateData)
        }
        #endif
        
        // Track in analytics
        EnhancedAnalyticsManager.shared.logEvent("flick_engagement", parameters: [
            "flick_id": flickId,
            "action": action,
            "value": value ?? "",
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Update trending score with higher weight for engagement
        let engagementWeight: Double = action == "like" ? 2.0 : action == "share" ? 3.0 : 1.0
        await updateTrendingScore(flickId: flickId, engagement: action, value: engagementWeight)
    }
    
    private func updateTrendingScore(flickId: String, engagement: String, value: Any) async {
        do {
            let request = TrendingUpdateRequest(
                contentId: flickId,
                contentType: "flick",
                engagement: engagement,
                value: value,
                timestamp: Date().timeIntervalSince1970
            )
            
            let _ = try await performMLRequest(
                url: trendingMLURL + "/update",
                request: request,
                responseType: TrendingUpdateResponse.self
            )
            
        } catch {
            // Non-critical error, don't throw
            print("Failed to update trending score: \(error)")
        }
    }
    
    private func predictViralPotential(flick: NuclearFlick) async {
        do {
            let request = ViralPredictionRequest(
                flickId: flick.id,
                title: flick.title,
                description: flick.description,
                tags: flick.tags,
                duration: flick.duration,
                creatorFollowers: 0, // Would get from user data
                uploadTime: flick.createdAt.timeIntervalSince1970
            )
            
            let response = try await performMLRequest(
                url: viralPredictionURL + "/predict",
                request: request,
                responseType: ViralPredictionResponse.self
            )
            
            // Store viral prediction in Firestore
            #if canImport(FirebaseFirestore)
            let db = Firestore.firestore()
            try? await db.collection("flicks").document(flick.id).updateData([
                "viralScore": response.viralScore,
                "viralPrediction": response.prediction,
                "predictedViews": response.predictedViews
            ])
            #endif
            
        } catch {
            print("Viral prediction failed: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func performMLRequest<T: Codable, R: Codable>(
        url: String,
        request: T,
        responseType: R.Type
    ) async throws -> R {
        guard let requestURL = URL(string: url) else {
            throw FlicksError.invalidURL
        }
        
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.configured.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw FlicksError.serverError
        }
        
        return try JSONDecoder().decode(responseType, from: data)
    }
    
    private func flickToMLData(_ flick: NuclearFlick) -> [String: Any] {
        return [
            "id": flick.id,
            "title": flick.title,
            "description": flick.description,
            "tags": flick.tags,
            "duration": flick.duration,
            "viewCount": flick.viewCount,
            "likeCount": flick.likeCount,
            "commentCount": flick.commentCount,
            "shareCount": flick.shareCount,
            "createdAt": flick.createdAt.timeIntervalSince1970,
            "creatorId": flick.creator.id
        ]
    }
    
    private func getCurrentUserId() -> String {
        return AppState.shared.currentUser?.id ?? "anonymous"
    }
    
    private func getCurrentUser() -> User? {
        return AppState.shared.currentUser
    }
}

// MARK: - Supporting Types

struct FlickUploadMetadata {
    let title: String
    let description: String
    let tags: [String]
    let category: String
    let duration: TimeInterval
    let isPublic: Bool
}

enum FlicksError: LocalizedError {
    case firebaseUnavailable
    case firestoreUnavailable
    case storageUnavailable
    case thumbnailGenerationFailed
    case invalidURL
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .firebaseUnavailable:
            return "Firebase is not available"
        case .firestoreUnavailable:
            return "Firestore is not available"
        case .storageUnavailable:
            return "Firebase Storage is not available"
        case .thumbnailGenerationFailed:
            return "Failed to generate thumbnail"
        case .invalidURL:
            return "Invalid URL"
        case .serverError:
            return "Server error occurred"
        }
    }
}

// MARK: - ML Request/Response Types

struct MLRankingRequest: Codable {
    let flicks: [[String: Any]]
    let userId: String
    let context: String
    
    init(flicks: [[String: Any]], userId: String, context: String) {
        self.flicks = flicks
        self.userId = userId
        self.context = context
    }
    
    enum CodingKeys: String, CodingKey {
        case flicks, userId, context
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        context = try container.decode(String.self, forKey: .context)
        
        // Decode flicks as JSON array and convert to [String: Any]
        let flicksData = try container.decode([FlickData].self, forKey: .flicks)
        flicks = flicksData.map { $0.toDictionary() }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(context, forKey: .context)
        
        // Convert [String: Any] to encodable format
        let flicksData = flicks.map { FlickData(from: $0) }
        try container.encode(flicksData, forKey: .flicks)
    }
}

// Helper struct for encoding/decoding [String: Any]
struct FlickData: Codable {
    let data: [String: JSONValue]
    
    init(from dictionary: [String: Any]) {
        data = dictionary.mapValues { JSONValue(from: $0) }
    }
    
    func toDictionary() -> [String: Any] {
        return data.mapValues { $0.toAny() }
    }
}

enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null
    
    init(from value: Any) {
        if let string = value as? String {
            self = .string(string)
        } else if let int = value as? Int {
            self = .int(int)
        } else if let double = value as? Double {
            self = .double(double)
        } else if let bool = value as? Bool {
            self = .bool(bool)
        } else if let array = value as? [Any] {
            self = .array(array.map { JSONValue(from: $0) })
        } else if let object = value as? [String: Any] {
            self = .object(object.mapValues { JSONValue(from: $0) })
        } else {
            self = .null
        }
    }
    
    func toAny() -> Any {
        switch self {
        case .string(let string): return string
        case .int(let int): return int
        case .double(let double): return double
        case .bool(let bool): return bool
        case .array(let array): return array.map { $0.toAny() }
        case .object(let object): return object.mapValues { $0.toAny() }
        case .null: return NSNull()
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            self = .null
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let string): try container.encode(string)
        case .int(let int): try container.encode(int)
        case .double(let double): try container.encode(double)
        case .bool(let bool): try container.encode(bool)
        case .array(let array): try container.encode(array)
        case .object(let object): try container.encode(object)
        case .null: try container.encodeNil()
        }
    }
}

struct MLRankingResponse: Codable {
    let rankedIds: [String]
    let scores: [Double]
}

struct ContentModerationRequest: Codable {
    let contentId: String
    let title: String
    let description: String
    let tags: [String]
    let thumbnailURL: String
}

struct ContentModerationResponse: Codable {
    let isApproved: Bool
    let confidenceScore: Double
    let flags: [String]
    let reason: String?
}

struct ThumbnailGenerationRequest: Codable {
    let videoURL: String
    let timestamp: Double
    let quality: String
}

struct ThumbnailGenerationResponse: Codable {
    let thumbnailURL: String
    let success: Bool
}

struct ViralPredictionRequest: Codable {
    let flickId: String
    let title: String
    let description: String
    let tags: [String]
    let duration: TimeInterval
    let creatorFollowers: Int
    let uploadTime: TimeInterval
}

struct ViralPredictionResponse: Codable {
    let viralScore: Double
    let prediction: String
    let predictedViews: Int
    let confidence: Double
}

struct TrendingUpdateRequest: Codable {
    let contentId: String
    let contentType: String
    let engagement: String
    let value: JSONValue
    let timestamp: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case contentId, contentType, engagement, value, timestamp
    }
    
    init(contentId: String, contentType: String, engagement: String, value: Any, timestamp: TimeInterval) {
        self.contentId = contentId
        self.contentType = contentType
        self.engagement = engagement
        self.value = JSONValue(from: value)
        self.timestamp = timestamp
    }
}

struct TrendingUpdateResponse: Codable {
    let success: Bool
    let newScore: Double
}
