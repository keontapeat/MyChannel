//
//  CloudRunAgentRouter.swift
//  MyChannel
//
//  Centralized URL registry for all 244 live Cloud Run agents.
//  Base pattern: https://{service}-fkri6ifojq-uc.a.run.app
//

import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

private struct _EmptyBody: Encodable {}

struct CloudRunAgentRouter {

    private static let base = "https://%@-fkri6ifojq-uc.a.run.app"

    static func url(for service: CloudRunService) -> URL {
        URL(string: String(format: base, service.rawValue))!
    }

    // MARK: - Proxy URL
    //
    // Direct Cloud Run calls are blocked by the GCP org policy.
    // All calls route through the agentProxy Firebase callable function which:
    //   1. Verifies the Firebase ID token (automatic via onCall)
    //   2. Fetches a Google Identity Token using the runtime service account
    //   3. Forwards the request to the target Cloud Run service
    //
    // Firebase callable endpoint: POST with {data: {service, path, body, method}}
    // Response envelope: {result: <agent response>}
    //
    private static let proxyBase = "https://us-central1-mychannel-ca26d.cloudfunctions.net/agentProxy"

    // MARK: - Firebase ID Token

    private static func idToken() async -> String? {
        #if canImport(FirebaseAuth)
        return try? await Auth.auth().currentUser?.getIDToken()
        #else
        return nil
        #endif
    }

    // MARK: - Call helpers

    static func post<B: Encodable, T: Decodable>(
        _ service: CloudRunService,
        path: String = "/predict",
        body: B,
        timeout: TimeInterval = 30
    ) async throws -> T {
        return try await callProxy(
            service: service.rawValue,
            path: path,
            method: "POST",
            body: body,
            timeout: timeout
        )
    }

    static func get<T: Decodable>(
        _ service: CloudRunService,
        path: String = "/health",
        timeout: TimeInterval = 15
    ) async throws -> T {
        return try await callProxy(
            service: service.rawValue,
            path: path,
            method: "GET",
            body: _EmptyBody(),
            timeout: timeout
        )
    }

    // MARK: - Firebase Callable Proxy

    /// Wraps the request in the Firebase callable envelope {data: ...} and
    /// unwraps the response from {result: ...}. Attaches Firebase ID token.
    private static func callProxy<B: Encodable, T: Decodable>(
        service: String,
        path: String,
        method: String,
        body: B,
        timeout: TimeInterval
    ) async throws -> T {
        // Encode the inner body as a JSON object
        let bodyData = try JSONEncoder().encode(body)
        let bodyJSON = try JSONSerialization.jsonObject(with: bodyData)

        // Firebase callable envelope: {data: {service, path, method, body}}
        let envelope: [String: Any] = [
            "data": [
                "service": service,
                "path": path,
                "method": method,
                "body": bodyJSON
            ] as [String: Any]
        ]

        var req = URLRequest(url: URL(string: proxyBase)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = timeout
        req.httpBody = try JSONSerialization.data(withJSONObject: envelope)
        if let token = await idToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "error"
            throw CloudRunError.httpError((resp as? HTTPURLResponse)?.statusCode ?? 0, msg)
        }

        // Firebase callable response envelope: {result: <actual response>}
        if let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let result = envelope["result"] {
            let resultData = try JSONSerialization.data(withJSONObject: result)
            return try JSONDecoder().decode(T.self, from: resultData)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Error

enum CloudRunError: LocalizedError {
    case httpError(Int, String)
    case serviceUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let msg): return "Cloud Run error \(code): \(msg)"
        case .serviceUnavailable(let svc): return "Service unavailable: \(svc)"
        }
    }
}

// MARK: - All 244 Live Services

enum CloudRunService: String, CaseIterable {
    // Ad Network Core
    case rtbBidding = "rtb-bidding-predictor"
    case advancedTargeting = "advanced-targeting-predictor"
    case fraudDetection = "fraud-detection-predictor"
    case creativePerformance = "creative-performance-predictor"
    case budgetPacing = "budget-pacing-predictor"
    case placementOptimization = "placement-optimization-predictor"
    case contextualAnalysis = "contextual-analysis-predictor"
    case competitorIntelligence = "competitor-intelligence-predictor"
    case viewabilityPrediction = "viewability-prediction-predictor"
    case brandSafetyML = "brand-safety-ml-predictor"
    case audienceLookalike = "audience-lookalike-predictor"
    case adQualityScorer = "ad-quality-scorer-predictor"

    // Ad Optimization & Revenue
    case adOptimization = "ad-optimization"
    case adRevBooster = "ad-revenue-booster"
    case adsServe = "ads-serve"
    case realTimeBidding = "real-time-bidding-ai"
    case brandSafety = "brand-safety"
    case brandSafetyAI = "brand-safety-ai"
    case campaignOptimizer = "campaign-optimizer-ai"
    case dynamicPricing = "dynamic-pricing-v2"

    // Content AI
    case mlAgents = "ml-agents"
    case recommendations = "recommendations"
    case viralPrediction = "viral-prediction"
    case watchTimeOptimizer = "watch-time-optimizer"
    case trendForecaster = "trend-forecaster"
    case titleOptimizer = "title-optimizer"
    case titleGenAI = "title-gen-ai"
    case descriptionWriter = "description-writer"
    case descriptionWriterAI = "description-writer-ai"
    case thumbnailGen = "thumbnail-gen-v2"
    case thumbnailGenerator = "thumbnail-generator"
    case scriptWriter = "script-writer-ai"
    case tiktokAlgorithm = "tiktok-algorithm"
    case shortsOptimizer = "shorts-optimizer-ai"
    case playlistOptimizer = "playlist-optimizer-ai"
    case contentQuality = "content-quality-ai"

    // Video & Media
    case videoEditorAI = "video-editor-ai"
    case videoEditorAIv2 = "video-editor-ai-v2"
    case videoOptimizerAI = "video-optimizer-ai"
    case streamQualityAI = "stream-quality-ai"
    case streamQualityOptimizer = "stream-quality-optimizer"
    case liveStreamOptimizer = "live-stream-optimizer-ai"
    case aiVideoEditor = "ai-video-editor"
    case audioBookAI = "audiobook-ai"
    case voiceAI = "voice-ai"
    case voiceAIv2 = "voice-ai-v2"
    case voiceSynthesizer = "voice-synthesizer-ai"
    case voiceToScript = "voice-to-script"
    case translationAI = "translation-ai-v2"
    case multiLanguageAI = "multi-language-ai"
    case multiLanguageAIv2 = "multi-language-ai-v2"
    case aiTranslation = "ai-translation"

    // Creator Tools
    case creatorCoachAI = "creator-coach-ai"
    case creatorEarningsOptimizer = "creator-earnings-optimizer"
    case creatorFundAI = "creator-fund-ai"
    case creatorFundAllocator = "creator-fund-allocator"
    case creatorRelationsAI = "creator-relations-ai"
    case creatorDiscoveryAI = "creator-discovery-ai"
    case creatorRevenueOptimizer = "creator-revenue-optimizer"
    case creatorVerifiedEmail = "creator-verified-email-ai"
    case revenueMaximizer = "revenue-maximizer-ai"
    case revenueSplitMaximizer = "revenue-split-maximizer"
    case monetizationMaximizer = "monetization-maximizer-ai"
    case monetizationReview = "monetization-review-ai"
    case membershipOptimizer = "membership-optimizer"
    case merchandiseAI = "merchandise-ai"
    case affiliateOptimizer = "affiliate-optimizer"
    case sponsorshipMatcher = "sponsorship-matcher"
    case sponsorshipMatcherAI = "sponsorship-matcher-ai"
    case sponsorshipMaximizer = "sponsorship-maximizer"
    case superChatOptimizer = "super-chat-optimizer"
    case negotiationAI = "negotiation-ai"

    // Analytics & Intelligence
    case analyticsPredictor = "analytics-predictor-ai"
    case behaviorPrediction = "behavior-prediction-ai"
    case engagementPredictor = "engagement-predictor"
    case engagementBooster = "engagement-booster-ai"
    case retentionOptimizer = "retention-optimizer-ai"
    case churnPrevention = "churn-prevention"
    case lifetimeValue = "lifetime-value-ai"
    case audienceGrowth = "audience-growth-ai"
    case audienceSegmentation = "audience-segmentation-ai"
    case hyperPersonalization = "hyper-personalization-ai"
    case influencerScoring = "influencer-scoring-ai"
    case demandForecasting = "demand-forecasting-ai"
    case socialListening = "social-listening-ai"
    case competitiveIntel = "competitive-intel-ai"
    case competitorAnalyzer = "competitor-analyzer-ai"
    case awardPredictor = "award-predictor-ai"

    // Safety & Moderation
    case contentModeration = "content-moderation"
    case moderationAIv2 = "moderation-ai-v2"
    case spamDetection = "spam-detection"
    case fraudDetectionAI = "fraud-detection"
    case deepfakeDetection = "deepfake-detection"
    case deepfakeDetector = "deepfake-detector-ai"
    case copyrightDetection = "copyright-detection"
    case copyrightClaims = "copyright-claims-ai"
    case copyrightDetectorAI = "copyright-detector-ai"
    case trustSafetyAI = "trust-safety-ai"
    case legalCompliance = "legal-compliance-ai"
    case insiderThreat = "insider-threat-detector"
    case promptInjectionDefender = "prompt-injection-defender"
    case aiSecurityFortress = "ai-security-fortress"
    case crisisDetection = "crisis-detection-ai"
    case reportContent = "report-content"
    case appealReview = "appeal-review-ai"
    case verificationScoring = "verification-scoring-ai"

    // Growth & User Acquisition
    case userAcquisition = "user-acquisition-ai" // may not exist in 244 — handled gracefully
    case subscriptionGrowth = "subscription-growth-ai"
    case growthASOSync = "growth-aso-sync"
    case growthASOPublish = "growth-aso-publish"
    case newUserDiscovery = "neural-search-ai"
    case emailPersonalization = "email-personalization-ai"
    case emailTimingOptimizer = "email-timing-optimizer"
    case notificationTiming = "notification-timing"
    case welcomeEmailAI = "welcome-email-ai"
    case verificationEmailAI = "verification-email-ai"
    case milestoneEmailAI = "milestone-email-ai"
    case upsellAI = "upsell-ai"
    case crossSellAI = "cross-sell-ai"
    case paymentOptimizer = "payment-optimizer-ai"
    case taxOptimization = "tax-optimization-ai"

    // Gaming
    case aiGaming = "ai-gaming"
    case aiGamingv2 = "ai-gaming-v2"
    case matchFairness = "match-fairness"
    case vsMatchAI = "vs-match-ai"
    case vsMatchOdds = "vs-match-odds-ai"
    case tournamentRanking = "tournament-ranking-ai"
    case medalRanker = "medal-ranker-ai"
    case ticketSalesAI = "ticket-sales-ai"
    case esportsAI = "esports-ai"
    case cloudGamingAI = "cloud-gaming-ai"
    case myChannelGamingAI = "mychannel-gaming-ai"
    case myChannelAntiCheat = "mychannel-gaming-anti-cheat"
    case myChannelDispute = "mychannel-gaming-dispute-resolution"
    case myChannelGameplayAnalyzer = "mychannel-gaming-gameplay-analyzer"
    case myChannelMatchFairness = "mychannel-gaming-match-fairness"
    case myChannelPerformancePredictor = "mychannel-gaming-performance-predictor"
    case myChannelPrizePool = "mychannel-gaming-prize-pool"
    case myChannelTournamentBracket = "mychannel-gaming-tournament-bracket"

    // Partnership AIs
    case nbAI = "nba-partnership-ai"
    case nflAI = "nfl-partnership-ai"
    case premierLeagueAI = "premier-league-ai"
    case ufcAI = "ufc-partnership-ai"
    case telecomAI = "telecom-partnership-ai"
    case olympicsAI = "olympics-ai"

    // Specialized Content
    case aiMusic = "ai-music"
    case aiMusicv2 = "ai-music-v2"
    case myChannelMusicAI = "mychannel-music-ai"
    case myChannelSportsAI = "mychannel-sports-ai"
    case myChannelTVAI = "mychannel-tv-ai"
    case educationAI = "education-ai"
    case educationAIv2 = "education-ai-v2"
    case cookingAI = "cooking-ai"
    case fitnessAI = "fitness-ai"
    case fitnessAIv2 = "fitness-ai-v2"
    case travelAI = "travel-ai"
    case travelAIv2 = "travel-ai-v2"
    case newsAI = "news-ai"
    case newsAIv2 = "news-ai-v2"
    case shoppingAI = "shopping-ai"
    case shoppingAIv2 = "shopping-ai-v2"
    case podcastAI = "podcast-ai"
    case datingAI = "dating-ai"
    case datingAIv2 = "dating-ai-v2"
    case kidsAI = "kids-ai"
    case kidsAIv2 = "kids-ai-v2"

    // Emerging Tech
    case blockchainAI = "blockchain-ai"
    case blockchainAIv2 = "blockchain-ai-v2"
    case nftMarketplace = "nft-marketplace-ai"
    case metaverseAI = "metaverse-ai"
    case metaverseAIv2 = "metaverse-ai-v2"
    case vrArAI = "vr-ar-ai"
    case vrArAIv2 = "vr-ar-ai-v2"
    case quantumAI = "quantum-ai"
    case quantumAIv2 = "quantum-ai-v2"
    case singularityAI = "singularity-ai"
    case singularityAIv2 = "singularity-ai-v2"

    // Platform Services
    case myChannelAI = "mychannel-ai"
    case myChannelAuth = "mychannel-auth"
    case myChannelContent = "mychannel-content"
    case myChannelEvents = "mychannel-events"
    case myChannelTranscode = "mychannel-transcode"
    case myChannelUpload = "mychannel-upload"
    case superAITeam = "super-ai-team"
    case aiRank = "ai-rank"
    case aiAvatar = "ai-avatar"
    case aiAvatarv2 = "ai-avatar-v2"
    case advertiserAI = "advertiser-ai"
    case maIntelligence = "ma-intelligence-ai"
    case ipoReadiness = "ipo-readiness"
    case ipoReadinessAI = "ipo-readiness-ai"
    case investorRelations = "investor-relations"
    case investorRelationsAI = "investor-relations-ai"

    // Infrastructure
    case cdnOptimizer = "cdn-optimizer"
    case cdnOptimizerv2 = "cdn-optimizer-v2"
    case autoScaler = "auto-scaler"
    case androidPreload = "android-preload-ai"
    case androidPreloadOptimizer = "android-preload-optimizer"
    case apiShield = "api-shield"
    case rateLimiterAI = "rate-limiter-ai"
    case databaseOptimizer = "database-optimizer"
    case redisCache = "redis-cache"
    case fileGuardianOpus = "file-guardian-opus"
    case globalExpansion = "global-expansion-ai"
    case regionalContent = "regional-content-ai"
    case regionalContentOptimizer = "regional-content-optimizer"
    case searchRanking = "search-ranking-ai"
    case commentAnalyzer = "comment-analyzer-ai"
    case emotionDetection = "emotion-detection-ai"
    case autoplayIntelligence = "autoplay-intelligence"
    case mychannelaABTesting = "a-b-testing-ai"
    case abTestingAI = "ab-testing-ai"
    case customerServiceAI = "customer-service-ai"
    case supportAIv2 = "support-ai-v2"
    case supportTriageAI = "support-triage-ai"

    // TMDB / Content Discovery
    case tmdbDetails = "tmdb-details"
    case tmdbFreeAds = "tmdb-free-ads"
    case tmdbPopular = "tmdb-popular"
    case tmdbTrending = "tmdb-trending"

    // Payments & Economy
    case escrowPayments = "escrow-payments"
    case tippingAI = "tipping-ai"
    case tippingMaximizer = "tipping-maximizer"
    case virtualGifts = "virtual-gifts-ai"

    // Health & Operations
    case health = "health"
    case doctor = "doctor"
    case gateway = "gateway"
    case eventsView = "events-view"
    case cleanupOrphaned = "cleanuporphanedmedia"
    case deleteExpiredStories = "deleteexpiredstories"
    case recaptchaVerify = "recaptcha-verify"
    case reviewsEligibility = "reviews-eligibility"
    case referralCreate = "referral-create"

    // Firebase trigger services
    case onCommentCreated = "on-comment-created"
    case onCommentDeleted = "on-comment-deleted"
    case onLikeCreated = "on-like-created"
    case onLikeDeleted = "on-like-deleted"
    case onMembershipRenew = "on-membership-renew"
    case onSubscribeCreated = "on-subscribe-created"
    case onSubscribeDeleted = "on-subscribe-deleted"
    case onTipReceived = "on-tip-received"
    case onUploadCreated = "on-upload-created-trigger"
    case onVideoReady = "on-video-ready"
    case notifyFollowers = "notifyfollowersonstorycreated"
}
