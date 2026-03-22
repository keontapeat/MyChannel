//
//  VideoAnalyticsOptimizationService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// 📊 Enterprise Video Analytics & Optimization Service
// YouTube-level video analytics with ML-powered optimization
@MainActor
class VideoAnalyticsOptimizationService: ObservableObject {
    static let shared = VideoAnalyticsOptimizationService()
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var videoAnalytics: [String: VideoAnalytics] = [:]
    @Published var optimizationSuggestions: [String: [OptimizationSuggestion]] = [:]
    
    // Performance tracking
    private let cache = NSCache<NSString, NSData>()
    
    // ML Services Integration
    private let videoInsightsURL = "https://video-insights-fkri6ifojq-uc.a.run.app"
    private let performanceAnalysisURL = "https://performance-analysis-fkri6ifojq-uc.a.run.app"
    private let audienceAnalysisURL = "https://audience-analysis-fkri6ifojq-uc.a.run.app"
    private let competitorBenchmarkURL = "https://competitor-benchmark-fkri6ifojq-uc.a.run.app"
    private let videoOptimizationURL = "https://video-optimization-fkri6ifojq-uc.a.run.app"
    private let thumbnailAnalysisURL = "https://thumbnail-analysis-fkri6ifojq-uc.a.run.app"
    private let titleAnalysisURL = "https://title-analysis-fkri6ifojq-uc.a.run.app"
    
    private init() {
        setupCache()
    }
    
    // MARK: - Configuration
    
    private func setupCache() {
        cache.countLimit = 200 // Cache analytics for 200 videos
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB cache limit
    }
    
    // MARK: - Comprehensive Video Analytics
    
    func getVideoAnalytics(videoId: String, timeRange: String = "30d") async throws -> VideoAnalytics {
        let startTime = Date()
        
        // Start performance tracking
        PerformanceMonitoringManager.shared.startTrace(name: "video_analytics", attributes: [
            "video_id": videoId,
            "time_range": timeRange
        ])
        
        defer {
            let analysisTime = Date().timeIntervalSince(startTime)
            PerformanceMonitoringManager.shared.stopTrace(name: "video_analytics", metrics: [
                "analysis_time_ms": Int64(analysisTime * 1000)
            ])
        }
        
        // Check cache first
        let cacheKey = "analytics_\(videoId)_\(timeRange)" as NSString
        if let cachedData = cache.object(forKey: cacheKey) as? Data,
           let cachedAnalytics = try? JSONDecoder().decode(VideoAnalytics.self, from: cachedData) {
            return cachedAnalytics
        }
        
        isLoading = true
        error = nil
        
        do {
            // Load comprehensive analytics from multiple sources
            async let basicAnalytics = loadBasicAnalytics(videoId: videoId, timeRange: timeRange)
            async let audienceAnalytics = loadAudienceAnalytics(videoId: videoId)
            async let performanceAnalytics = loadPerformanceAnalytics(videoId: videoId)
            async let competitorBenchmark = loadCompetitorBenchmark(videoId: videoId)
            
            let analytics = try await combineAnalytics(
                basic: basicAnalytics,
                audience: audienceAnalytics,
                performance: performanceAnalytics,
                benchmark: competitorBenchmark,
                videoId: videoId
            )
            
            // Cache results
            if let encodedData = try? JSONEncoder().encode(analytics) {
                cache.setObject(encodedData as NSData, forKey: cacheKey)
            }
            
            // Store in local state
            videoAnalytics[videoId] = analytics
            
            // Track analytics
            EnhancedAnalyticsManager.shared.logEvent("video_analytics_loaded", parameters: [
                "video_id": videoId,
                "time_range": timeRange,
                "analysis_time_ms": Date().timeIntervalSince(startTime) * 1000
            ])
            
            isLoading = false
            return analytics
            
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            
            ErrorReportingManager.shared.reportError(
                error,
                context: "VideoAnalytics",
                severity: .warning,
                metadata: ["video_id": videoId]
            )
            
            throw error
        }
    }
    
    private func loadBasicAnalytics(videoId: String, timeRange: String) async throws -> BasicVideoAnalytics {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let doc = try await db.collection("videos").document(videoId).getDocument()
        
        guard let data = doc.data() else {
            throw VideoAnalyticsError.videoNotFound
        }
        
        return BasicVideoAnalytics(
            views: data["viewCount"] as? Int ?? 0,
            uniqueViews: data["uniqueViewCount"] as? Int ?? 0,
            likes: data["likeCount"] as? Int ?? 0,
            dislikes: data["dislikeCount"] as? Int ?? 0,
            comments: data["commentCount"] as? Int ?? 0,
            shares: data["shareCount"] as? Int ?? 0,
            watchTime: data["totalWatchTime"] as? TimeInterval ?? 0,
            averageViewDuration: data["averageViewDuration"] as? TimeInterval ?? 0,
            clickThroughRate: data["clickThroughRate"] as? Double ?? 0.0,
            engagementRate: data["engagementRate"] as? Double ?? 0.0
        )
        #else
        throw VideoAnalyticsError.firestoreUnavailable
        #endif
    }
    
    private func loadAudienceAnalytics(videoId: String) async throws -> AudienceVideoAnalytics {
        let request = AudienceAnalyticsRequest(
            videoId: videoId,
            analysisType: "comprehensive"
        )
        
        let response = try await performMLRequest(
            url: audienceAnalysisURL + "/video",
            request: request,
            responseType: AudienceAnalyticsResponse.self
        )
        
        return AudienceVideoAnalytics(
            demographics: response.demographics,
            geographicData: response.geographicData,
            deviceBreakdown: response.deviceBreakdown,
            trafficSources: response.trafficSources,
            viewingPatterns: response.viewingPatterns,
            engagementBySegment: response.engagementBySegment
        )
    }
    
    private func loadPerformanceAnalytics(videoId: String) async throws -> PerformanceVideoAnalytics {
        let request = PerformanceAnalysisRequest(
            videoId: videoId,
            includeRetention: true,
            includePredictions: true
        )
        
        let response = try await performMLRequest(
            url: performanceAnalysisURL + "/video",
            request: request,
            responseType: PerformanceAnalysisResponse.self
        )
        
        return PerformanceVideoAnalytics(
            retentionCurve: response.retentionCurve,
            dropOffPoints: response.dropOffPoints,
            replaySegments: response.replaySegments,
            engagementHotspots: response.engagementHotspots,
            performanceScore: response.performanceScore,
            improvementAreas: response.improvementAreas,
            predictedPerformance: response.predictedPerformance
        )
    }
    
    private func loadCompetitorBenchmark(videoId: String) async throws -> CompetitorBenchmark {
        let request = CompetitorBenchmarkRequest(
            videoId: videoId,
            category: "general", // Would get from video metadata
            competitorCount: 10
        )
        
        let response = try await performMLRequest(
            url: competitorBenchmarkURL + "/benchmark",
            request: request,
            responseType: CompetitorBenchmarkResponse.self
        )
        
        return CompetitorBenchmark(
            categoryAverage: response.categoryAverage,
            percentileRank: response.percentileRank,
            topPerformers: response.topPerformers,
            competitiveGaps: response.competitiveGaps,
            opportunities: response.opportunities
        )
    }
    
    private func combineAnalytics(
        basic: BasicVideoAnalytics,
        audience: AudienceVideoAnalytics,
        performance: PerformanceVideoAnalytics,
        benchmark: CompetitorBenchmark,
        videoId: String
    ) async throws -> VideoAnalytics {
        return VideoAnalytics(
            videoId: videoId,
            views: basic.views,
            uniqueViews: basic.uniqueViews,
            likes: basic.likes,
            dislikes: basic.dislikes,
            comments: basic.comments,
            shares: basic.shares,
            watchTime: basic.watchTime,
            averageWatchTime: basic.averageViewDuration,
            clickThroughRate: basic.clickThroughRate,
            engagementRate: basic.engagementRate,
            revenue: 0.0, // Would calculate from monetization data
            retentionCurve: performance.retentionCurve,
            trafficSources: audience.trafficSources,
            audienceDemographics: audience.demographics,
            deviceBreakdown: audience.deviceBreakdown,
            geographicData: audience.geographicData,
            performanceScore: performance.performanceScore,
            competitorBenchmark: benchmark,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Video Optimization
    
    func getOptimizationSuggestions(videoId: String) async throws -> [OptimizationSuggestion] {
        let request = VideoOptimizationRequest(
            videoId: videoId,
            optimizationTypes: ["thumbnail", "title", "description", "tags", "timing", "engagement"]
        )
        
        let response = try await performMLRequest(
            url: videoOptimizationURL + "/suggestions",
            request: request,
            responseType: VideoOptimizationResponse.self
        )
        
        let suggestions = response.suggestions.map { suggestion in
            OptimizationSuggestion(
                type: OptimizationType(rawValue: suggestion.type) ?? .general,
                title: suggestion.title,
                description: suggestion.description,
                impact: ImpactLevel(rawValue: suggestion.impact) ?? .medium,
                effort: EffortLevel(rawValue: suggestion.effort) ?? .medium,
                expectedImprovement: suggestion.expectedImprovement,
                actionSteps: suggestion.actionSteps,
                priority: calculatePriority(impact: suggestion.impact, effort: suggestion.effort)
            )
        }
        
        // Store suggestions
        optimizationSuggestions[videoId] = suggestions
        
        // Track optimization request
        EnhancedAnalyticsManager.shared.logEvent("optimization_suggestions_generated", parameters: [
            "video_id": videoId,
            "suggestion_count": suggestions.count
        ])
        
        return suggestions
    }
    
    private func calculatePriority(impact: String, effort: String) -> Priority {
        let impactLevel = ImpactLevel(rawValue: impact) ?? .medium
        let effortLevel = EffortLevel(rawValue: effort) ?? .medium
        
        switch (impactLevel, effortLevel) {
        case (.high, .low), (.high, .medium):
            return .high
        case (.medium, .low):
            return .high
        case (.high, .high), (.medium, .medium):
            return .medium
        case (.low, .low), (.medium, .high):
            return .medium
        default:
            return .low
        }
    }
    
    // MARK: - Real-time Analytics Updates
    
    func startRealtimeAnalytics(videoId: String) async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Listen for real-time video updates
        db.collection("videos").document(videoId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let data = snapshot?.data() else { return }
                
                Task { @MainActor in
                    // Update real-time metrics
                    await self.updateRealtimeMetrics(videoId: videoId, data: data)
                }
            }
        #endif
    }
    
    private func updateRealtimeMetrics(videoId: String, data: [String: Any]) async {
        // Update monitoring dashboard with real-time data
        if let views = data["viewCount"] as? Int {
            MonitoringDashboardManager.shared.updateMetric("video_\(videoId)_views", value: Double(views))
        }
        
        if let engagement = data["engagementRate"] as? Double {
            MonitoringDashboardManager.shared.updateMetric("video_\(videoId)_engagement", value: engagement)
        }
        
        // Track real-time update
        EnhancedAnalyticsManager.shared.logEvent("video_realtime_update", parameters: [
            "video_id": videoId,
            "views": data["viewCount"] as? Int ?? 0,
            "engagement": data["engagementRate"] as? Double ?? 0.0
        ])
    }
    
    // MARK: - Helper Methods
    
    private func performMLRequest<T: Codable, R: Codable>(
        url: String,
        request: T,
        responseType: R.Type
    ) async throws -> R {
        guard let requestURL = URL(string: url) else {
            throw VideoAnalyticsError.invalidURL
        }
        
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw VideoAnalyticsError.serverError
        }
        
        return try JSONDecoder().decode(responseType, from: data)
    }
}

// MARK: - Supporting Types

struct BasicVideoAnalytics {
    let views: Int
    let uniqueViews: Int
    let likes: Int
    let dislikes: Int
    let comments: Int
    let shares: Int
    let watchTime: TimeInterval
    let averageViewDuration: TimeInterval
    let clickThroughRate: Double
    let engagementRate: Double
}

struct AudienceVideoAnalytics {
    let demographics: [String: Double]
    let geographicData: [String: Double]
    let deviceBreakdown: [String: Double]
    let trafficSources: [String: Double]
    let viewingPatterns: [String: Double]
    let engagementBySegment: [String: Double]
}

struct PerformanceVideoAnalytics {
    let retentionCurve: [Double]
    let dropOffPoints: [TimeInterval]
    let replaySegments: [TimeInterval]
    let engagementHotspots: [TimeInterval]
    let performanceScore: Double
    let improvementAreas: [String]
    let predictedPerformance: Double
}

struct CompetitorBenchmark {
    let categoryAverage: [String: Double]
    let percentileRank: Double
    let topPerformers: [String]
    let competitiveGaps: [String]
    let opportunities: [String]
}

struct OptimizationSuggestion {
    let type: OptimizationType
    let title: String
    let description: String
    let impact: ImpactLevel
    let effort: EffortLevel
    let expectedImprovement: String
    let actionSteps: [String]
    let priority: Priority
}

enum OptimizationType: String, CaseIterable {
    case thumbnail = "thumbnail"
    case title = "title"
    case description = "description"
    case tags = "tags"
    case timing = "timing"
    case engagement = "engagement"
    case seo = "seo"
    case general = "general"
}

enum ImpactLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

enum EffortLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

// MARK: - ML Request/Response Types

struct AudienceAnalyticsRequest: Codable {
    let videoId: String
    let analysisType: String
}

struct AudienceAnalyticsResponse: Codable {
    let demographics: [String: Double]
    let geographicData: [String: Double]
    let deviceBreakdown: [String: Double]
    let trafficSources: [String: Double]
    let viewingPatterns: [String: Double]
    let engagementBySegment: [String: Double]
}

struct PerformanceAnalysisRequest: Codable {
    let videoId: String
    let includeRetention: Bool
    let includePredictions: Bool
}

struct PerformanceAnalysisResponse: Codable {
    let retentionCurve: [Double]
    let dropOffPoints: [TimeInterval]
    let replaySegments: [TimeInterval]
    let engagementHotspots: [TimeInterval]
    let performanceScore: Double
    let improvementAreas: [String]
    let predictedPerformance: Double
}

struct CompetitorBenchmarkRequest: Codable {
    let videoId: String
    let category: String
    let competitorCount: Int
}

struct CompetitorBenchmarkResponse: Codable {
    let categoryAverage: [String: Double]
    let percentileRank: Double
    let topPerformers: [String]
    let competitiveGaps: [String]
    let opportunities: [String]
}

struct VideoOptimizationRequest: Codable {
    let videoId: String
    let optimizationTypes: [String]
}

struct VideoOptimizationResponse: Codable {
    let suggestions: [MLOptimizationSuggestion]
}

struct MLOptimizationSuggestion: Codable {
    let type: String
    let title: String
    let description: String
    let impact: String
    let effort: String
    let expectedImprovement: String
    let actionSteps: [String]
}

// MARK: - Error Types

enum VideoAnalyticsError: LocalizedError {
    case videoNotFound
    case firestoreUnavailable
    case invalidURL
    case serverError
    case insufficientData
    
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
        case .insufficientData:
            return "Insufficient data for analysis"
        }
    }
}
