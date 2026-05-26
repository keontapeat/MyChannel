//
//  EnhancedVideoManagementService.swift
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

// 📹 Enterprise Video Management Service
// Industry-standard video management with YouTube-level features
@MainActor
class EnhancedVideoManagementService: ObservableObject {
    static let shared = EnhancedVideoManagementService()
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var videos: [EnhancedVideo] = []
    @Published var filteredVideos: [EnhancedVideo] = []
    @Published var selectedFilter: VideoManagementFilter = .all
    @Published var sortOption: VideoSortOption = .uploadDate
    @Published var viewMode: VideoViewMode = .list
    
    // Performance tracking
    private let cache = NSCache<NSString, NSArray>()
    private var cancellables = Set<AnyCancellable>()
    
    // ML Services Integration
    private let videoAnalyticsURL = "https://video-analytics-fkri6ifojq-uc.a.run.app"
    private let videoOptimizationURL = "https://video-optimization-fkri6ifojq-uc.a.run.app"
    private let contentModerationURL = "https://content-moderation-fkri6ifojq-uc.a.run.app"
    private let performanceInsightsURL = "https://performance-insights-fkri6ifojq-uc.a.run.app"
    private let videoSEOURL = "https://video-seo-fkri6ifojq-uc.a.run.app"
    
    private init() {
        setupCache()
        startPerformanceTracking()
    }
    
    // MARK: - Configuration
    
    private func setupCache() {
        cache.countLimit = 500 // Cache up to 500 videos
        cache.totalCostLimit = 200 * 1024 * 1024 // 200MB cache limit
    }
    
    private func startPerformanceTracking() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                self.updatePerformanceMetrics()
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        MonitoringDashboardManager.shared.updateMetric("video_management_cache_size", value: Double(cache.totalCostLimit))
        MonitoringDashboardManager.shared.updateMetric("videos_loaded_count", value: Double(videos.count))
    }
    
    // MARK: - Video Loading with Enhanced Features
    
    func loadVideos(creatorId: String, filter: VideoManagementFilter = .all, limit: Int = 50) async throws -> [EnhancedVideo] {
        let startTime = Date()
        
        // Start performance tracking
        PerformanceMonitoringManager.shared.startTrace(name: "video_management_load", attributes: [
            "creator_id": creatorId,
            "filter": filter.rawValue,
            "limit": String(limit)
        ])
        
        // Update monitoring metrics
        MonitoringDashboardManager.shared.incrementCounter("video_management_requests")
        
        defer {
            let loadTime = Date().timeIntervalSince(startTime)
            PerformanceMonitoringManager.shared.stopTrace(name: "video_management_load", metrics: [
                "load_time_ms": Int64(loadTime * 1000)
            ])
            MonitoringDashboardManager.shared.recordLatency("video_management_load_time", latency: loadTime)
        }
        
        // Check cache first
        let cacheKey = "videos_\(creatorId)_\(filter.rawValue)_\(limit)" as NSString
        if let cachedResults = cache.object(forKey: cacheKey) as? [EnhancedVideo] {
            EnhancedAnalyticsManager.shared.logEvent("video_management_cache_hit", parameters: [
                "creator_id": creatorId,
                "filter": filter.rawValue,
                "cached_count": cachedResults.count
            ])
            return cachedResults
        }
        
        isLoading = true
        error = nil
        
        do {
            // Load videos from Firestore with enhanced data
            let loadedVideos = try await loadVideosFromFirestore(creatorId: creatorId, filter: filter, limit: limit)
            
            // Enhance with ML analytics
            let enhancedVideos = await enhanceVideosWithML(loadedVideos)
            
            // Apply sorting
            let sortedVideos = sortVideos(enhancedVideos, by: sortOption)
            
            // Cache results
            cache.setObject(sortedVideos as NSArray, forKey: cacheKey)
            
            // Track analytics
            EnhancedAnalyticsManager.shared.logEvent("videos_loaded", parameters: [
                "creator_id": creatorId,
                "filter": filter.rawValue,
                "loaded_count": sortedVideos.count,
                "load_time_ms": Date().timeIntervalSince(startTime) * 1000,
                "enhanced_backend": true
            ])
            
            videos = sortedVideos
            filteredVideos = sortedVideos
            selectedFilter = filter
            isLoading = false
            
            return sortedVideos
            
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            
            // Report error
            ErrorReportingManager.shared.reportError(
                error,
                context: "VideoManagementLoad",
                severity: .warning,
                metadata: [
                    "creator_id": creatorId,
                    "filter": filter.rawValue,
                    "limit": limit
                ]
            )
            
            MonitoringDashboardManager.shared.incrementCounter("video_management_errors")
            throw error
        }
    }
    
    private func loadVideosFromFirestore(creatorId: String, filter: VideoManagementFilter, limit: Int) async throws -> [EnhancedVideo] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        var query = db.collection("videos")
            .whereField("creatorId", isEqualTo: creatorId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        
        // Apply filter
        switch filter {
        case .all:
            break // No additional filter
        case .publicVideos:
            query = query.whereField("visibility", isEqualTo: "public")
        case .unlisted:
            query = query.whereField("visibility", isEqualTo: "unlisted")
        case .privateVideos:
            query = query.whereField("visibility", isEqualTo: "private")
        case .scheduled:
            query = query.whereField("isScheduled", isEqualTo: true)
        case .drafts:
            query = query.whereField("status", isEqualTo: "draft")
        case .live:
            query = query.whereField("isLive", isEqualTo: true)
        }
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { doc in
            parseEnhancedVideoFromDocument(doc)
        }
        #else
        return []
        #endif
    }
    
    private func parseEnhancedVideoFromDocument(_ doc: DocumentSnapshot) -> EnhancedVideo? {
        let data = doc.data() ?? [:]
        
        guard let title = data["title"] as? String,
              let creatorId = data["creatorId"] as? String else {
            return nil
        }
        
        return EnhancedVideo(
            id: doc.documentID,
            title: title,
            description: data["description"] as? String ?? "",
            creatorId: creatorId,
            creatorName: data["creatorName"] as? String ?? "Unknown",
            creatorAvatarURL: data["creatorAvatarURL"] as? String ?? "",
            thumbnailURL: data["thumbnailURL"] as? String ?? "",
            videoURL: data["videoURL"] as? String ?? "",
            duration: data["duration"] as? TimeInterval ?? 0,
            visibility: VideoVisibility(rawValue: data["visibility"] as? String ?? "public") ?? .publicVideo,
            status: VideoStatus(rawValue: data["status"] as? String ?? "published") ?? .published,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            publishedAt: (data["publishedAt"] as? Timestamp)?.dateValue(),
            scheduledAt: (data["scheduledAt"] as? Timestamp)?.dateValue(),
            viewCount: data["viewCount"] as? Int ?? 0,
            likeCount: data["likeCount"] as? Int ?? 0,
            dislikeCount: data["dislikeCount"] as? Int ?? 0,
            commentCount: data["commentCount"] as? Int ?? 0,
            shareCount: data["shareCount"] as? Int ?? 0,
            watchTime: data["watchTime"] as? TimeInterval ?? 0,
            engagementRate: data["engagementRate"] as? Double ?? 0.0,
            clickThroughRate: data["clickThroughRate"] as? Double ?? 0.0,
            retentionRate: data["retentionRate"] as? Double ?? 0.0,
            tags: data["tags"] as? [String] ?? [],
            category: data["category"] as? String ?? "",
            language: data["language"] as? String ?? "en",
            isLive: data["isLive"] as? Bool ?? false,
            isScheduled: data["isScheduled"] as? Bool ?? false,
            monetizationEnabled: data["monetizationEnabled"] as? Bool ?? false,
            ageRestricted: data["ageRestricted"] as? Bool ?? false,
            copyrightClaims: data["copyrightClaims"] as? [String] ?? [],
            performanceScore: data["performanceScore"] as? Double ?? 0.0,
            seoScore: data["seoScore"] as? Double ?? 0.0,
            thumbnailOptimizationScore: data["thumbnailOptimizationScore"] as? Double ?? 0.0,
            mlInsights: nil // Will be populated by ML enhancement
        )
    }
    
    private func enhanceVideosWithML(_ videos: [EnhancedVideo]) async -> [EnhancedVideo] {
        guard RemoteConfigManager.shared.isMLEnhancementEnabled else {
            return videos
        }
        
        return await withTaskGroup(of: EnhancedVideo.self) { group in
            for video in videos {
                group.addTask {
                    await self.enhanceVideoWithML(video)
                }
            }
            
            var enhancedVideos: [EnhancedVideo] = []
            for await enhancedVideo in group {
                enhancedVideos.append(enhancedVideo)
            }
            
            // Maintain original order
            return videos.compactMap { originalVideo in
                enhancedVideos.first { $0.id == originalVideo.id }
            }
        }
    }
    
    private func enhanceVideoWithML(_ video: EnhancedVideo) async -> EnhancedVideo {
        do {
            let request = VideoAnalyticsRequest(
                videoId: video.id,
                creatorId: video.creatorId,
                videoMetadata: VideoMLMetadata(
                    title: video.title,
                    description: video.description,
                    tags: video.tags,
                    category: video.category,
                    duration: video.duration,
                    thumbnailURL: video.thumbnailURL
                ),
                performanceData: VideoPerformanceData(
                    views: video.viewCount,
                    likes: video.likeCount,
                    comments: video.commentCount,
                    shares: video.shareCount,
                    watchTime: video.watchTime,
                    engagementRate: video.engagementRate
                )
            )
            
            let response = try await performMLRequest(
                url: videoAnalyticsURL + "/analyze",
                request: request,
                responseType: VideoAnalyticsResponse.self
            )
            
            var enhancedVideo = video
            enhancedVideo.mlInsights = VideoMLInsights(
                performanceScore: response.performanceScore,
                seoScore: response.seoScore,
                thumbnailScore: response.thumbnailScore,
                titleOptimization: response.titleOptimization,
                descriptionOptimization: response.descriptionOptimization,
                tagSuggestions: response.tagSuggestions,
                audienceRetention: response.audienceRetention,
                viralPotential: response.viralPotential,
                competitorComparison: response.competitorComparison,
                optimizationTips: response.optimizationTips
            )
            
            return enhancedVideo
            
        } catch {
            // Return original video if ML enhancement fails
            return video
        }
    }
    
    // MARK: - Video Management Operations
    
    func updateVideoVisibility(videoId: String, visibility: VideoVisibility) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        try await db.collection("videos").document(videoId).updateData([
            "visibility": visibility.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Update local cache
        if let index = videos.firstIndex(where: { $0.id == videoId }) {
            videos[index].visibility = visibility
        }
        
        // Track analytics
        EnhancedAnalyticsManager.shared.logEvent("video_visibility_changed", parameters: [
            "video_id": videoId,
            "new_visibility": visibility.rawValue
        ])
        #endif
    }
    
    func scheduleVideo(videoId: String, scheduledDate: Date) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        try await db.collection("videos").document(videoId).updateData([
            "scheduledAt": Timestamp(date: scheduledDate),
            "isScheduled": true,
            "status": VideoStatus.scheduled.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Update local cache
        if let index = videos.firstIndex(where: { $0.id == videoId }) {
            videos[index].scheduledAt = scheduledDate
            videos[index].isScheduled = true
            videos[index].status = .scheduled
        }
        
        // Track analytics
        EnhancedAnalyticsManager.shared.logEvent("video_scheduled", parameters: [
            "video_id": videoId,
            "scheduled_date": scheduledDate.timeIntervalSince1970
        ])
        #endif
    }
    
    func deleteVideo(videoId: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Soft delete - mark as deleted instead of removing
        try await db.collection("videos").document(videoId).updateData([
            "status": VideoStatus.deleted.rawValue,
            "deletedAt": FieldValue.serverTimestamp()
        ])
        
        // Remove from local cache
        videos.removeAll { $0.id == videoId }
        filteredVideos.removeAll { $0.id == videoId }
        
        // Track analytics
        EnhancedAnalyticsManager.shared.logEvent("video_deleted", parameters: [
            "video_id": videoId
        ])
        #endif
    }
    
    func duplicateVideo(videoId: String) async throws -> String {
        guard let originalVideo = videos.first(where: { $0.id == videoId }) else {
            throw VideoManagementError.videoNotFound
        }
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let newVideoId = UUID().uuidString
        
        let duplicateData: [String: Any] = [
            "title": "\(originalVideo.title) (Copy)",
            "description": originalVideo.description,
            "creatorId": originalVideo.creatorId,
            "creatorName": originalVideo.creatorName,
            "thumbnailURL": originalVideo.thumbnailURL,
            "videoURL": originalVideo.videoURL,
            "duration": originalVideo.duration,
            "visibility": VideoVisibility.privateVideo.rawValue, // Always start as private
            "status": VideoStatus.draft.rawValue,
            "tags": originalVideo.tags,
            "category": originalVideo.category,
            "language": originalVideo.language,
            "monetizationEnabled": originalVideo.monetizationEnabled,
            "ageRestricted": originalVideo.ageRestricted,
            "createdAt": FieldValue.serverTimestamp(),
            "viewCount": 0,
            "likeCount": 0,
            "commentCount": 0,
            "shareCount": 0
        ]
        
        try await db.collection("videos").document(newVideoId).setData(duplicateData)
        
        // Track analytics
        EnhancedAnalyticsManager.shared.logEvent("video_duplicated", parameters: [
            "original_video_id": videoId,
            "new_video_id": newVideoId
        ])
        
        return newVideoId
        #else
        throw VideoManagementError.firestoreUnavailable
        #endif
    }
    
    // MARK: - Filtering and Sorting
    
    func applyFilter(_ filter: VideoManagementFilter) {
        selectedFilter = filter
        
        switch filter {
        case .all:
            filteredVideos = videos
        case .publicVideos:
            filteredVideos = videos.filter { $0.visibility == .publicVideo }
        case .unlisted:
            filteredVideos = videos.filter { $0.visibility == .unlisted }
        case .privateVideos:
            filteredVideos = videos.filter { $0.visibility == .privateVideo }
        case .scheduled:
            filteredVideos = videos.filter { $0.isScheduled }
        case .drafts:
            filteredVideos = videos.filter { $0.status == .draft }
        case .live:
            filteredVideos = videos.filter { $0.isLive }
        }
        
        // Re-apply sorting
        filteredVideos = sortVideos(filteredVideos, by: sortOption)
        
        // Track filter usage
        EnhancedAnalyticsManager.shared.logEvent("video_filter_applied", parameters: [
            "filter": filter.rawValue,
            "result_count": filteredVideos.count
        ])
    }
    
    func applySorting(_ sortOption: VideoSortOption) {
        self.sortOption = sortOption
        filteredVideos = sortVideos(filteredVideos, by: sortOption)
        
        // Track sorting usage
        EnhancedAnalyticsManager.shared.logEvent("video_sorting_applied", parameters: [
            "sort_option": sortOption.rawValue
        ])
    }
    
    private func sortVideos(_ videos: [EnhancedVideo], by sortOption: VideoSortOption) -> [EnhancedVideo] {
        switch sortOption {
        case .uploadDate:
            return videos.sorted { $0.createdAt > $1.createdAt }
        case .publishDate:
            return videos.sorted { ($0.publishedAt ?? Date.distantPast) > ($1.publishedAt ?? Date.distantPast) }
        case .views:
            return videos.sorted { $0.viewCount > $1.viewCount }
        case .likes:
            return videos.sorted { $0.likeCount > $1.likeCount }
        case .comments:
            return videos.sorted { $0.commentCount > $1.commentCount }
        case .duration:
            return videos.sorted { $0.duration > $1.duration }
        case .performance:
            return videos.sorted { $0.performanceScore > $1.performanceScore }
        case .alphabetical:
            return videos.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }
    
    // MARK: - Bulk Operations
    
    func bulkUpdateVisibility(videoIds: [String], visibility: VideoVisibility) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let batch = db.batch()
        
        for videoId in videoIds {
            let videoRef = db.collection("videos").document(videoId)
            batch.updateData([
                "visibility": visibility.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: videoRef)
        }
        
        try await batch.commit()
        
        // Update local cache
        for videoId in videoIds {
            if let index = videos.firstIndex(where: { $0.id == videoId }) {
                videos[index].visibility = visibility
            }
        }
        
        // Track analytics
        EnhancedAnalyticsManager.shared.logEvent("bulk_visibility_update", parameters: [
            "video_count": videoIds.count,
            "new_visibility": visibility.rawValue
        ])
        #endif
    }
    
    func bulkDelete(videoIds: [String]) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let batch = db.batch()
        
        for videoId in videoIds {
            let videoRef = db.collection("videos").document(videoId)
            batch.updateData([
                "status": VideoStatus.deleted.rawValue,
                "deletedAt": FieldValue.serverTimestamp()
            ], forDocument: videoRef)
        }
        
        try await batch.commit()
        
        // Remove from local cache
        videos.removeAll { videoIds.contains($0.id) }
        filteredVideos.removeAll { videoIds.contains($0.id) }
        
        // Track analytics
        EnhancedAnalyticsManager.shared.logEvent("bulk_delete", parameters: [
            "video_count": videoIds.count
        ])
        #endif
    }
    
    // MARK: - Search and Analytics
    
    func searchVideos(query: String) -> [EnhancedVideo] {
        guard !query.isEmpty else { return filteredVideos }
        
        let searchResults = videos.filter { video in
            video.title.localizedCaseInsensitiveContains(query) ||
            video.description.localizedCaseInsensitiveContains(query) ||
            video.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
        
        // Track search
        EnhancedAnalyticsManager.shared.logEvent("video_search", parameters: [
            "query": query,
            "result_count": searchResults.count
        ])
        
        return searchResults
    }
    
    func getVideoAnalytics(videoId: String) async throws -> VideoManagementAnalytics {
        do {
            let request = VideoAnalyticsDetailRequest(
                videoId: videoId,
                timeRange: "30d",
                includeRealtime: true
            )
            
            let response = try await performMLRequest(
                url: videoAnalyticsURL + "/detailed",
                request: request,
                responseType: VideoAnalyticsDetailResponse.self
            )
            
            return VideoManagementAnalytics(
                videoId: videoId,
                views: response.views,
                uniqueViews: response.uniqueViews,
                watchTime: response.watchTime,
                averageViewDuration: response.averageViewDuration,
                clickThroughRate: response.clickThroughRate,
                engagementRate: response.engagementRate,
                retentionCurve: response.retentionCurve,
                trafficSources: response.trafficSources,
                audienceDemographics: response.audienceDemographics,
                deviceBreakdown: response.deviceBreakdown,
                geographicData: response.geographicData,
                revenueData: response.revenueData
            )
            
        } catch {
            throw VideoManagementError.analyticsUnavailable
        }
    }
    
    // MARK: - Helper Methods
    
    private func performMLRequest<T: Codable, R: Codable>(
        url: String,
        request: T,
        responseType: R.Type
    ) async throws -> R {
        guard let requestURL = URL(string: url) else {
            throw VideoManagementError.invalidURL
        }
        
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.configured.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw VideoManagementError.serverError
        }
        
        return try JSONDecoder().decode(responseType, from: data)
    }
}

// MARK: - Supporting Types

struct EnhancedVideo: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let creatorId: String
    let creatorName: String
    let creatorAvatarURL: String
    let thumbnailURL: String
    let videoURL: String
    let duration: TimeInterval
    var visibility: VideoVisibility
    var status: VideoStatus
    let createdAt: Date
    let publishedAt: Date?
    var scheduledAt: Date?
    let viewCount: Int
    let likeCount: Int
    let dislikeCount: Int
    let commentCount: Int
    let shareCount: Int
    let watchTime: TimeInterval
    let engagementRate: Double
    let clickThroughRate: Double
    let retentionRate: Double
    let tags: [String]
    let category: String
    let language: String
    var isLive: Bool
    var isScheduled: Bool
    let monetizationEnabled: Bool
    let ageRestricted: Bool
    let copyrightClaims: [String]
    let performanceScore: Double
    let seoScore: Double
    let thumbnailOptimizationScore: Double
    var mlInsights: VideoMLInsights?
    
    // Computed properties for UI
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedViewCount: String {
        if viewCount >= 1_000_000 {
            return String(format: "%.1fM views", Double(viewCount) / 1_000_000)
        } else if viewCount >= 1_000 {
            return String(format: "%.1fK views", Double(viewCount) / 1_000)
        } else {
            return "\(viewCount) views"
        }
    }
    
    var statusColor: String {
        switch status {
        case .published: return "green"
        case .draft: return "gray"
        case .scheduled: return "blue"
        case .processing: return "orange"
        case .failed: return "red"
        case .deleted: return "red"
        }
    }
    
    var visibilityIcon: String {
        switch visibility {
        case .publicVideo: return "globe"
        case .unlisted: return "link"
        case .privateVideo: return "lock"
        }
    }
}

enum VideoManagementFilter: String, CaseIterable {
    case all = "all"
    case publicVideos = "public"
    case unlisted = "unlisted"
    case privateVideos = "private"
    case scheduled = "scheduled"
    case drafts = "drafts"
    case live = "live"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .publicVideos: return "Public"
        case .unlisted: return "Unlisted"
        case .privateVideos: return "Private"
        case .scheduled: return "Scheduled"
        case .drafts: return "Drafts"
        case .live: return "Live"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .publicVideos: return "globe"
        case .unlisted: return "link"
        case .privateVideos: return "lock"
        case .scheduled: return "calendar"
        case .drafts: return "doc"
        case .live: return "dot.radiowaves.left.and.right"
        }
    }
}

enum VideoVisibility: String, Codable, CaseIterable {
    case publicVideo = "public"
    case unlisted = "unlisted"
    case privateVideo = "private"
}

enum VideoStatus: String, Codable, CaseIterable {
    case published = "published"
    case draft = "draft"
    case scheduled = "scheduled"
    case processing = "processing"
    case failed = "failed"
    case deleted = "deleted"
}

enum VideoSortOption: String, CaseIterable {
    case uploadDate = "upload_date"
    case publishDate = "publish_date"
    case views = "views"
    case likes = "likes"
    case comments = "comments"
    case duration = "duration"
    case performance = "performance"
    case alphabetical = "alphabetical"
    
    var displayName: String {
        switch self {
        case .uploadDate: return "Upload date"
        case .publishDate: return "Publish date"
        case .views: return "Views"
        case .likes: return "Likes"
        case .comments: return "Comments"
        case .duration: return "Duration"
        case .performance: return "Performance"
        case .alphabetical: return "A-Z"
        }
    }
}

enum VideoViewMode: String, CaseIterable {
    case list = "list"
    case grid = "grid"
    case compact = "compact"
}

struct VideoMLInsights: Codable {
    let performanceScore: Double
    let seoScore: Double
    let thumbnailScore: Double
    let titleOptimization: [String]
    let descriptionOptimization: [String]
    let tagSuggestions: [String]
    let audienceRetention: [Double]
    let viralPotential: Double
    let competitorComparison: [String: Double]
    let optimizationTips: [String]
}

struct VideoManagementAnalytics: Codable {
    let videoId: String
    let views: Int
    let uniqueViews: Int
    let watchTime: TimeInterval
    let averageViewDuration: TimeInterval
    let clickThroughRate: Double
    let engagementRate: Double
    let retentionCurve: [Double]
    let trafficSources: [String: Double]
    let audienceDemographics: [String: Double]
    let deviceBreakdown: [String: Double]
    let geographicData: [String: Double]
    let revenueData: [String: Double]
}

// MARK: - ML Request/Response Types

struct VideoAnalyticsRequest: Codable {
    let videoId: String
    let creatorId: String
    let videoMetadata: VideoMLMetadata
    let performanceData: VideoPerformanceData
}

struct VideoMLMetadata: Codable {
    let title: String
    let description: String
    let tags: [String]
    let category: String
    let duration: TimeInterval
    let thumbnailURL: String
}

struct VideoPerformanceData: Codable {
    let views: Int
    let likes: Int
    let comments: Int
    let shares: Int
    let watchTime: TimeInterval
    let engagementRate: Double
}

struct VideoAnalyticsResponse: Codable {
    let performanceScore: Double
    let seoScore: Double
    let thumbnailScore: Double
    let titleOptimization: [String]
    let descriptionOptimization: [String]
    let tagSuggestions: [String]
    let audienceRetention: [Double]
    let viralPotential: Double
    let competitorComparison: [String: Double]
    let optimizationTips: [String]
}

struct VideoAnalyticsDetailRequest: Codable {
    let videoId: String
    let timeRange: String
    let includeRealtime: Bool
}

struct VideoAnalyticsDetailResponse: Codable {
    let views: Int
    let uniqueViews: Int
    let watchTime: TimeInterval
    let averageViewDuration: TimeInterval
    let clickThroughRate: Double
    let engagementRate: Double
    let retentionCurve: [Double]
    let trafficSources: [String: Double]
    let audienceDemographics: [String: Double]
    let deviceBreakdown: [String: Double]
    let geographicData: [String: Double]
    let revenueData: [String: Double]
}

// MARK: - Error Types

enum VideoManagementError: LocalizedError {
    case videoNotFound
    case firestoreUnavailable
    case invalidURL
    case serverError
    case analyticsUnavailable
    case insufficientPermissions
    
    var errorDescription: String? {
        switch self {
        case .videoNotFound:
            return "Video not found"
        case .firestoreUnavailable:
            return "Firestore is not available"
        case .invalidURL:
            return "Invalid service URL"
        case .serverError:
            return "Server error occurred"
        case .analyticsUnavailable:
            return "Analytics service unavailable"
        case .insufficientPermissions:
            return "Insufficient permissions"
        }
    }
}
