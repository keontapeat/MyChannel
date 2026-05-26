//
//  CreatorContentOptimizationService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// 🎯 Enterprise Creator Content Optimization Service
// Industry-standard content optimization with AI-powered insights
@MainActor
class CreatorContentOptimizationService: ObservableObject {
    static let shared = CreatorContentOptimizationService()
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var contentInsights: [ContentInsight] = []
    @Published var optimizationRecommendations: [OptimizationRecommendation] = []
    
    // ML Services Integration
    private let contentAnalysisURL = "https://content-analysis-fkri6ifojq-uc.a.run.app"
    private let thumbnailOptimizationURL = "https://thumbnail-optimization-fkri6ifojq-uc.a.run.app"
    private let titleOptimizationURL = "https://title-optimization-fkri6ifojq-uc.a.run.app"
    private let seoOptimizationURL = "https://seo-optimization-fkri6ifojq-uc.a.run.app"
    private let viralPredictionURL = "https://viral-prediction-fkri6ifojq-uc.a.run.app"
    private let competitorAnalysisURL = "https://competitor-analysis-fkri6ifojq-uc.a.run.app"
    private let contentStrategyURL = "https://content-strategy-fkri6ifojq-uc.a.run.app"
    
    private init() {}
    
    // MARK: - Content Analysis
    
    func analyzeContent(videoId: String, creatorId: String) async throws -> ContentAnalysisResult {
        let startTime = Date()
        
        // Track content analysis
        PerformanceMonitoringManager.shared.startTrace(name: "content_analysis", attributes: [
            "video_id": videoId,
            "creator_id": creatorId
        ])
        
        defer {
            let analysisTime = Date().timeIntervalSince(startTime)
            PerformanceMonitoringManager.shared.stopTrace(name: "content_analysis", metrics: [
                "analysis_time_ms": Int64(analysisTime * 1000)
            ])
        }
        
        isLoading = true
        error = nil
        
        do {
            // Get video data from Firestore
            let videoData = try await getVideoData(videoId: videoId)
            
            // Perform comprehensive content analysis
            let analysisRequest = ContentAnalysisRequest(
                videoId: videoId,
                creatorId: creatorId,
                videoData: videoData,
                analysisTypes: ["performance", "seo", "engagement", "viral_potential", "audience_match"]
            )
            
            let analysisResponse = try await performMLRequest(
                url: contentAnalysisURL + "/analyze",
                request: analysisRequest,
                responseType: ContentAnalysisResponse.self
            )
            
            let result = ContentAnalysisResult(
                videoId: videoId,
                performanceScore: analysisResponse.performanceScore,
                seoScore: analysisResponse.seoScore,
                engagementScore: analysisResponse.engagementScore,
                viralPotential: analysisResponse.viralPotential,
                audienceMatch: analysisResponse.audienceMatch,
                strengths: analysisResponse.strengths,
                weaknesses: analysisResponse.weaknesses,
                improvements: analysisResponse.improvements,
                competitorComparison: analysisResponse.competitorComparison,
                trendAlignment: analysisResponse.trendAlignment
            )
            
            // Track successful analysis
            EnhancedAnalyticsManager.shared.logEvent("content_analyzed", parameters: [
                "video_id": videoId,
                "creator_id": creatorId,
                "performance_score": analysisResponse.performanceScore,
                "analysis_time_ms": Date().timeIntervalSince(startTime) * 1000
            ])
            
            isLoading = false
            return result
            
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            
            ErrorReportingManager.shared.reportError(
                error,
                context: "ContentAnalysis",
                severity: .warning,
                metadata: [
                    "video_id": videoId,
                    "creator_id": creatorId
                ]
            )
            
            throw error
        }
    }
    
    // MARK: - Thumbnail Optimization
    
    func optimizeThumbnail(videoId: String, currentThumbnailURL: String, videoMetadata: ContentOptimizationVideoMetadata) async throws -> ThumbnailOptimizationResult {
        let request = ThumbnailOptimizationRequest(
            videoId: videoId,
            currentThumbnailURL: currentThumbnailURL,
            videoTitle: videoMetadata.title,
            videoCategory: videoMetadata.category,
            targetAudience: videoMetadata.targetAudience,
            competitorThumbnails: await getCompetitorThumbnails(category: videoMetadata.category)
        )
        
        let response = try await performMLRequest(
            url: thumbnailOptimizationURL + "/optimize",
            request: request,
            responseType: ThumbnailOptimizationResponse.self
        )
        
        return ThumbnailOptimizationResult(
            currentScore: response.currentScore,
            optimizedThumbnails: response.optimizedThumbnails.map { thumbnail in
                OptimizedThumbnail(
                    url: thumbnail.url,
                    score: thumbnail.score,
                    improvements: thumbnail.improvements,
                    designElements: thumbnail.designElements,
                    colorPalette: thumbnail.colorPalette,
                    textOverlay: thumbnail.textOverlay,
                    emotionalImpact: thumbnail.emotionalImpact
                )
            },
            recommendations: response.recommendations,
            abTestSuggestions: response.abTestSuggestions
        )
    }
    
    // MARK: - Title Optimization
    
    func optimizeTitle(currentTitle: String, videoMetadata: ContentOptimizationVideoMetadata, targetKeywords: [String]) async throws -> TitleOptimizationResult {
        let request = TitleOptimizationRequest(
            currentTitle: currentTitle,
            videoCategory: videoMetadata.category,
            targetKeywords: targetKeywords,
            audienceData: await getAudienceData(creatorId: videoMetadata.creatorId),
            competitorTitles: await getCompetitorTitles(category: videoMetadata.category),
            trendingTopics: await getTrendingTopics(category: videoMetadata.category)
        )
        
        let response = try await performMLRequest(
            url: titleOptimizationURL + "/optimize",
            request: request,
            responseType: TitleOptimizationResponse.self
        )
        
        return TitleOptimizationResult(
            currentScore: response.currentScore,
            optimizedTitles: response.optimizedTitles.map { title in
                OptimizedTitle(
                    title: title.title,
                    score: title.score,
                    seoScore: title.seoScore,
                    engagementScore: title.engagementScore,
                    clickThroughRate: title.predictedCTR,
                    keywords: title.keywords,
                    emotionalTriggers: title.emotionalTriggers,
                    lengthOptimization: title.lengthOptimization
                )
            },
            keywordSuggestions: response.keywordSuggestions,
            trendingElements: response.trendingElements
        )
    }
    
    // MARK: - SEO Optimization
    
    func optimizeSEO(videoId: String, videoMetadata: ContentOptimizationVideoMetadata) async throws -> SEOOptimizationResult {
        let request = SEOOptimizationRequest(
            videoId: videoId,
            title: videoMetadata.title,
            description: videoMetadata.description,
            tags: videoMetadata.tags,
            category: videoMetadata.category,
            targetKeywords: videoMetadata.targetKeywords,
            competitorAnalysis: await getCompetitorSEOData(category: videoMetadata.category)
        )
        
        let response = try await performMLRequest(
            url: seoOptimizationURL + "/optimize",
            request: request,
            responseType: SEOOptimizationResponse.self
        )
        
        return SEOOptimizationResult(
            currentSEOScore: response.currentSEOScore,
            optimizedTitle: response.optimizedTitle,
            optimizedDescription: response.optimizedDescription,
            recommendedTags: response.recommendedTags,
            keywordDensity: response.keywordDensity,
            competitorGaps: response.competitorGaps,
            searchRankingPotential: response.searchRankingPotential,
            optimizationSteps: response.optimizationSteps
        )
    }
    
    // MARK: - Viral Prediction
    
    func predictViralPotential(videoMetadata: ContentOptimizationVideoMetadata, creatorMetrics: CreatorMetrics) async throws -> ContentViralPredictionResult {
        let request = ContentViralPredictionRequest(
            videoMetadata: videoMetadata,
            creatorMetrics: creatorMetrics,
            trendingFactors: await getTrendingFactors(),
            historicalData: await getHistoricalViralData(creatorId: videoMetadata.creatorId),
            socialSignals: await getSocialSignals(videoId: videoMetadata.videoId)
        )
        
        let response = try await performMLRequest(
            url: viralPredictionURL + "/predict",
            request: request,
            responseType: ContentViralPredictionResponse.self
        )
        
        return ContentViralPredictionResult(
            viralScore: response.viralScore,
            probability: response.probability,
            predictedViews: response.predictedViews,
            timeToViral: response.timeToViral,
            viralFactors: response.viralFactors,
            boostingStrategies: response.boostingStrategies,
            optimalReleaseTime: response.optimalReleaseTime,
            crossPlatformPotential: response.crossPlatformPotential
        )
    }
    
    // MARK: - Content Strategy
    
    func generateContentStrategy(creatorId: String, goals: [ContentGoal], timeframe: StrategyTimeframe) async throws -> CreatorContentStrategy {
        let request = ContentStrategyRequest(
            creatorId: creatorId,
            goals: goals.map { $0.rawValue },
            timeframe: timeframe.rawValue,
            audienceData: await getAudienceData(creatorId: creatorId),
            performanceHistory: await getPerformanceHistory(creatorId: creatorId),
            competitorAnalysis: await getCompetitorStrategy(creatorId: creatorId),
            trendingTopics: await getTrendingTopics(category: "general")
        )
        
        let response = try await performMLRequest(
            url: contentStrategyURL + "/generate",
            request: request,
            responseType: ContentStrategyResponse.self
        )
        
        return CreatorContentStrategy(
            timeframe: timeframe,
            contentPillars: response.contentPillars,
            uploadSchedule: response.uploadSchedule,
            contentTypes: response.contentTypes,
            topicRecommendations: response.topicRecommendations,
            collaborationOpportunities: response.collaborationOpportunities,
            seasonalContent: response.seasonalContent,
            performanceTargets: response.performanceTargets,
            budgetAllocation: response.budgetAllocation,
            riskFactors: response.riskFactors
        )
    }
    
    // MARK: - Competitor Analysis
    
    func analyzeCompetitors(creatorId: String, category: String) async throws -> CompetitorAnalysisResult {
        let request = CompetitorAnalysisRequest(
            creatorId: creatorId,
            category: category,
            analysisDepth: "comprehensive",
            competitorCount: 10,
            metrics: ["views", "engagement", "growth", "content_strategy", "monetization"]
        )
        
        let response = try await performMLRequest(
            url: competitorAnalysisURL + "/analyze",
            request: request,
            responseType: CompetitorAnalysisResponse.self
        )
        
        return CompetitorAnalysisResult(
            competitors: response.competitors.map { competitor in
                CompetitorProfile(
                    id: competitor.id,
                    name: competitor.name,
                    subscriberCount: competitor.subscriberCount,
                    avgViews: competitor.avgViews,
                    engagementRate: competitor.engagementRate,
                    uploadFrequency: competitor.uploadFrequency,
                    contentStrategy: competitor.contentStrategy,
                    strengths: competitor.strengths,
                    weaknesses: competitor.weaknesses,
                    opportunities: competitor.opportunities
                )
            },
            marketPosition: response.marketPosition,
            competitiveAdvantages: response.competitiveAdvantages,
            threats: response.threats,
            recommendations: response.recommendations,
            benchmarks: response.benchmarks
        )
    }
    
    // MARK: - Performance Optimization
    
    func optimizePerformance(videoId: String, currentMetrics: ContentVideoMetrics) async throws -> PerformanceOptimizationResult {
        // Analyze current performance bottlenecks
        let bottlenecks = analyzePerformanceBottlenecks(metrics: currentMetrics)
        
        // Generate optimization recommendations
        let recommendations = await generateOptimizationRecommendations(
            videoId: videoId,
            bottlenecks: bottlenecks,
            currentMetrics: currentMetrics
        )
        
        return PerformanceOptimizationResult(
            currentPerformance: currentMetrics,
            bottlenecks: bottlenecks,
            recommendations: recommendations,
            expectedImprovements: await calculateExpectedImprovements(recommendations: recommendations),
            implementationPriority: await prioritizeImplementation(recommendations: recommendations),
            timeline: await generateImplementationTimeline(recommendations: recommendations)
        )
    }
    
    // MARK: - Helper Methods
    
    private func performMLRequest<T: Encodable, R: Decodable>(
        url: String,
        request: T,
        responseType: R.Type
    ) async throws -> R {
        guard let requestURL = URL(string: url) else {
            throw ContentOptimizationError.invalidURL
        }
        
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.configured.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw ContentOptimizationError.serverError
        }
        
        return try JSONDecoder().decode(responseType, from: data)
    }
    
    private func getVideoData(videoId: String) async throws -> [String: Any] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let doc = try await db.collection("videos").document(videoId).getDocument()
        return doc.data() ?? [:]
        #else
        return [:]
        #endif
    }
    
    private func getAudienceData(creatorId: String) async -> [String: Any] {
        return [
            "demographics": ["18-24": 0.3, "25-34": 0.4, "35-44": 0.2, "45+": 0.1],
            "interests": ["technology": 0.6, "gaming": 0.4, "lifestyle": 0.3],
            "engagement_patterns": ["morning": 0.2, "afternoon": 0.3, "evening": 0.5]
        ]
    }
    
    private func getCompetitorThumbnails(category: String) async -> [String] {
        return ["https://example.com/thumb1.jpg", "https://example.com/thumb2.jpg"]
    }
    
    private func getCompetitorTitles(category: String) async -> [String] {
        return ["Amazing Tech Review!", "Best Gaming Setup 2024", "Ultimate Guide to Success"]
    }
    
    private func getTrendingTopics(category: String) async -> [String] {
        return ["AI", "Machine Learning", "Productivity", "Tech Reviews"]
    }
    
    private func getCompetitorSEOData(category: String) async -> [String: Any] {
        return [
            "top_keywords": ["tech", "review", "tutorial", "guide"],
            "avg_title_length": 45,
            "common_tags": ["technology", "review", "2024"]
        ]
    }
    
    private func getTrendingFactors() async -> [String: Double] {
        return [
            "social_media_buzz": 0.8,
            "search_volume": 0.6,
            "competitor_activity": 0.4
        ]
    }
    
    private func getHistoricalViralData(creatorId: String) async -> [String: Any] {
        return [
            "viral_videos": 3,
            "avg_viral_views": 1000000,
            "viral_factors": ["timing", "trending_topic", "thumbnail"]
        ]
    }
    
    private func getSocialSignals(videoId: String) async -> [String: Any] {
        return [
            "shares": 150,
            "mentions": 45,
            "hashtag_usage": 12
        ]
    }
    
    private func getPerformanceHistory(creatorId: String) async -> [String: Any] {
        return [
            "avg_views": 50000,
            "avg_engagement": 0.08,
            "growth_rate": 0.15
        ]
    }
    
    private func getCompetitorStrategy(creatorId: String) async -> [String: Any] {
        return [
            "upload_frequency": "3x/week",
            "content_types": ["tutorials", "reviews", "vlogs"],
            "trending_topics": ["AI", "productivity"]
        ]
    }
    
    private func analyzePerformanceBottlenecks(metrics: ContentVideoMetrics) -> [PerformanceBottleneck] {
        var bottlenecks: [PerformanceBottleneck] = []
        
        if metrics.clickThroughRate < 0.05 {
            bottlenecks.append(PerformanceBottleneck(
                type: .lowCTR,
                severity: .high,
                description: "Click-through rate is below average",
                impact: "Reduced discoverability and views"
            ))
        }
        
        if metrics.averageViewDuration < 0.4 {
            bottlenecks.append(PerformanceBottleneck(
                type: .lowRetention,
                severity: .high,
                description: "Audience retention is below 40%",
                impact: "Algorithm deprioritization"
            ))
        }
        
        return bottlenecks
    }
    
    private func generateOptimizationRecommendations(
        videoId: String,
        bottlenecks: [PerformanceBottleneck],
        currentMetrics: ContentVideoMetrics
    ) async -> [OptimizationRecommendation] {
        var recommendations: [OptimizationRecommendation] = []
        
        for bottleneck in bottlenecks {
            switch bottleneck.type {
            case .lowCTR:
                recommendations.append(OptimizationRecommendation(
                    type: .thumbnailOptimization,
                    priority: .high,
                    title: "Optimize Thumbnail for Higher CTR",
                    description: "Improve thumbnail design to increase click-through rate",
                    expectedImpact: "15-25% CTR improvement",
                    implementationSteps: [
                        "A/B test different thumbnail designs",
                        "Use bright colors and clear text",
                        "Include emotional expressions",
                        "Test with competitor analysis"
                    ]
                ))
            case .lowRetention:
                recommendations.append(OptimizationRecommendation(
                    type: .contentStructure,
                    priority: .high,
                    title: "Improve Content Structure",
                    description: "Restructure content to maintain audience attention",
                    expectedImpact: "10-20% retention improvement",
                    implementationSteps: [
                        "Add hook in first 15 seconds",
                        "Use pattern interrupts every 30 seconds",
                        "Include preview of upcoming content",
                        "Optimize pacing and editing"
                    ]
                ))
            case .lowEngagement:
                recommendations.append(OptimizationRecommendation(
                    type: .engagementOptimization,
                    priority: .medium,
                    title: "Boost Audience Engagement",
                    description: "Increase likes, comments, and shares",
                    expectedImpact: "20-30% engagement increase",
                    implementationSteps: [
                        "Add clear call-to-actions",
                        "Ask engaging questions",
                        "Respond to comments quickly",
                        "Create community posts"
                    ]
                ))
            case .poorSEO:
                recommendations.append(OptimizationRecommendation(
                    type: .seoOptimization,
                    priority: .medium,
                    title: "Improve SEO",
                    description: "Optimize search visibility",
                    expectedImpact: "15-25% search ranking improvement",
                    implementationSteps: [
                        "Optimize title with keywords",
                        "Improve description",
                        "Add relevant tags",
                        "Use trending hashtags"
                    ]
                ))
            }
        }
        
        return recommendations
    }
    
    private func calculateExpectedImprovements(recommendations: [OptimizationRecommendation]) async -> [String: Double] {
        var improvements: [String: Double] = [:]
        
        for recommendation in recommendations {
            switch recommendation.type {
            case .thumbnailOptimization:
                improvements["ctr_increase"] = 0.20
            case .contentStructure:
                improvements["retention_increase"] = 0.15
            case .engagementOptimization:
                improvements["engagement_increase"] = 0.25
            default:
                break
            }
        }
        
        return improvements
    }
    
    private func prioritizeImplementation(recommendations: [OptimizationRecommendation]) async -> [String] {
        return recommendations
            .sorted { $0.priority.sortOrder > $1.priority.sortOrder }
            .map { $0.title }
    }
    
    private func generateImplementationTimeline(recommendations: [OptimizationRecommendation]) async -> [String: String] {
        var timeline: [String: String] = [:]
        
        for (index, recommendation) in recommendations.enumerated() {
            let weeks = (index + 1) * 2
            timeline[recommendation.title] = "Week \(weeks)"
        }
        
        return timeline
    }
}

// MARK: - Supporting Types

struct ContentInsight: Codable {
    let type: InsightType
    let title: String
    let description: String
    let impact: CreatorImpactLevel
    let actionable: Bool
    let recommendations: [String]
}

enum InsightType: String, Codable {
    case performance = "performance"
    case audience = "audience"
    case seo = "seo"
    case trending = "trending"
    case monetization = "monetization"
}

enum CreatorImpactLevel: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

struct OptimizationRecommendation: Codable {
    let type: CreatorOptimizationType
    let priority: ContentPriority
    let title: String
    let description: String
    let expectedImpact: String
    let implementationSteps: [String]
}

enum CreatorOptimizationType: String, Codable {
    case thumbnailOptimization = "thumbnail"
    case titleOptimization = "title"
    case contentStructure = "structure"
    case seoOptimization = "seo"
    case engagementOptimization = "engagement"
    case timingOptimization = "timing"
}

enum ContentPriority: String, Codable {
    case low
    case medium
    case high
    case critical
    
    var sortOrder: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

struct ContentOptimizationVideoMetadata: Codable {
    let videoId: String
    let creatorId: String
    let title: String
    let description: String
    let tags: [String]
    let category: String
    let targetAudience: String
    let targetKeywords: [String]
}

struct CreatorMetrics: Codable {
    let subscriberCount: Int
    let avgViews: Int
    let engagementRate: Double
    let uploadFrequency: String
    let audienceRetention: Double
}

struct ContentVideoMetrics: Codable {
    let views: Int
    let likes: Int
    let comments: Int
    let shares: Int
    let clickThroughRate: Double
    let averageViewDuration: Double
    let engagementRate: Double
    let retentionCurve: [Double]
}

enum ContentGoal: String, CaseIterable {
    case growth = "growth"
    case monetization = "monetization"
    case engagement = "engagement"
    case branding = "branding"
    case education = "education"
}

enum StrategyTimeframe: String, CaseIterable {
    case month = "1m"
    case quarter = "3m"
    case halfYear = "6m"
    case year = "1y"
}

// Additional supporting types would be defined here...

struct ContentAnalysisResult: Codable {
    let videoId: String
    let performanceScore: Double
    let seoScore: Double
    let engagementScore: Double
    let viralPotential: Double
    let audienceMatch: Double
    let strengths: [String]
    let weaknesses: [String]
    let improvements: [String]
    let competitorComparison: [String: Double]
    let trendAlignment: Double
}

struct PerformanceBottleneck: Codable {
    let type: BottleneckType
    let severity: Severity
    let description: String
    let impact: String
}

enum BottleneckType: String, Codable {
    case lowCTR = "low_ctr"
    case lowRetention = "low_retention"
    case lowEngagement = "low_engagement"
    case poorSEO = "poor_seo"
}

enum Severity: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

// MARK: - ML Request/Response Types (Simplified versions)

struct ContentAnalysisRequest: Encodable {
    let videoId: String
    let creatorId: String
    let videoData: [String: Any]
    let analysisTypes: [String]
    
    enum CodingKeys: String, CodingKey {
        case videoId, creatorId, analysisTypes
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(videoId, forKey: .videoId)
        try container.encode(creatorId, forKey: .creatorId)
        try container.encode(analysisTypes, forKey: .analysisTypes)
    }
}

struct ContentAnalysisResponse: Codable {
    let performanceScore: Double
    let seoScore: Double
    let engagementScore: Double
    let viralPotential: Double
    let audienceMatch: Double
    let strengths: [String]
    let weaknesses: [String]
    let improvements: [String]
    let competitorComparison: [String: Double]
    let trendAlignment: Double
}

// MARK: - Viral Prediction Types

struct ContentViralPredictionRequest: Encodable {
    let videoMetadata: ContentOptimizationVideoMetadata
    let creatorMetrics: CreatorMetrics
    let trendingFactors: [String: Double]
    let historicalData: [String: Any]
    let socialSignals: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case videoMetadata, creatorMetrics, trendingFactors
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(videoMetadata, forKey: .videoMetadata)
        try container.encode(creatorMetrics, forKey: .creatorMetrics)
        try container.encode(trendingFactors, forKey: .trendingFactors)
    }
}

struct ContentViralPredictionResponse: Codable {
    let viralScore: Double
    let probability: Double
    let predictedViews: Int
    let timeToViral: TimeInterval
    let viralFactors: [String]
    let boostingStrategies: [String]
    let optimalReleaseTime: String
    let crossPlatformPotential: [String: Double]
}

struct ContentViralPredictionResult {
    let viralScore: Double
    let probability: Double
    let predictedViews: Int
    let timeToViral: TimeInterval
    let viralFactors: [String]
    let boostingStrategies: [String]
    let optimalReleaseTime: String
    let crossPlatformPotential: [String: Double]
}

// MARK: - Content Strategy Types

struct ContentStrategyRequest: Encodable {
    let creatorId: String
    let goals: [String]
    let timeframe: String
    let audienceData: [String: Any]
    let performanceHistory: [String: Any]
    let competitorAnalysis: [String: Any]
    let trendingTopics: [String]
    
    enum CodingKeys: String, CodingKey {
        case creatorId, goals, timeframe, trendingTopics
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(creatorId, forKey: .creatorId)
        try container.encode(goals, forKey: .goals)
        try container.encode(timeframe, forKey: .timeframe)
        try container.encode(trendingTopics, forKey: .trendingTopics)
    }
}

struct ContentStrategyResponse: Codable {
    let contentPillars: [String]
    let uploadSchedule: [String: String]
    let contentTypes: [String]
    let topicRecommendations: [String]
    let collaborationOpportunities: [String]
    let seasonalContent: [String]
    let performanceTargets: [String: Double]
    let budgetAllocation: [String: Double]
    let riskFactors: [String]
}

struct CreatorContentStrategy {
    let timeframe: StrategyTimeframe
    let contentPillars: [String]
    let uploadSchedule: [String: String]
    let contentTypes: [String]
    let topicRecommendations: [String]
    let collaborationOpportunities: [String]
    let seasonalContent: [String]
    let performanceTargets: [String: Double]
    let budgetAllocation: [String: Double]
    let riskFactors: [String]
}

// MARK: - Competitor Analysis Types

struct CompetitorAnalysisRequest: Encodable {
    let creatorId: String
    let category: String
    let analysisDepth: String
    let competitorCount: Int
    let metrics: [String]
}

struct CompetitorAnalysisResponse: Codable {
    let competitors: [CompetitorProfile]
    let marketPosition: String
    let competitiveAdvantages: [String]
    let threats: [String]
    let recommendations: [String]
    let benchmarks: [String: Double]
}

struct CompetitorAnalysisResult {
    let competitors: [CompetitorProfile]
    let marketPosition: String
    let competitiveAdvantages: [String]
    let threats: [String]
    let recommendations: [String]
    let benchmarks: [String: Double]
}

struct CompetitorProfile: Codable {
    let id: String
    let name: String
    let subscriberCount: Int
    let avgViews: Int
    let engagementRate: Double
    let uploadFrequency: String
    let contentStrategy: String
    let strengths: [String]
    let weaknesses: [String]
    let opportunities: [String]
}

// MARK: - Performance Optimization Types

struct PerformanceOptimizationResult {
    let currentPerformance: ContentVideoMetrics
    let bottlenecks: [PerformanceBottleneck]
    let recommendations: [OptimizationRecommendation]
    let expectedImprovements: [String: Double]
    let implementationPriority: [String]
    let timeline: [String: String]
}

// MARK: - Thumbnail Types

struct ThumbnailOptimizationRequest: Encodable {
    let videoId: String
    let currentThumbnailURL: String
    let videoTitle: String
    let videoCategory: String
    let targetAudience: String
    let competitorThumbnails: [String]
}

struct ThumbnailOptimizationResponse: Codable {
    let currentScore: Double
    let optimizedThumbnails: [OptimizedThumbnailData]
    let recommendations: [String]
    let abTestSuggestions: [String]
}

struct OptimizedThumbnailData: Codable {
    let url: String
    let score: Double
    let improvements: [String]
    let designElements: [String]
    let colorPalette: [String]
    let textOverlay: String
    let emotionalImpact: String
}

struct ThumbnailOptimizationResult {
    let currentScore: Double
    let optimizedThumbnails: [OptimizedThumbnail]
    let recommendations: [String]
    let abTestSuggestions: [String]
}

struct OptimizedThumbnail {
    let url: String
    let score: Double
    let improvements: [String]
    let designElements: [String]
    let colorPalette: [String]
    let textOverlay: String
    let emotionalImpact: String
}

// MARK: - Title Types

struct TitleOptimizationRequest: Encodable {
    let currentTitle: String
    let videoCategory: String
    let targetKeywords: [String]
    let audienceData: [String: Any]
    let competitorTitles: [String]
    let trendingTopics: [String]
    
    enum CodingKeys: String, CodingKey {
        case currentTitle, videoCategory, targetKeywords, competitorTitles, trendingTopics
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentTitle, forKey: .currentTitle)
        try container.encode(videoCategory, forKey: .videoCategory)
        try container.encode(targetKeywords, forKey: .targetKeywords)
        try container.encode(competitorTitles, forKey: .competitorTitles)
        try container.encode(trendingTopics, forKey: .trendingTopics)
    }
}

struct TitleOptimizationResponse: Codable {
    let currentScore: Double
    let optimizedTitles: [OptimizedTitleData]
    let keywordSuggestions: [String]
    let trendingElements: [String]
}

struct OptimizedTitleData: Codable {
    let title: String
    let score: Double
    let seoScore: Double
    let engagementScore: Double
    let predictedCTR: Double
    let keywords: [String]
    let emotionalTriggers: [String]
    let lengthOptimization: String
}

struct TitleOptimizationResult {
    let currentScore: Double
    let optimizedTitles: [OptimizedTitle]
    let keywordSuggestions: [String]
    let trendingElements: [String]
}

struct OptimizedTitle {
    let title: String
    let score: Double
    let seoScore: Double
    let engagementScore: Double
    let clickThroughRate: Double
    let keywords: [String]
    let emotionalTriggers: [String]
    let lengthOptimization: String
}

// MARK: - SEO Types

struct SEOOptimizationRequest: Encodable {
    let videoId: String
    let title: String
    let description: String
    let tags: [String]
    let category: String
    let targetKeywords: [String]
    let competitorAnalysis: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case videoId, title, description, tags, category, targetKeywords
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(videoId, forKey: .videoId)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(tags, forKey: .tags)
        try container.encode(category, forKey: .category)
        try container.encode(targetKeywords, forKey: .targetKeywords)
    }
}

struct SEOOptimizationResponse: Codable {
    let currentSEOScore: Double
    let optimizedTitle: String
    let optimizedDescription: String
    let recommendedTags: [String]
    let keywordDensity: [String: Double]
    let competitorGaps: [String]
    let searchRankingPotential: Double
    let optimizationSteps: [String]
}

struct SEOOptimizationResult {
    let currentSEOScore: Double
    let optimizedTitle: String
    let optimizedDescription: String
    let recommendedTags: [String]
    let keywordDensity: [String: Double]
    let competitorGaps: [String]
    let searchRankingPotential: Double
    let optimizationSteps: [String]
}

// MARK: - Error Types

enum ContentOptimizationError: LocalizedError {
    case invalidURL
    case serverError
    case analysisFailed
    case insufficientData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid service URL"
        case .serverError:
            return "Server error occurred"
        case .analysisFailed:
            return "Content analysis failed"
        case .insufficientData:
            return "Insufficient data for analysis"
        }
    }
}
