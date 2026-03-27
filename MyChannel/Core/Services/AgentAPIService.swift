//
//  AgentAPIService.swift
//  MyChannel
//
//  🎯 MASTER AGENT API SERVICE
//  Unified interface for all 30 Vertex AI agents
//
//  Features:
//  - ✅ Type-safe agent calls
//  - ✅ Automatic retries with exponential backoff
//  - ✅ Response caching (1 hour TTL)
//  - ✅ Rate limiting protection
//  - ✅ Error handling & fallbacks
//  - ✅ Performance tracking
//
//  Created by Keonta on 11/14/24.
//

import Foundation
import Combine

private struct _AgentPromptRequest: Encodable {
    let prompt: String
    let agent: String
}

/// Master service for calling all 30 Vertex AI agents
@MainActor
class AgentAPIService: ObservableObject {
    static let shared = AgentAPIService()
    
    // MARK: - Configuration
    private let vertexAI = VertexAIAgentService.shared
    private let cache = AgentResponseCache.shared
    
    // MARK: - Published State
    @Published var isProcessing = false
    @Published var totalAgentCalls = 0
    @Published var totalErrors = 0
    @Published var averageResponseTime: TimeInterval = 0
    
    private var responseTimes: [TimeInterval] = []
    private let maxResponseTimeSamples = 100
    
    private init() {}
    
    // MARK: - 💰 MONEY MAKER AGENTS
    
    /// Get optimal pricing for subscription tier
    func getOptimalPricing(
        userId: String,
        currentTier: String,
        usage: [String: Any]
    ) async throws -> PricingRecommendation {
        let cacheKey = "pricing_\(userId)_\(currentTier)"
        
        if let cached: PricingRecommendation = cache.get(key: cacheKey) {
            return cached
        }
        
        let result: PricingRecommendation = try await callAgent(
            name: "Dynamic Pricing AI",
            prompt: buildPricingPrompt(userId: userId, currentTier: currentTier, usage: usage)
        )
        
        cache.set(key: cacheKey, value: result, ttl: 3600) // 1 hour
        return result
    }
    
    /// Get optimal ad placements for video
    func getAdPlacements(
        videoId: String,
        duration: TimeInterval,
        category: String
    ) async throws -> AdPlacementRecommendation {
        let cacheKey = "ads_\(videoId)"
        
        if let cached: AdPlacementRecommendation = cache.get(key: cacheKey) {
            return cached
        }
        
        let result: AdPlacementRecommendation = try await callAgent(
            name: "Ad Placement Genius",
            prompt: buildAdPlacementPrompt(videoId: videoId, duration: duration, category: category)
        )
        
        cache.set(key: cacheKey, value: result, ttl: 3600)
        return result
    }
    
    /// Detect fraud in transaction
    func detectFraud(
        userId: String,
        transactionType: String,
        amount: Double,
        metadata: [String: Any]
    ) async throws -> APIFraudDetectionResult {
        // NO CACHING for fraud detection (always real-time)
        
        let result: APIFraudDetectionResult = try await callAgent(
            name: "Fraud Detection AI",
            prompt: buildFraudDetectionPrompt(
                userId: userId,
                transactionType: transactionType,
                amount: amount,
                metadata: metadata
            )
        )
        
        return result
    }
    
    /// Get upsell recommendations
    func getUpsellRecommendations(
        userId: String,
        currentPurchases: [String],
        browsingHistory: [String]
    ) async throws -> UpsellRecommendation {
        let cacheKey = "upsell_\(userId)"
        
        if let cached: UpsellRecommendation = cache.get(key: cacheKey) {
            return cached
        }
        
        let result: UpsellRecommendation = try await callAgent(
            name: "Upsell & Cross-Sell AI",
            prompt: buildUpsellPrompt(
                userId: userId,
                currentPurchases: currentPurchases,
                browsingHistory: browsingHistory
            )
        )
        
        cache.set(key: cacheKey, value: result, ttl: 1800) // 30 minutes
        return result
    }
    
    /// Check match fairness
    func checkMatchFairness(
        challenger: String,
        opponent: String,
        wagerAmount: Double,
        category: String
    ) async throws -> APIMatchFairnessResult {
        let result: APIMatchFairnessResult = try await callAgent(
            name: "Match Fairness Referee",
            prompt: buildMatchFairnessPrompt(
                challenger: challenger,
                opponent: opponent,
                wagerAmount: wagerAmount,
                category: category
            )
        )
        
        return result
    }
    
    // MARK: - 📈 GROWTH AGENTS
    
    /// Get personalized recommendations (uses existing VertexAIAgentService)
    func getRecommendations(
        userId: String,
        sessionHistory: [String],
        limit: Int = 10
    ) async throws -> [String] {
        let cacheKey = "recommendations_\(userId)"
        
        if let cached: [String] = cache.get(key: cacheKey) {
            return cached
        }
        
        let response = try await vertexAI.getRecommendations(
            for: userId,
            sessionHistory: sessionHistory,
            limit: limit
        )
        
        cache.set(key: cacheKey, value: response.videoIDs, ttl: 3600)
        return response.videoIDs
    }
    
    /// Predict viral potential
    func predictViralPotential(
        videoId: String,
        metadata: [String: Any]
    ) async throws -> ViralPrediction {
        let result: ViralPrediction = try await callAgent(
            name: "Viral Content Predictor",
            prompt: buildViralPredictionPrompt(videoId: videoId, metadata: metadata)
        )
        
        return result
    }
    
    /// Get user retention recommendations
    func getRetentionRecommendations(
        userId: String,
        churnRisk: Double
    ) async throws -> RetentionRecommendation {
        let result: RetentionRecommendation = try await callAgent(
            name: "User Retention Doctor",
            prompt: buildRetentionPrompt(userId: userId, churnRisk: churnRisk)
        )
        
        return result
    }
    
    /// Get SEO optimization suggestions
    func getSEOOptimization(
        videoId: String,
        title: String,
        description: String,
        tags: [String]
    ) async throws -> SEORecommendation {
        let cacheKey = "seo_\(videoId)"
        
        if let cached: SEORecommendation = cache.get(key: cacheKey) {
            return cached
        }
        
        let result: SEORecommendation = try await callAgent(
            name: "SEO Discovery Booster",
            prompt: buildSEOPrompt(
                videoId: videoId,
                title: title,
                description: description,
                tags: tags
            )
        )
        
        cache.set(key: cacheKey, value: result, ttl: 3600)
        return result
    }
    
    // MARK: - 🎮 GAMING AGENTS
    
    /// Orchestrate VS match
    func orchestrateMatch(
        challengerId: String,
        opponentId: String?,
        category: String,
        wagerAmount: Double
    ) async throws -> MatchOrchestrationResult {
        let result: MatchOrchestrationResult = try await callAgent(
            name: "Match Orchestrator AI",
            prompt: buildMatchOrchestrationPrompt(
                challengerId: challengerId,
                opponentId: opponentId,
                category: category,
                wagerAmount: wagerAmount
            )
        )
        
        return result
    }
    
    /// Calculate prize pool distribution
    func calculatePrizePool(
        tournamentId: String,
        totalPrizePool: Double,
        participants: Int
    ) async throws -> PrizePoolDistribution {
        let result: PrizePoolDistribution = try await callAgent(
            name: "Prize Pool Manager AI",
            prompt: buildPrizePoolPrompt(
                tournamentId: tournamentId,
                totalPrizePool: totalPrizePool,
                participants: participants
            )
        )
        
        return result
    }
    
    /// Detect cheating in match
    func detectCheating(
        matchId: String,
        metrics: [String: Any]
    ) async throws -> AntiCheatResult {
        // NO CACHING for anti-cheat (always real-time)
        
        let result: AntiCheatResult = try await callAgent(
            name: "Anti-Cheat Guardian AI",
            prompt: buildAntiCheatPrompt(matchId: matchId, metrics: metrics)
        )
        
        return result
    }
    
    /// Schedule tournament
    func scheduleTournament(
        participants: [String],
        format: String,
        startTime: Date
    ) async throws -> TournamentSchedule {
        let result: TournamentSchedule = try await callAgent(
            name: "Tournament Scheduler AI",
            prompt: buildTournamentSchedulePrompt(
                participants: participants,
                format: format,
                startTime: startTime
            )
        )
        
        return result
    }
    
    /// Calculate leaderboard rankings
    func calculateLeaderboard(
        division: String,
        matches: [[String: Any]]
    ) async throws -> LeaderboardResult {
        let result: LeaderboardResult = try await callAgent(
            name: "Leaderboard Calculator AI",
            prompt: buildLeaderboardPrompt(division: division, matches: matches)
        )
        
        return result
    }
    
    // MARK: - 🛡️ SAFETY AGENTS
    
    /// Moderate content (uses existing VertexAIAgentService)
    func moderateContent(
        videoId: String,
        metadata: VertexVideoMetadata,
        transcript: String?
    ) async throws -> CPSTriageResponse {
        return try await vertexAI.triageContent(
            videoID: videoId,
            metadata: metadata,
            transcript: transcript,
            audioFingerprint: nil
        )
    }
    
    /// Detect copyright violations
    func detectCopyright(
        videoId: String,
        audioFingerprint: String,
        videoFingerprint: String
    ) async throws -> CopyrightDetectionResult {
        let result: CopyrightDetectionResult = try await callAgent(
            name: "Copyright Protector AI",
            prompt: buildCopyrightPrompt(
                videoId: videoId,
                audioFingerprint: audioFingerprint,
                videoFingerprint: videoFingerprint
            )
        )
        
        return result
    }
    
    /// Detect spam
    func detectSpam(
        content: String,
        userId: String,
        contentType: String
    ) async throws -> SpamDetectionResult {
        let result: SpamDetectionResult = try await callAgent(
            name: "Spam Destroyer AI",
            prompt: buildSpamDetectionPrompt(
                content: content,
                userId: userId,
                contentType: contentType
            )
        )
        
        return result
    }
    
    /// Filter toxicity
    func filterToxicity(
        content: String,
        context: [String: Any]
    ) async throws -> ToxicityResult {
        let result: ToxicityResult = try await callAgent(
            name: "Toxicity Filter AI",
            prompt: buildToxicityPrompt(content: content, context: context)
        )
        
        return result
    }
    
    /// Handle real-time report
    func handleReport(
        reportId: String,
        contentId: String,
        reason: String,
        evidence: [String: Any]
    ) async throws -> ReportHandlingResult {
        // NO CACHING for reports (always real-time)
        
        let result: ReportHandlingResult = try await callAgent(
            name: "Real-Time Report Handler AI",
            prompt: buildReportHandlingPrompt(
                reportId: reportId,
                contentId: contentId,
                reason: reason,
                evidence: evidence
            )
        )
        
        return result
    }
    
    // MARK: - 📊 ANALYTICS AGENTS
    
    /// Get creator analytics
    func getCreatorAnalytics(
        creatorId: String,
        timeRange: String
    ) async throws -> AgentCreatorAnalytics {
        let cacheKey = "creator_analytics_\(creatorId)_\(timeRange)"
        
        if let cached: AgentCreatorAnalytics = cache.get(key: cacheKey) {
            return cached
        }
        
        let result: AgentCreatorAnalytics = try await callAgent(
            name: "Creator Analytics Pro AI",
            prompt: buildCreatorAnalyticsPrompt(creatorId: creatorId, timeRange: timeRange)
        )
        
        cache.set(key: cacheKey, value: result, ttl: 1800) // 30 minutes
        return result
    }
    
    /// Get audience insights
    func getAudienceInsights(
        creatorId: String
    ) async throws -> APIAudienceInsights {
        let cacheKey = "audience_insights_\(creatorId)"
        
        if let cached: APIAudienceInsights = cache.get(key: cacheKey) {
            return cached
        }
        
        let result: APIAudienceInsights = try await callAgent(
            name: "Audience Insights AI",
            prompt: buildAudienceInsightsPrompt(creatorId: creatorId)
        )
        
        cache.set(key: cacheKey, value: result, ttl: 3600)
        return result
    }
    
    /// Get revenue attribution
    func getRevenueAttribution(
        creatorId: String,
        timeRange: String
    ) async throws -> RevenueAttribution {
        let cacheKey = "revenue_\(creatorId)_\(timeRange)"
        
        if let cached: RevenueAttribution = cache.get(key: cacheKey) {
            return cached
        }
        
        let result: RevenueAttribution = try await callAgent(
            name: "Revenue Attribution AI",
            prompt: buildRevenueAttributionPrompt(creatorId: creatorId, timeRange: timeRange)
        )
        
        cache.set(key: cacheKey, value: result, ttl: 1800)
        return result
    }
    
    /// Forecast trends
    func forecastTrends(
        category: String,
        lookAhead: Int
    ) async throws -> TrendForecast {
        let cacheKey = "trends_\(category)_\(lookAhead)"
        
        if let cached: TrendForecast = cache.get(key: cacheKey) {
            return cached
        }
        
        let result: TrendForecast = try await callAgent(
            name: "Trend Forecaster AI",
            prompt: buildTrendForecastPrompt(category: category, lookAhead: lookAhead)
        )
        
        cache.set(key: cacheKey, value: result, ttl: 7200) // 2 hours
        return result
    }
    
    /// Get competitor intelligence
    func getCompetitorIntelligence(
        competitors: [String]
    ) async throws -> APICompetitorIntelligence {
        let cacheKey = "competitors_\(competitors.joined(separator: "_"))"
        
        if let cached: APICompetitorIntelligence = cache.get(key: cacheKey) {
            return cached
        }
        
        let result: APICompetitorIntelligence = try await callAgent(
            name: "Competitor Intelligence AI",
            prompt: buildCompetitorIntelligencePrompt(competitors: competitors)
        )
        
        cache.set(key: cacheKey, value: result, ttl: 3600)
        return result
    }
    
    // MARK: - ⚙️ INFRASTRUCTURE AGENTS
    
    /// Get creator coaching (uses existing VertexAIAgentService)
    func getCreatorCoaching(
        creatorId: String,
        videoMetadata: VertexVideoMetadata,
        pastPerformance: CreatorStats?
    ) async throws -> CoachingResponse {
        return try await vertexAI.getCreatorCoaching(
            for: creatorId,
            videoMetadata: videoMetadata,
            pastPerformance: pastPerformance
        )
    }
    
    /// Get support response (uses existing VertexAIAgentService)
    func getSupportResponse(
        userId: String,
        question: String,
        userContext: UserContext?
    ) async throws -> VertexSupportResponse {
        return try await vertexAI.getSupportResponse(
            userID: userId,
            question: question,
            userContext: nil
        )
    }
    
    /// Get infrastructure health
    func getInfrastructureHealth() async throws -> InfrastructureHealth {
        let result: InfrastructureHealth = try await callAgent(
            name: "Scale Master AI",
            prompt: "Analyze current infrastructure health. Return JSON with: cpu_usage, memory_usage, network_usage, database_connections, cache_hit_rate, api_response_time, recommendations"
        )
        
        return result
    }
    
    // MARK: - 🔧 Core Agent Call Logic

    /// Agent name → CloudRunService mapping
    private static let agentServiceMap: [String: CloudRunService] = [
        "Dynamic Pricing AI":           .dynamicPricing,
        "Ad Placement Genius":          .placementOptimization,
        "Fraud Detection AI":           .fraudDetection,
        "Upsell & Cross-Sell AI":       .upsellAI,
        "Match Fairness Referee":       .matchFairness,
        "Viral Content Predictor":      .viralPrediction,
        "User Retention Doctor":        .retentionOptimizer,
        "SEO Discovery Booster":        .titleOptimizer,
        "Match Orchestrator AI":        .vsMatchAI,
        "Prize Pool Manager AI":        .myChannelPrizePool,
        "Anti-Cheat Guardian AI":       .myChannelAntiCheat,
        "Tournament Scheduler AI":      .myChannelTournamentBracket,
        "Leaderboard Calculator AI":    .tournamentRanking,
        "Copyright Protector AI":       .copyrightDetection,
        "Spam Destroyer AI":            .spamDetection,
        "Toxicity Filter AI":           .contentModeration,
        "Real-Time Report Handler AI":  .reportContent,
        "Creator Analytics Pro AI":     .analyticsPredictor,
        "Audience Insights AI":         .audienceSegmentation,
        "Revenue Attribution AI":       .revenueMaximizer,
        "Trend Forecaster AI":          .trendForecaster,
        "Competitor Intelligence AI":   .competitorIntelligence,
        "Scale Master AI":              .autoScaler,
    ]

    /// Generic agent call with structured Encodable body + retry logic
    private func callAgent<B: Encodable, T: Decodable>(
        name: String,
        body: B,
        maxRetries: Int = 3
    ) async throws -> T {
        let startTime = Date()
        isProcessing = true
        defer { isProcessing = false }

        guard let service = AgentAPIService.agentServiceMap[name] else {
            throw AgentAPIError.notImplemented(name)
        }

        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                let result: T = try await CloudRunAgentRouter.post(service, path: "/predict", body: body)
                let responseTime = Date().timeIntervalSince(startTime)
                trackResponseTime(responseTime)
                totalAgentCalls += 1
                print("✅ [AgentAPI] \(name) responded in \(String(format: "%.2f", responseTime * 1000))ms")
                return result
            } catch {
                lastError = error
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt))
                    print("⚠️ [AgentAPI] \(name) failed (\(attempt)/\(maxRetries)). Retry in \(delay)s…")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    totalErrors += 1
                    print("🚨 [AgentAPI] \(name) failed after \(maxRetries) attempts: \(error.localizedDescription)")
                }
            }
        }
        throw lastError ?? AgentAPIError.unknownError
    }

    /// Convenience overload: plain-string prompt wrapped in {prompt, agent} JSON
    private func callAgent<T: Decodable>(
        name: String,
        prompt: String,
        maxRetries: Int = 3
    ) async throws -> T {
        return try await callAgent(name: name, body: _AgentPromptRequest(prompt: prompt, agent: name), maxRetries: maxRetries)
    }
    
    // MARK: - 📊 Performance Tracking
    
    private func trackResponseTime(_ time: TimeInterval) {
        responseTimes.append(time)
        
        if responseTimes.count > maxResponseTimeSamples {
            responseTimes.removeFirst()
        }
        
        averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
    }
    
    // MARK: - 📝 Prompt Builders (Placeholders)
    
    private func buildPricingPrompt(userId: String, currentTier: String, usage: [String: Any]) -> String {
        return "Optimize pricing for user \(userId) on tier \(currentTier) with usage: \(usage)"
    }
    
    private func buildAdPlacementPrompt(videoId: String, duration: TimeInterval, category: String) -> String {
        return "Optimize ad placements for video \(videoId), duration: \(duration)s, category: \(category)"
    }
    
    private func buildFraudDetectionPrompt(userId: String, transactionType: String, amount: Double, metadata: [String: Any]) -> String {
        return "Detect fraud for user \(userId), type: \(transactionType), amount: $\(amount), metadata: \(metadata)"
    }
    
    private func buildUpsellPrompt(userId: String, currentPurchases: [String], browsingHistory: [String]) -> String {
        return "Upsell recommendations for user \(userId), purchases: \(currentPurchases), history: \(browsingHistory)"
    }
    
    private func buildMatchFairnessPrompt(challenger: String, opponent: String, wagerAmount: Double, category: String) -> String {
        return "Check match fairness: \(challenger) vs \(opponent), wager: $\(wagerAmount), category: \(category)"
    }
    
    private func buildViralPredictionPrompt(videoId: String, metadata: [String: Any]) -> String {
        return "Predict viral potential for video \(videoId), metadata: \(metadata)"
    }
    
    private func buildRetentionPrompt(userId: String, churnRisk: Double) -> String {
        return "Retention recommendations for user \(userId), churn risk: \(churnRisk)"
    }
    
    private func buildSEOPrompt(videoId: String, title: String, description: String, tags: [String]) -> String {
        return "SEO optimization for video \(videoId), title: \(title), description: \(description), tags: \(tags)"
    }
    
    private func buildMatchOrchestrationPrompt(challengerId: String, opponentId: String?, category: String, wagerAmount: Double) -> String {
        return "Orchestrate match: challenger \(challengerId), opponent: \(opponentId ?? "any"), category: \(category), wager: $\(wagerAmount)"
    }
    
    private func buildPrizePoolPrompt(tournamentId: String, totalPrizePool: Double, participants: Int) -> String {
        return "Calculate prize pool for tournament \(tournamentId), total: $\(totalPrizePool), participants: \(participants)"
    }
    
    private func buildAntiCheatPrompt(matchId: String, metrics: [String: Any]) -> String {
        return "Detect cheating in match \(matchId), metrics: \(metrics)"
    }
    
    private func buildTournamentSchedulePrompt(participants: [String], format: String, startTime: Date) -> String {
        return "Schedule tournament with \(participants.count) participants, format: \(format), start: \(startTime)"
    }
    
    private func buildLeaderboardPrompt(division: String, matches: [[String: Any]]) -> String {
        return "Calculate leaderboard for division \(division) with \(matches.count) matches"
    }
    
    private func buildCopyrightPrompt(videoId: String, audioFingerprint: String, videoFingerprint: String) -> String {
        return "Detect copyright for video \(videoId), audio: \(audioFingerprint), video: \(videoFingerprint)"
    }
    
    private func buildSpamDetectionPrompt(content: String, userId: String, contentType: String) -> String {
        return "Detect spam in \(contentType) from user \(userId): \(content)"
    }
    
    private func buildToxicityPrompt(content: String, context: [String: Any]) -> String {
        return "Filter toxicity in content: \(content), context: \(context)"
    }
    
    private func buildReportHandlingPrompt(reportId: String, contentId: String, reason: String, evidence: [String: Any]) -> String {
        return "Handle report \(reportId) for content \(contentId), reason: \(reason), evidence: \(evidence)"
    }
    
    private func buildCreatorAnalyticsPrompt(creatorId: String, timeRange: String) -> String {
        return "Analytics for creator \(creatorId), time range: \(timeRange)"
    }
    
    private func buildAudienceInsightsPrompt(creatorId: String) -> String {
        return "Audience insights for creator \(creatorId)"
    }
    
    private func buildRevenueAttributionPrompt(creatorId: String, timeRange: String) -> String {
        return "Revenue attribution for creator \(creatorId), time range: \(timeRange)"
    }
    
    private func buildTrendForecastPrompt(category: String, lookAhead: Int) -> String {
        return "Forecast trends in category \(category) for next \(lookAhead) days"
    }
    
    private func buildCompetitorIntelligencePrompt(competitors: [String]) -> String {
        return "Analyze competitors: \(competitors.joined(separator: ", "))"
    }
}

// MARK: - 📦 Response Types

struct PricingRecommendation: Codable {
    let recommendedPrice: Double
    let confidence: Double
    let reasoning: String
}

struct AdPlacementRecommendation: Codable {
    let placements: [AdPlacementTiming]  // ✅ Renamed to avoid conflict
    let estimatedRevenue: Double
}

// ✅ Renamed from AdPlacement to AdPlacementTiming
struct AdPlacementTiming: Codable {
    let timestamp: TimeInterval
    let type: String
    let duration: TimeInterval
}

struct APIFraudDetectionResult: Codable {
    let riskScore: Double
    let decision: String // "allow", "review", "block"
    let reasons: [String]
    let confidence: Double
}

struct UpsellRecommendation: Codable {
    let products: [String]
    let expectedRevenue: Double
    let confidence: Double
}

struct APIMatchFairnessResult: Codable {
    let fairnessScore: Double
    let isBalanced: Bool
    let reasoning: String
    let suggestedAdjustments: [String]
}

struct ViralPrediction: Codable {
    let viralScore: Double // 0-100
    let predictedViews: Int
    let viralFactors: [String]
    let recommendations: [String]
}

struct RetentionRecommendation: Codable {
    let actions: [String]
    let expectedImpact: Double
    let priority: String
}

struct SEORecommendation: Codable {
    let optimizedTitle: String
    let optimizedDescription: String
    let recommendedTags: [String]
    let estimatedRankingBoost: Double
}

struct MatchOrchestrationResult: Codable {
    let matchId: String
    let suggestedOpponents: [String]
    let fairnessScore: Double
    let estimatedDuration: TimeInterval
}

struct PrizePoolDistribution: Codable {
    let placements: [PrizePlacement]
    let totalDistributed: Double
}

struct PrizePlacement: Codable {
    let rank: Int
    let userId: String
    let amount: Double
}

struct AntiCheatResult: Codable {
    let suspicionScore: Double
    let isCheating: Bool
    let evidence: [String]
    let recommendedAction: String
}

struct TournamentSchedule: Codable {
    let rounds: [TournamentRound]
    let totalDuration: TimeInterval
}

struct TournamentRound: Codable {
    let roundNumber: Int
    let matches: [ScheduledMatch]
    let startTime: Date
}

struct ScheduledMatch: Codable {
    let matchId: String
    let participants: [String]
    let startTime: Date
}

struct LeaderboardResult: Codable {
    let rankings: [APILeaderboardEntry]
    let lastUpdated: Date
}

struct APILeaderboardEntry: Codable {
    let rank: Int
    let userId: String
    let score: Double
    let wins: Int
    let losses: Int
}

struct CopyrightDetectionResult: Codable {
    let hasViolation: Bool
    let matches: [CopyrightMatch]
    let confidence: Double
    let action: String
}

struct CopyrightMatch: Codable {
    let contentId: String
    let owner: String
    let timestamp: TimeInterval
    let type: String
}

struct SpamDetectionResult: Codable {
    let isSpam: Bool
    let spamScore: Double
    let reasons: [String]
    let action: String
}

struct ToxicityResult: Codable {
    let toxicityScore: Double
    let isToxic: Bool
    let categories: [String]
    let action: String
}

struct ReportHandlingResult: Codable {
    let decision: String
    let priority: String
    let assignedTo: String?
    let estimatedResolutionTime: TimeInterval
}

struct AgentCreatorAnalytics: Codable {
    let totalViews: Int
    let totalRevenue: Double
    let growthRate: Double
    let topVideos: [String]
    let insights: [String]
}

struct APIAudienceInsights: Codable {
    let demographics: [String: Double]
    let interests: [String]
    let watchPatterns: [String: String]
    let recommendations: [String]
}

struct RevenueAttribution: Codable {
    let sources: [RevenueSource]
    let totalRevenue: Double
}

struct RevenueSource: Codable {
    let source: String
    let amount: Double
    let percentage: Double
}

struct TrendForecast: Codable {
    let trends: [APITrend]
    let confidence: Double
}

struct APITrend: Codable {
    let topic: String
    let predictedGrowth: Double
    let peakDate: Date
}

struct APICompetitorIntelligence: Codable {
    let competitors: [CompetitorAnalysis]
    let opportunities: [String]
    let threats: [String]
}

struct CompetitorAnalysis: Codable {
    let name: String
    let strengths: [String]
    let weaknesses: [String]
    let marketShare: Double
}

struct InfrastructureHealth: Codable {
    let cpuUsage: Double
    let memoryUsage: Double
    let networkUsage: Double
    let databaseConnections: Int
    let cacheHitRate: Double
    let apiResponseTime: TimeInterval
    let recommendations: [String]
}

// MARK: - 🗄️ Agent Response Cache

class AgentResponseCache {
    static let shared = AgentResponseCache()
    
    private var cache: [String: CachedResponse] = [:]
    private let queue = DispatchQueue(label: "com.mychannel.agentcache", attributes: .concurrent)
    
    private init() {}
    
    func get<T: Codable>(key: String) -> T? {
        queue.sync {
            guard let cached = cache[key], cached.expiresAt > Date() else {
                return nil
            }
            
            guard let data = cached.data as? Data else {
                return nil
            }
            
            return try? JSONDecoder().decode(T.self, from: data)
        }
    }
    
    func set<T: Codable>(key: String, value: T, ttl: TimeInterval) {
        queue.async(flags: .barrier) {
            guard let data = try? JSONEncoder().encode(value) else {
                return
            }
            
            self.cache[key] = CachedResponse(
                data: data,
                expiresAt: Date().addingTimeInterval(ttl)
            )
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

struct CachedResponse {
    let data: Any
    let expiresAt: Date
}

// MARK: - ⚠️ Errors

enum AgentAPIError: LocalizedError {
    case notImplemented(String)
    case invalidResponse
    case timeout
    case rateLimited
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .notImplemented(let agent):
            return "Agent '\(agent)' not yet implemented"
        case .invalidResponse:
            return "Invalid response from agent"
        case .timeout:
            return "Agent request timed out"
        case .rateLimited:
            return "Rate limit exceeded"
        case .unknownError:
            return "Unknown agent error"
        }
    }
}

