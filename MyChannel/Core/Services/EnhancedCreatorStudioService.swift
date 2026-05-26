//
//  EnhancedCreatorStudioService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// 🎬 Enterprise-Grade Creator Studio Backend Service
// Industry-standard creator platform with ML integration
@MainActor
class EnhancedCreatorStudioService: ObservableObject {
    static let shared = EnhancedCreatorStudioService()
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var creatorAnalytics: CreatorAnalytics?
    @Published var contentPerformance: [ContentPerformanceData] = []
    @Published var revenueData: RevenueAnalytics?
    
    // Performance tracking
    private let cache = NSCache<NSString, NSData>()
    private var cancellables = Set<AnyCancellable>()
    
    // ML Services Integration
    private let analyticsMLURL = "https://creator-analytics-fkri6ifojq-uc.a.run.app"
    private let contentOptimizationURL = "https://content-optimization-fkri6ifojq-uc.a.run.app"
    private let audienceInsightsURL = "https://audience-insights-fkri6ifojq-uc.a.run.app"
    private let revenueOptimizationURL = "https://revenue-optimization-fkri6ifojq-uc.a.run.app"
    private let trendAnalysisURL = "https://trend-analysis-fkri6ifojq-uc.a.run.app"
    private let competitorAnalysisURL = "https://competitor-analysis-fkri6ifojq-uc.a.run.app"
    private let creatorCoachingURL = "https://creator-coaching-fkri6ifojq-uc.a.run.app"
    
    private init() {
        setupCache()
        startPerformanceTracking()
    }
    
    // MARK: - Configuration
    
    private func setupCache() {
        cache.countLimit = 1000 // Cache up to 1000 analytics items
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB cache limit
    }
    
    private func startPerformanceTracking() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            Task { @MainActor in
                self.updatePerformanceMetrics()
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        // Track creator studio performance metrics
        MonitoringDashboardManager.shared.updateMetric("creator_studio_cache_size", value: Double(cache.totalCostLimit))
        MonitoringDashboardManager.shared.updateMetric("creator_analytics_requests", value: Double(contentPerformance.count))
    }
    
    // MARK: - Creator Analytics with ML Enhancement
    
    func loadCreatorAnalytics(creatorId: String, timeRange: AnalyticsTimeRange = .month) async throws -> CreatorAnalytics {
        let startTime = Date()
        
        // Start performance tracking
        PerformanceMonitoringManager.shared.startTrace(name: "creator_analytics_load", attributes: [
            "creator_id": creatorId,
            "time_range": timeRange.rawValue
        ])
        
        // Update monitoring metrics
        MonitoringDashboardManager.shared.incrementCounter("creator_analytics_requests")
        
        defer {
            let loadTime = Date().timeIntervalSince(startTime)
            PerformanceMonitoringManager.shared.stopTrace(name: "creator_analytics_load", metrics: [
                "load_time_ms": Int64(loadTime * 1000)
            ])
            MonitoringDashboardManager.shared.recordLatency("creator_analytics_load_time", latency: loadTime)
        }
        
        // Check cache first
        let cacheKey = "creator_analytics_\(creatorId)_\(timeRange.rawValue)" as NSString
        if let cachedData = cache.object(forKey: cacheKey) as? Data,
           let cachedAnalytics = try? JSONDecoder().decode(CreatorAnalytics.self, from: cachedData) {
            
            EnhancedAnalyticsManager.shared.logEvent("creator_analytics_cache_hit", parameters: [
                "creator_id": creatorId,
                "time_range": timeRange.rawValue
            ])
            
            return cachedAnalytics
        }
        
        isLoading = true
        error = nil
        
        do {
            // Load basic analytics from Firestore
            let basicAnalytics = try await loadBasicAnalytics(creatorId: creatorId, timeRange: timeRange)
            
            // Enhance with ML insights
            let enhancedAnalytics = await enhanceAnalyticsWithML(basicAnalytics, creatorId: creatorId)
            
            // Cache results
            if let encodedData = try? JSONEncoder().encode(enhancedAnalytics) {
                cache.setObject(encodedData as NSData, forKey: cacheKey)
            }
            
            // Track analytics
            EnhancedAnalyticsManager.shared.logEvent("creator_analytics_loaded", parameters: [
                "creator_id": creatorId,
                "time_range": timeRange.rawValue,
                "load_time_ms": Date().timeIntervalSince(startTime) * 1000,
                "enhanced": true
            ])
            
            creatorAnalytics = enhancedAnalytics
            isLoading = false
            return enhancedAnalytics
            
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            
            // Report error
            ErrorReportingManager.shared.reportError(
                error,
                context: "CreatorAnalyticsLoad",
                severity: .warning,
                metadata: [
                    "creator_id": creatorId,
                    "time_range": timeRange.rawValue
                ]
            )
            
            MonitoringDashboardManager.shared.incrementCounter("creator_analytics_errors")
            throw error
        }
    }
    
    private func loadBasicAnalytics(creatorId: String, timeRange: AnalyticsTimeRange) async throws -> CreatorAnalytics {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Calculate date range
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: timeRange.calendarComponent, value: -timeRange.value, to: endDate) ?? endDate
        
        // Load creator's videos
        let videosSnapshot = try await db.collection("videos")
            .whereField("creatorId", isEqualTo: creatorId)
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("createdAt", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments()
        
        var totalViews = 0
        var totalWatchTime: TimeInterval = 0
        var totalLikes = 0
        var totalComments = 0
        var totalShares = 0
        var videoCount = videosSnapshot.documents.count
        
        for doc in videosSnapshot.documents {
            let data = doc.data()
            totalViews += data["viewCount"] as? Int ?? 0
            totalWatchTime += data["totalWatchTime"] as? TimeInterval ?? 0
            totalLikes += data["likeCount"] as? Int ?? 0
            totalComments += data["commentCount"] as? Int ?? 0
            totalShares += data["shareCount"] as? Int ?? 0
        }
        
        // Load subscriber data
        let subscriberDoc = try await db.collection("users").document(creatorId).getDocument()
        let subscriberCount = subscriberDoc.data()?["subscriberCount"] as? Int ?? 0
        
        // Calculate engagement rate
        let engagementRate = totalViews > 0 ? Double(totalLikes + totalComments + totalShares) / Double(totalViews) : 0.0
        
        return CreatorAnalytics(
            creatorId: creatorId,
            timeRange: timeRange,
            totalViews: totalViews,
            totalWatchTime: totalWatchTime,
            subscriberCount: subscriberCount,
            videoCount: videoCount,
            engagementRate: engagementRate,
            averageViewDuration: totalViews > 0 ? totalWatchTime / Double(totalViews) : 0,
            clickThroughRate: 0.0, // Would calculate from impression data
            revenueGenerated: 0.0, // Would calculate from monetization data
            topPerformingVideos: [],
            audienceDemographics: [:],
            trafficSources: [:],
            deviceBreakdown: [:],
            geographicData: [:],
            peakViewingHours: [],
            contentCategories: [:],
            growthRate: 0.0,
            retentionRate: 0.0,
            mlInsights: nil
        )
        #else
        throw CreatorStudioError.firestoreUnavailable
        #endif
    }
    
    private func enhanceAnalyticsWithML(_ analytics: CreatorAnalytics, creatorId: String) async -> CreatorAnalytics {
        do {
            let request = CreatorAnalyticsMLRequest(
                creatorId: creatorId,
                basicAnalytics: analytics,
                timeRange: analytics.timeRange.rawValue
            )
            
            let response = try await performMLRequest(
                url: analyticsMLURL + "/enhance",
                request: request,
                responseType: CreatorAnalyticsMLResponse.self
            )
            
            // Create enhanced analytics with ML insights
            var enhancedAnalytics = analytics
            enhancedAnalytics.mlInsights = CreatorMLInsights(
                predictedGrowth: response.predictedGrowth,
                contentRecommendations: response.contentRecommendations,
                audienceInsights: response.audienceInsights,
                optimizationTips: response.optimizationTips,
                competitorComparison: response.competitorComparison,
                trendingTopics: response.trendingTopics,
                bestUploadTimes: response.bestUploadTimes,
                thumbnailOptimization: response.thumbnailOptimization
            )
            
            return enhancedAnalytics
            
        } catch {
            ErrorReportingManager.shared.reportMLServiceError(
                serviceName: "creator_analytics",
                error: error,
                requestData: ["creator_id": creatorId],
                responseTime: 0
            )
            return analytics
        }
    }
    
    // MARK: - Content Performance Analysis
    
    func analyzeContentPerformance(creatorId: String, videoIds: [String]) async throws -> [ContentPerformanceData] {
        let startTime = Date()
        
        do {
            let request = ContentPerformanceRequest(
                creatorId: creatorId,
                videoIds: videoIds,
                analysisType: "comprehensive"
            )
            
            let response = try await performMLRequest(
                url: contentOptimizationURL + "/analyze",
                request: request,
                responseType: ContentPerformanceResponse.self
            )
            
            let performanceData = response.videoAnalytics.map { videoData in
                ContentPerformanceData(
                    videoId: videoData.videoId,
                    title: videoData.title,
                    views: videoData.views,
                    watchTime: videoData.watchTime,
                    engagementRate: videoData.engagementRate,
                    clickThroughRate: videoData.clickThroughRate,
                    retentionCurve: videoData.retentionCurve,
                    audienceRetention: videoData.audienceRetention,
                    trafficSources: videoData.trafficSources,
                    performanceScore: videoData.performanceScore,
                    optimizationSuggestions: videoData.optimizationSuggestions,
                    predictedPerformance: videoData.predictedPerformance
                )
            }
            
            // Track analytics
            let loadTime = Date().timeIntervalSince(startTime)
            EnhancedAnalyticsManager.shared.logEvent("content_performance_analyzed", parameters: [
                "creator_id": creatorId,
                "video_count": videoIds.count,
                "analysis_time_ms": loadTime * 1000
            ])
            
            contentPerformance = performanceData
            return performanceData
            
        } catch {
            ErrorReportingManager.shared.reportError(
                error,
                context: "ContentPerformanceAnalysis",
                severity: .warning,
                metadata: [
                    "creator_id": creatorId,
                    "video_count": videoIds.count
                ]
            )
            throw error
        }
    }
    
    // MARK: - Revenue Analytics
    
    func loadRevenueAnalytics(creatorId: String, timeRange: AnalyticsTimeRange) async throws -> RevenueAnalytics {
        do {
            let request = RevenueAnalyticsRequest(
                creatorId: creatorId,
                timeRange: timeRange.rawValue,
                includeProjections: true
            )
            
            let response = try await performMLRequest(
                url: revenueOptimizationURL + "/analytics",
                request: request,
                responseType: RevenueAnalyticsResponse.self
            )
            
            let revenueAnalytics = RevenueAnalytics(
                totalRevenue: response.totalRevenue,
                adRevenue: response.adRevenue,
                membershipRevenue: response.membershipRevenue,
                merchandiseRevenue: response.merchandiseRevenue,
                sponsorshipRevenue: response.sponsorshipRevenue,
                revenueBySource: response.revenueBySource,
                monthlyProjections: response.monthlyProjections,
                revenuePerView: response.revenuePerView,
                topEarningVideos: response.topEarningVideos,
                optimizationOpportunities: response.optimizationOpportunities
            )
            
            // Track analytics
            EnhancedAnalyticsManager.shared.logEvent("revenue_analytics_loaded", parameters: [
                "creator_id": creatorId,
                "time_range": timeRange.rawValue,
                "total_revenue": response.totalRevenue
            ])
            
            revenueData = revenueAnalytics
            return revenueAnalytics
            
        } catch {
            ErrorReportingManager.shared.reportError(
                error,
                context: "RevenueAnalyticsLoad",
                severity: .warning,
                metadata: ["creator_id": creatorId]
            )
            throw error
        }
    }
    
    // MARK: - Audience Insights
    
    func getAudienceInsights(creatorId: String) async throws -> AudienceInsights {
        let request = AudienceInsightsRequest(
            creatorId: creatorId,
            analysisDepth: "comprehensive"
        )
        
        let response = try await performMLRequest(
            url: audienceInsightsURL + "/analyze",
            request: request,
            responseType: AudienceInsightsResponse.self
        )
        
        return AudienceInsights(
            totalAudience: response.totalAudience,
            demographics: response.demographics,
            interests: response.interests,
            behaviorPatterns: response.behaviorPatterns,
            engagementPreferences: response.engagementPreferences,
            deviceUsage: response.deviceUsage,
            geographicDistribution: response.geographicDistribution,
            viewingHabits: response.viewingHabits,
            loyaltyScore: response.loyaltyScore,
            growthPotential: response.growthPotential
        )
    }
    
    // MARK: - Trend Analysis
    
    func analyzeTrends(creatorId: String, category: String) async throws -> TrendAnalysis {
        let request = TrendAnalysisRequest(
            creatorId: creatorId,
            category: category,
            timeframe: "30d"
        )
        
        let response = try await performMLRequest(
            url: trendAnalysisURL + "/analyze",
            request: request,
            responseType: TrendAnalysisResponse.self
        )
        
        return TrendAnalysis(
            trendingTopics: response.trendingTopics,
            emergingTrends: response.emergingTrends,
            seasonalPatterns: response.seasonalPatterns,
            competitorTrends: response.competitorTrends,
            opportunityScore: response.opportunityScore,
            recommendedActions: response.recommendedActions
        )
    }
    
    // MARK: - Creator Coaching
    
    func getPersonalizedCoaching(creatorId: String) async throws -> CreatorCoaching {
        let request = CreatorCoachingRequest(
            creatorId: creatorId,
            currentLevel: "intermediate", // Would determine from analytics
            goals: ["growth", "monetization", "engagement"]
        )
        
        let response = try await performMLRequest(
            url: creatorCoachingURL + "/coach",
            request: request,
            responseType: CreatorCoachingResponse.self
        )
        
        return CreatorCoaching(
            personalizedTips: response.personalizedTips,
            skillAssessment: response.skillAssessment,
            improvementAreas: response.improvementAreas,
            actionPlan: response.actionPlan,
            milestones: response.milestones,
            resources: response.resources,
            mentorRecommendations: response.mentorRecommendations
        )
    }
    
    // MARK: - Real-time Monitoring
    
    func startRealtimeMonitoring(creatorId: String) async {
        // Set up real-time listeners for creator metrics
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Listen for video performance updates
        db.collection("videos")
            .whereField("creatorId", isEqualTo: creatorId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    // Update content performance in real-time
                    await self.updateRealtimeMetrics(from: documents)
                }
            }
        
        // Listen for subscriber changes
        db.collection("users").document(creatorId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let data = snapshot?.data() else { return }
                
                Task { @MainActor in
                    // Update subscriber count in real-time
                    if let subscriberCount = data["subscriberCount"] as? Int {
                        await self.updateSubscriberCount(subscriberCount)
                    }
                }
            }
        #endif
    }
    
    private func updateRealtimeMetrics(from documents: [DocumentSnapshot]) async {
        // Process real-time video performance updates
        var totalViews = 0
        var totalEngagement = 0
        
        for doc in documents {
            guard let data = doc.data() else { continue }
            totalViews += data["viewCount"] as? Int ?? 0
            totalEngagement += (data["likeCount"] as? Int ?? 0) + (data["commentCount"] as? Int ?? 0)
        }
        
        // Update monitoring dashboard
        MonitoringDashboardManager.shared.updateMetric("creator_total_views", value: Double(totalViews))
        MonitoringDashboardManager.shared.updateMetric("creator_total_engagement", value: Double(totalEngagement))
    }
    
    private func updateSubscriberCount(_ count: Int) async {
        MonitoringDashboardManager.shared.updateMetric("creator_subscriber_count", value: Double(count))
    }
    
    // MARK: - Helper Methods
    
    private func performMLRequest<T: Codable, R: Codable>(
        url: String,
        request: T,
        responseType: R.Type
    ) async throws -> R {
        guard let requestURL = URL(string: url) else {
            throw CreatorStudioError.invalidURL
        }
        
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.configured.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw CreatorStudioError.serverError
        }
        
        return try JSONDecoder().decode(responseType, from: data)
    }
}

// MARK: - Supporting Types

struct CreatorAnalytics: Codable {
    let creatorId: String
    let timeRange: AnalyticsTimeRange
    let totalViews: Int
    let totalWatchTime: TimeInterval
    let subscriberCount: Int
    let videoCount: Int
    let engagementRate: Double
    let averageViewDuration: TimeInterval
    let clickThroughRate: Double
    let revenueGenerated: Double
    let topPerformingVideos: [String]
    let audienceDemographics: [String: Double]
    let trafficSources: [String: Double]
    let deviceBreakdown: [String: Double]
    let geographicData: [String: Double]
    let peakViewingHours: [Int]
    let contentCategories: [String: Double]
    let growthRate: Double
    let retentionRate: Double
    var mlInsights: CreatorMLInsights?
}

struct CreatorMLInsights: Codable {
    let predictedGrowth: Double
    let contentRecommendations: [String]
    let audienceInsights: [String]
    let optimizationTips: [String]
    let competitorComparison: [String: Double]
    let trendingTopics: [String]
    let bestUploadTimes: [String]
    let thumbnailOptimization: [String]
}

enum AnalyticsTimeRange: String, CaseIterable, Codable {
    case day = "1d"
    case week = "7d"
    case month = "30d"
    case quarter = "90d"
    case year = "365d"
    
    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .day
        case .month: return .day
        case .quarter: return .day
        case .year: return .day
        }
    }
    
    var value: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
}

struct ContentPerformanceData: Codable {
    let videoId: String
    let title: String
    let views: Int
    let watchTime: TimeInterval
    let engagementRate: Double
    let clickThroughRate: Double
    let retentionCurve: [Double]
    let audienceRetention: Double
    let trafficSources: [String: Double]
    let performanceScore: Double
    let optimizationSuggestions: [String]
    let predictedPerformance: Double
}

struct RevenueAnalytics: Codable {
    let totalRevenue: Double
    let adRevenue: Double
    let membershipRevenue: Double
    let merchandiseRevenue: Double
    let sponsorshipRevenue: Double
    let revenueBySource: [String: Double]
    let monthlyProjections: [Double]
    let revenuePerView: Double
    let topEarningVideos: [String]
    let optimizationOpportunities: [String]
}

struct AudienceInsights: Codable {
    let totalAudience: Int
    let demographics: [String: Double]
    let interests: [String: Double]
    let behaviorPatterns: [String]
    let engagementPreferences: [String: Double]
    let deviceUsage: [String: Double]
    let geographicDistribution: [String: Double]
    let viewingHabits: [String: Double]
    let loyaltyScore: Double
    let growthPotential: Double
}

struct TrendAnalysis: Codable {
    let trendingTopics: [String]
    let emergingTrends: [String]
    let seasonalPatterns: [String: Double]
    let competitorTrends: [String]
    let opportunityScore: Double
    let recommendedActions: [String]
}

struct CreatorCoaching: Codable {
    let personalizedTips: [String]
    let skillAssessment: [String: Double]
    let improvementAreas: [String]
    let actionPlan: [String]
    let milestones: [String]
    let resources: [String]
    let mentorRecommendations: [String]
}

// MARK: - ML Request/Response Types

struct CreatorAnalyticsMLRequest: Codable {
    let creatorId: String
    let basicAnalytics: CreatorAnalytics
    let timeRange: String
}

struct CreatorAnalyticsMLResponse: Codable {
    let predictedGrowth: Double
    let contentRecommendations: [String]
    let audienceInsights: [String]
    let optimizationTips: [String]
    let competitorComparison: [String: Double]
    let trendingTopics: [String]
    let bestUploadTimes: [String]
    let thumbnailOptimization: [String]
}

struct ContentPerformanceRequest: Codable {
    let creatorId: String
    let videoIds: [String]
    let analysisType: String
}

struct ContentPerformanceResponse: Codable {
    let videoAnalytics: [VideoAnalyticsData]
}

struct VideoAnalyticsData: Codable {
    let videoId: String
    let title: String
    let views: Int
    let watchTime: TimeInterval
    let engagementRate: Double
    let clickThroughRate: Double
    let retentionCurve: [Double]
    let audienceRetention: Double
    let trafficSources: [String: Double]
    let performanceScore: Double
    let optimizationSuggestions: [String]
    let predictedPerformance: Double
}

struct RevenueAnalyticsRequest: Codable {
    let creatorId: String
    let timeRange: String
    let includeProjections: Bool
}

struct RevenueAnalyticsResponse: Codable {
    let totalRevenue: Double
    let adRevenue: Double
    let membershipRevenue: Double
    let merchandiseRevenue: Double
    let sponsorshipRevenue: Double
    let revenueBySource: [String: Double]
    let monthlyProjections: [Double]
    let revenuePerView: Double
    let topEarningVideos: [String]
    let optimizationOpportunities: [String]
}

struct AudienceInsightsRequest: Codable {
    let creatorId: String
    let analysisDepth: String
}

struct AudienceInsightsResponse: Codable {
    let totalAudience: Int
    let demographics: [String: Double]
    let interests: [String: Double]
    let behaviorPatterns: [String]
    let engagementPreferences: [String: Double]
    let deviceUsage: [String: Double]
    let geographicDistribution: [String: Double]
    let viewingHabits: [String: Double]
    let loyaltyScore: Double
    let growthPotential: Double
}

struct TrendAnalysisRequest: Codable {
    let creatorId: String
    let category: String
    let timeframe: String
}

struct TrendAnalysisResponse: Codable {
    let trendingTopics: [String]
    let emergingTrends: [String]
    let seasonalPatterns: [String: Double]
    let competitorTrends: [String]
    let opportunityScore: Double
    let recommendedActions: [String]
}

struct CreatorCoachingRequest: Codable {
    let creatorId: String
    let currentLevel: String
    let goals: [String]
}

struct CreatorCoachingResponse: Codable {
    let personalizedTips: [String]
    let skillAssessment: [String: Double]
    let improvementAreas: [String]
    let actionPlan: [String]
    let milestones: [String]
    let resources: [String]
    let mentorRecommendations: [String]
}

// MARK: - Error Types

enum CreatorStudioError: LocalizedError {
    case firestoreUnavailable
    case invalidURL
    case serverError
    case dataCorruption
    
    var errorDescription: String? {
        switch self {
        case .firestoreUnavailable:
            return "Firestore is not available"
        case .invalidURL:
            return "Invalid service URL"
        case .serverError:
            return "Server error occurred"
        case .dataCorruption:
            return "Data corruption detected"
        }
    }
}
