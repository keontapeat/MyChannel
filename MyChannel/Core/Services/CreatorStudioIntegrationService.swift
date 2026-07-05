//
//  CreatorStudioIntegrationService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import SwiftUI

// 🎬 Creator Studio Integration Service
// Seamless integration layer for existing Creator Studio UI with enterprise backend
@MainActor
class CreatorStudioIntegrationService: ObservableObject {
    static let shared = CreatorStudioIntegrationService()
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var dashboardData: CreatorDashboardData?
    @Published var realtimeMetrics: StudioRealtimeMetrics = StudioRealtimeMetrics()
    
    // Backend services
    private let enhancedStudioService = EnhancedCreatorStudioService.shared
    private let monetizationService = CreatorMonetizationService.shared
    private let contentOptimizationService = CreatorContentOptimizationService.shared
    
    // Real-time monitoring
    private var metricsTimer: Timer?
    
    private init() {
        startRealtimeMonitoring()
    }
    
    // MARK: - Dashboard Integration
    
    /// Load comprehensive dashboard data for Creator Studio
    func loadDashboardData(creatorId: String) async -> CreatorDashboardData {
        isLoading = true
        error = nil
        
        do {
            // Load all dashboard components in parallel
            async let analytics = enhancedStudioService.loadCreatorAnalytics(creatorId: creatorId, timeRange: .month)
            async let revenue = monetizationService.loadEarningsData(creatorId: creatorId, timeRange: .month)
            async let contentPerformance = enhancedStudioService.analyzeContentPerformance(creatorId: creatorId, videoIds: await getRecentVideoIds(creatorId: creatorId))
            async let audienceInsights = enhancedStudioService.getAudienceInsights(creatorId: creatorId)
            
            let dashboardData = CreatorDashboardData(
                analytics: try await analytics,
                revenue: try await revenue,
                contentPerformance: try await contentPerformance,
                audienceInsights: try await audienceInsights,
                lastUpdated: Date()
            )
            
            self.dashboardData = dashboardData
            isLoading = false
            
            // Track dashboard load
            EnhancedAnalyticsManager.shared.logEvent("creator_dashboard_loaded", parameters: [
                "creator_id": creatorId,
                "components_loaded": 4,
                "enhanced_backend": true
            ])
            
            return dashboardData
            
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            
            // Return fallback data
            return CreatorDashboardData.fallback()
        }
    }
    
    /// Get real-time creator metrics for live updates
    func getRealtimeMetrics(creatorId: String) async -> StudioRealtimeMetrics {
        guard !creatorId.isEmpty else { return StudioRealtimeMetrics() }

        // Derive live metrics from REAL service data (no fabricated/random values).
        // Day-range analytics + earnings back the numbers we can source truthfully.
        let analytics = try? await enhancedStudioService.loadCreatorAnalytics(creatorId: creatorId, timeRange: .day)
        let earnings = try? await monetizationService.loadEarningsData(creatorId: creatorId, timeRange: .day)

        let metrics = StudioRealtimeMetrics(
            // No live concurrent-viewer presence source is wired here yet — report 0
            // rather than a fabricated count.
            currentViewers: 0,
            recentViews: analytics?.totalViews ?? 0,
            liveEngagement: analytics?.engagementRate ?? 0,
            revenueToday: earnings?.totalEarnings ?? 0,
            // No per-day subscriber-delta source yet — report 0 rather than fabricating.
            subscriberGrowth: 0,
            trendingVideos: analytics?.topPerformingVideos ?? [],
            lastUpdated: Date()
        )

        realtimeMetrics = metrics
        return metrics
    }
    
    // MARK: - Content Management Integration
    
    /// Analyze video performance with enterprise insights
    func analyzeVideoPerformance(videoId: String, creatorId: String) async -> VideoPerformanceInsights {
        do {
            // Get comprehensive content analysis
            let contentAnalysis = try await contentOptimizationService.analyzeContent(videoId: videoId, creatorId: creatorId)
            
            // Get performance data from enhanced service
            let performanceData = try await enhancedStudioService.analyzeContentPerformance(creatorId: creatorId, videoIds: [videoId])
            
            let insights = VideoPerformanceInsights(
                videoId: videoId,
                performanceScore: contentAnalysis.performanceScore,
                seoScore: contentAnalysis.seoScore,
                engagementScore: contentAnalysis.engagementScore,
                viralPotential: contentAnalysis.viralPotential,
                optimizationTips: contentAnalysis.improvements,
                competitorComparison: contentAnalysis.competitorComparison,
                detailedMetrics: performanceData.first,
                lastAnalyzed: Date()
            )
            
            // Track video analysis
            EnhancedAnalyticsManager.shared.logEvent("video_analyzed_in_studio", parameters: [
                "video_id": videoId,
                "creator_id": creatorId,
                "performance_score": contentAnalysis.performanceScore
            ])
            
            return insights
            
        } catch {
            return VideoPerformanceInsights.fallback(videoId: videoId)
        }
    }
    
    /// Get content optimization recommendations
    func getContentOptimizationRecommendations(creatorId: String) async -> [ContentOptimizationTip] {
        do {
            // Get personalized coaching
            let coaching = try await enhancedStudioService.getPersonalizedCoaching(creatorId: creatorId)
            
            // Get trend analysis
            let trends = try await enhancedStudioService.analyzeTrends(creatorId: creatorId, category: "general")
            
            var tips: [ContentOptimizationTip] = []
            
            // Convert coaching tips
            for tip in coaching.personalizedTips {
                tips.append(ContentOptimizationTip(
                    type: .coaching,
                    title: "Personalized Coaching",
                    description: tip,
                    priority: .medium,
                    estimatedImpact: "Moderate improvement",
                    actionSteps: ["Implement suggestion", "Monitor results"]
                ))
            }
            
            // Convert trend recommendations
            for action in trends.recommendedActions {
                tips.append(ContentOptimizationTip(
                    type: .trending,
                    title: "Trending Opportunity",
                    description: action,
                    priority: .high,
                    estimatedImpact: "High engagement potential",
                    actionSteps: ["Create trending content", "Optimize for discovery"]
                ))
            }
            
            return tips
            
        } catch {
            return []
        }
    }
    
    // MARK: - Monetization Integration
    
    /// Get monetization insights and opportunities
    func getMonetizationInsights(creatorId: String) async -> MonetizationInsights {
        do {
            // Get revenue analytics
            let revenueData = try await monetizationService.loadEarningsData(creatorId: creatorId, timeRange: .month)
            
            // Get sponsorship opportunities
            let sponsorships = try await monetizationService.findSponsorshipOpportunities(creatorId: creatorId)
            
            // Get revenue projections
            let projections = try await monetizationService.getRevenueProjections(creatorId: creatorId, timeframe: .quarter)
            
            return MonetizationInsights(
                currentRevenue: revenueData.totalEarnings,
                revenueStreams: [
                    "Ads": revenueData.adRevenue,
                    "Memberships": revenueData.membershipRevenue,
                    "Sponsorships": revenueData.sponsorshipRevenue,
                    "Merchandise": revenueData.merchandiseRevenue
                ],
                sponsorshipOpportunities: sponsorships,
                revenueProjections: projections,
                optimizationOpportunities: [],
                lastUpdated: Date()
            )
            
        } catch {
            return MonetizationInsights.fallback()
        }
    }
    
    /// Enable monetization with enterprise setup
    func enableMonetization(creatorId: String, preferences: MonetizationPreferences) async throws -> MonetizationStatus {
        return try await monetizationService.enableMonetization(creatorId: creatorId, preferences: preferences)
    }
    
    // MARK: - Analytics Integration
    
    /// Get comprehensive analytics for Creator Studio
    func getAnalyticsData(creatorId: String, timeRange: AnalyticsTimeRange) async -> CreatorAnalyticsData {
        do {
            // Get enhanced analytics
            let analytics = try await enhancedStudioService.loadCreatorAnalytics(creatorId: creatorId, timeRange: timeRange)
            
            // Get audience insights
            let audienceInsights = try await enhancedStudioService.getAudienceInsights(creatorId: creatorId)
            
            return CreatorAnalyticsData(
                totalViews: analytics.totalViews,
                totalWatchTime: analytics.totalWatchTime,
                subscriberCount: analytics.subscriberCount,
                engagementRate: analytics.engagementRate,
                revenueGenerated: analytics.revenueGenerated,
                topPerformingVideos: analytics.topPerformingVideos,
                audienceDemographics: analytics.audienceDemographics,
                trafficSources: analytics.trafficSources,
                deviceBreakdown: analytics.deviceBreakdown,
                peakViewingHours: analytics.peakViewingHours,
                growthRate: analytics.growthRate,
                retentionRate: analytics.retentionRate,
                audienceInsights: audienceInsights,
                mlInsights: analytics.mlInsights,
                timeRange: timeRange
            )
            
        } catch {
            return CreatorAnalyticsData.fallback(timeRange: timeRange)
        }
    }
    
    // MARK: - Real-time Monitoring
    
    private func startRealtimeMonitoring() {
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let creatorId = AppState.shared.currentUser?.id {
                    _ = await self.getRealtimeMetrics(creatorId: creatorId)
                }
            }
        }
    }
    
    private func stopRealtimeMonitoring() {
        metricsTimer?.invalidate()
        metricsTimer = nil
    }
    
    // MARK: - Helper Methods
    
    private func getRecentVideoIds(creatorId: String) async -> [String] {
        guard !creatorId.isEmpty else { return [] }
        // Real recent uploads from Firestore (no placeholder IDs).
        let videos = await VideoFirestoreService.shared.fetchVideosByCreator(creatorId: creatorId, limit: 10)
        return videos.map { $0.id }
    }
    
    deinit {
        metricsTimer?.invalidate()
        metricsTimer = nil
    }
}

// MARK: - Supporting Types

struct CreatorDashboardData {
    let analytics: CreatorAnalytics
    let revenue: EarningsData
    let contentPerformance: [ContentPerformanceData]
    let audienceInsights: AudienceInsights
    let lastUpdated: Date
    
    static func fallback() -> CreatorDashboardData {
        return CreatorDashboardData(
            analytics: CreatorAnalytics(
                creatorId: "unknown",
                timeRange: .month,
                totalViews: 0,
                totalWatchTime: 0,
                subscriberCount: 0,
                videoCount: 0,
                engagementRate: 0,
                averageViewDuration: 0,
                clickThroughRate: 0,
                revenueGenerated: 0,
                topPerformingVideos: [],
                audienceDemographics: [:],
                trafficSources: [:],
                deviceBreakdown: [:],
                geographicData: [:],
                peakViewingHours: [],
                contentCategories: [:],
                growthRate: 0,
                retentionRate: 0,
                mlInsights: nil
            ),
            revenue: EarningsData(
                totalEarnings: 0,
                adRevenue: 0,
                membershipRevenue: 0,
                sponsorshipRevenue: 0,
                merchandiseRevenue: 0,
                dailyEarnings: [:],
                growthRate: 0,
                projectedEarnings: 0,
                payoutSchedule: PayoutSchedule(frequency: .monthly, nextPayoutDate: Date(), minimumThreshold: 100, paymentMethod: "direct_deposit"),
                taxInformation: TaxInformation(taxId: "", taxForm: "", withholdingRate: 0, estimatedTaxOwed: 0)
            ),
            contentPerformance: [],
            audienceInsights: AudienceInsights(
                totalAudience: 0,
                demographics: [:],
                interests: [:],
                behaviorPatterns: [],
                engagementPreferences: [:],
                deviceUsage: [:],
                geographicDistribution: [:],
                viewingHabits: [:],
                loyaltyScore: 0,
                growthPotential: 0
            ),
            lastUpdated: Date()
        )
    }
}

struct StudioRealtimeMetrics {
    let currentViewers: Int
    let recentViews: Int
    let liveEngagement: Double
    let revenueToday: Double
    let subscriberGrowth: Int
    let trendingVideos: [String]
    let lastUpdated: Date
    
    init(currentViewers: Int = 0, recentViews: Int = 0, liveEngagement: Double = 0, revenueToday: Double = 0, subscriberGrowth: Int = 0, trendingVideos: [String] = [], lastUpdated: Date = Date()) {
        self.currentViewers = currentViewers
        self.recentViews = recentViews
        self.liveEngagement = liveEngagement
        self.revenueToday = revenueToday
        self.subscriberGrowth = subscriberGrowth
        self.trendingVideos = trendingVideos
        self.lastUpdated = lastUpdated
    }
}

struct VideoPerformanceInsights {
    let videoId: String
    let performanceScore: Double
    let seoScore: Double
    let engagementScore: Double
    let viralPotential: Double
    let optimizationTips: [String]
    let competitorComparison: [String: Double]
    let detailedMetrics: ContentPerformanceData?
    let lastAnalyzed: Date
    
    static func fallback(videoId: String) -> VideoPerformanceInsights {
        return VideoPerformanceInsights(
            videoId: videoId,
            performanceScore: 0,
            seoScore: 0,
            engagementScore: 0,
            viralPotential: 0,
            optimizationTips: [],
            competitorComparison: [:],
            detailedMetrics: nil,
            lastAnalyzed: Date()
        )
    }
}

struct ContentOptimizationTip {
    let type: TipType
    let title: String
    let description: String
    let priority: ContentPriority
    let estimatedImpact: String
    let actionSteps: [String]
    
    enum TipType {
        case coaching
        case trending
        case seo
        case engagement
        case monetization
    }
}

struct MonetizationInsights {
    let currentRevenue: Double
    let revenueStreams: [String: Double]
    let sponsorshipOpportunities: [MonetizationSponsorshipOpportunity]
    let revenueProjections: RevenueProjection
    let optimizationOpportunities: [String]
    let lastUpdated: Date
    
    static func fallback() -> MonetizationInsights {
        return MonetizationInsights(
            currentRevenue: 0,
            revenueStreams: [:],
            sponsorshipOpportunities: [],
            revenueProjections: RevenueProjection(
                timeframe: .quarter,
                baselineProjection: 0,
                optimisticProjection: 0,
                conservativeProjection: 0,
                monthlyBreakdown: [],
                revenueByStream: [:],
                growthFactors: [],
                risks: [],
                opportunities: [],
                confidence: 0
            ),
            optimizationOpportunities: [],
            lastUpdated: Date()
        )
    }
}

struct CreatorAnalyticsData {
    let totalViews: Int
    let totalWatchTime: TimeInterval
    let subscriberCount: Int
    let engagementRate: Double
    let revenueGenerated: Double
    let topPerformingVideos: [String]
    let audienceDemographics: [String: Double]
    let trafficSources: [String: Double]
    let deviceBreakdown: [String: Double]
    let peakViewingHours: [Int]
    let growthRate: Double
    let retentionRate: Double
    let audienceInsights: AudienceInsights
    let mlInsights: CreatorMLInsights?
    let timeRange: AnalyticsTimeRange
    
    static func fallback(timeRange: AnalyticsTimeRange) -> CreatorAnalyticsData {
        return CreatorAnalyticsData(
            totalViews: 0,
            totalWatchTime: 0,
            subscriberCount: 0,
            engagementRate: 0,
            revenueGenerated: 0,
            topPerformingVideos: [],
            audienceDemographics: [:],
            trafficSources: [:],
            deviceBreakdown: [:],
            peakViewingHours: [],
            growthRate: 0,
            retentionRate: 0,
            audienceInsights: AudienceInsights(
                totalAudience: 0,
                demographics: [:],
                interests: [:],
                behaviorPatterns: [],
                engagementPreferences: [:],
                deviceUsage: [:],
                geographicDistribution: [:],
                viewingHabits: [:],
                loyaltyScore: 0,
                growthPotential: 0
            ),
            mlInsights: nil,
            timeRange: timeRange
        )
    }
}
