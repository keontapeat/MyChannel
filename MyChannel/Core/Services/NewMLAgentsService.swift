// MARK: - NewMLAgentsService.swift
// Wires all 47 new ML agents into the iOS app
// All endpoints: https://<service-name>-fkri6ifojq-uc.a.run.app

import Foundation

@MainActor
final class NewMLAgentsService: ObservableObject {

    static let shared = NewMLAgentsService()
    private let baseURL = "https://%@-fkri6ifojq-uc.a.run.app"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Generic Request Helper

    private func call(
        service: String,
        endpoint: String,
        body: [String: Any]
    ) async throws -> Data {
        let url = URL(string: String(format: baseURL, service) + endpoint)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: req)
        return data
    }

    private func callGET(service: String, endpoint: String) async throws -> Data {
        let url = URL(string: String(format: baseURL, service) + endpoint)!
        let (data, _) = try await session.data(from: url)
        return data
    }

    // MARK: - VIDEO INTELLIGENCE

    /// Detect scene changes for auto chapters
    func detectScenes(videoId: String, videoUrl: String) async throws -> [String: Any] {
        let data = try await call(service: "scene-detection-service", endpoint: "/detect",
                                  body: ["videoId": videoId, "videoUrl": videoUrl])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Auto-generate meaningful chapter titles
    func generateChapters(videoId: String, transcript: String, scenes: [[String: Any]]) async throws -> [String: Any] {
        let data = try await call(service: "auto-chapters-service", endpoint: "/generate",
                                  body: ["videoId": videoId, "transcript": transcript, "scenes": scenes])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Transcribe audio to text with SRT/VTT captions
    func transcribeAudio(videoId: String, audioUri: String, language: String = "en-US") async throws -> [String: Any] {
        let data = try await call(service: "speech-to-text-service", endpoint: "/transcribe",
                                  body: ["videoId": videoId, "audioUri": audioUri, "language": language])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Auto-generate video summary and description
    func summarizeVideo(videoId: String, transcript: String, title: String) async throws -> [String: Any] {
        let data = try await call(service: "video-summary-service", endpoint: "/summarize",
                                  body: ["videoId": videoId, "transcript": transcript, "title": title])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Generate highlight reel from video
    func generateHighlights(videoId: String, segments: [[String: Any]], engagementData: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "highlight-reel-service", endpoint: "/generate",
                                  body: ["videoId": videoId, "segments": segments, "engagementData": engagementData])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Analyze hook effectiveness (first 30 seconds)
    func analyzeHook(videoId: String, transcript: String, retentionData: [[String: Any]]) async throws -> [String: Any] {
        let data = try await call(service: "hook-analyzer-service", endpoint: "/analyze",
                                  body: ["videoId": videoId, "transcript": transcript, "retentionData": retentionData])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Check audio quality before publishing
    func checkAudioQuality(videoId: String, audioUri: String) async throws -> [String: Any] {
        let data = try await call(service: "audio-quality-service", endpoint: "/analyze",
                                  body: ["videoId": videoId, "audioUri": audioUri])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Analyze video pacing
    func analyzePacing(videoId: String, transcript: String, duration: Int) async throws -> [String: Any] {
        let data = try await call(service: "pacing-optimizer-service", endpoint: "/analyze",
                                  body: ["videoId": videoId, "transcript": transcript, "duration": duration])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - USER INTELLIGENCE

    /// Detect user mood from behavior
    func detectUserMood(userId: String, behavior: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "mood-detection-service", endpoint: "/detect",
                                  body: ["userId": userId, "behavior": behavior])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Detect what user wants this session
    func detectSessionIntent(userId: String, sessionData: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "session-intent-service", endpoint: "/detect",
                                  body: ["userId": userId, "sessionData": sessionData])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Predict binge-watch session
    func predictBingeWatch(userId: String, userHistory: [String: Any], currentSession: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "binge-watch-predictor-service", endpoint: "/predict",
                                  body: ["userId": userId, "userHistory": userHistory, "currentSession": currentSession])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Detect content fatigue and inject diversity
    func detectContentFatigue(userId: String, watchHistory: [[String: Any]], currentSession: [[String: Any]]) async throws -> [String: Any] {
        let data = try await call(service: "content-fatigue-service", endpoint: "/detect",
                                  body: ["userId": userId, "watchHistory": watchHistory, "currentSession": currentSession])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Detect if user fell asleep
    func detectSleepMode(userId: String, interactionSignals: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "sleep-mode-service", endpoint: "/detect",
                                  body: ["userId": userId, "interactionSignals": interactionSignals])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Detect if user wants to explore new content
    func detectDiscoveryMode(userId: String, userSignals: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "discovery-mode-service", endpoint: "/detect",
                                  body: ["userId": userId, "userSignals": userSignals])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Detect multi-device usage and optimize cross-device experience
    func detectSecondScreen(userId: String, deviceSessions: [[String: Any]]) async throws -> [String: Any] {
        let data = try await call(service: "second-screen-service", endpoint: "/detect",
                                  body: ["userId": userId, "deviceSessions": deviceSessions])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - COMMUNITY INTELLIGENCE

    /// Detect viral debates in comments
    func detectDebate(videoId: String, comments: [[String: Any]]) async throws -> [String: Any] {
        let data = try await call(service: "debate-detector-service", endpoint: "/detect",
                                  body: ["videoId": videoId, "comments": comments])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Detect coordinated harassment campaign
    func detectToxicPattern(targetUserId: String, reports: [[String: Any]]) async throws -> [String: Any] {
        let data = try await call(service: "toxic-pattern-service", endpoint: "/detect",
                                  body: ["targetUserId": targetUserId, "reports": reports])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Get platform community health score
    func getCommunityHealth(metrics: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "community-health-service", endpoint: "/score",
                                  body: ["metrics": metrics])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Match creator with superfans
    func scoreCreatorFan(userId: String, creatorId: String, userActivity: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "creator-fan-matcher-service", endpoint: "/score",
                                  body: ["userId": userId, "creatorId": creatorId, "userActivity": userActivity])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Optimize poll for maximum engagement
    func optimizePoll(creatorId: String, pollData: [String: Any], audienceData: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "poll-optimizer-service", endpoint: "/optimize",
                                  body: ["creatorId": creatorId, "pollData": pollData, "audienceData": audienceData])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Optimize virtual gift timing
    func optimizeGifting(userId: String, creatorId: String, streamData: [String: Any], userData: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "gifting-optimizer-service", endpoint: "/optimize",
                                  body: ["userId": userId, "creatorId": creatorId, "streamData": streamData, "userData": userData])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - SECURITY

    /// Detect account takeover in real-time
    func assessAccountTakeover(userId: String, signals: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "account-takeover-service", endpoint: "/assess",
                                  body: ["userId": userId, "signals": signals])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Detect AI-generated / synthetic media
    func detectSyntheticMedia(videoId: String, content: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "synthetic-media-detection-service", endpoint: "/detect",
                                  body: ["videoId": videoId, "content": content])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Detect phishing links in content
    func detectPhishing(contentId: String, text: String) async throws -> [String: Any] {
        let data = try await call(service: "phishing-detector-service", endpoint: "/analyze",
                                  body: ["contentId": contentId, "text": text])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Detect data exfiltration
    func detectDataExfiltration(userId: String, activity: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "data-exfiltration-service", endpoint: "/detect",
                                  body: ["userId": userId, "activity": activity])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - MUSIC & AUDIO

    /// Recommend music mood for video
    func recommendMusicMood(videoId: String, videoData: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "music-mood-service", endpoint: "/recommend",
                                  body: ["videoId": videoId, "videoData": videoData])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Sync cuts to music beats
    func syncBeats(videoId: String, audioData: [String: Any], scenes: [[String: Any]]) async throws -> [String: Any] {
        let data = try await call(service: "beat-sync-service", endpoint: "/analyze",
                                  body: ["videoId": videoId, "audioData": audioData, "scenes": scenes])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Find licensed music alternatives
    func findMusicAlternatives(videoId: String, flaggedSong: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "music-licensing-service", endpoint: "/alternatives",
                                  body: ["videoId": videoId, "flaggedSong": flaggedSong])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Detect voice cloning
    func detectVoiceClone(videoId: String, audioSignals: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "voice-clone-detector-service", endpoint: "/detect",
                                  body: ["videoId": videoId, "audioSignals": audioSignals])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - GLOBAL EXPANSION

    /// Check cultural sensitivity for regions
    func checkCulturalSensitivity(videoId: String, content: [String: Any], targetRegions: [String]) async throws -> [String: Any] {
        let data = try await call(service: "cultural-sensitivity-service", endpoint: "/analyze",
                                  body: ["videoId": videoId, "content": content, "targetRegions": targetRegions])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Get local trending feed for country
    func getLocalTrending(country: String, language: String, videos: [[String: Any]]) async throws -> [String: Any] {
        let data = try await call(service: "local-trending-service", endpoint: "/trending",
                                  body: ["country": country, "language": language, "videos": videos])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Get PPP-adjusted local price
    func getLocalPrice(basePriceUsd: Double, country: String, currency: String) async throws -> [String: Any] {
        let data = try await call(service: "currency-optimizer-service", endpoint: "/price",
                                  body: ["basePriceUsd": basePriceUsd, "country": country, "currency": currency])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Get regional compliance requirements
    func getComplianceRequirements(country: String, userAge: Int? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["country": country]
        if let age = userAge { body["userAge"] = age }
        let data = try await call(service: "regional-compliance-service", endpoint: "/requirements", body: body)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Detect language dialect
    func detectDialect(videoId: String, transcript: String) async throws -> [String: Any] {
        let data = try await call(service: "dialect-detection-service", endpoint: "/detect",
                                  body: ["videoId": videoId, "transcript": transcript])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - iOS / APP SPECIFIC

    /// Predict crash risk from device metrics
    func predictCrashRisk(deviceId: String, deviceMetrics: [String: Any], sessionMetrics: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "app-crash-predictor-service", endpoint: "/predict",
                                  body: ["deviceId": deviceId, "deviceMetrics": deviceMetrics, "sessionMetrics": sessionMetrics])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Get battery optimization recommendations
    func getBatteryOptimizations(deviceId: String, deviceState: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "battery-optimizer-service", endpoint: "/optimize",
                                  body: ["deviceId": deviceId, "deviceState": deviceState])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Predict offline content to download
    func predictOfflineContent(userId: String, userProfile: [String: Any], deviceInfo: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "offline-content-service", endpoint: "/predict",
                                  body: ["userId": userId, "userProfile": userProfile, "deviceInfo": deviceInfo])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Generate accessibility content
    func generateAccessibilityContent(videoId: String, videoMetadata: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "accessibility-ai-service", endpoint: "/describe",
                                  body: ["videoId": videoId, "videoMetadata": videoMetadata])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - BUSINESS INTELLIGENCE

    /// Get platform health score
    func getPlatformHealth(metrics: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "platform-health-service", endpoint: "/score",
                                  body: ["metrics": metrics])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Calculate unit economics
    func calculateUnitEconomics(metrics: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "unit-economics-service", endpoint: "/calculate",
                                  body: ["metrics": metrics])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Size the market for a region
    func sizeMarket(regions: [String], targetShare: Double = 0.05) async throws -> [String: Any] {
        let data = try await call(service: "market-sizing-service", endpoint: "/size",
                                  body: ["regions": regions, "targetMarketShare": targetShare])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Analyze creator economy health
    func analyzeCreatorEconomy(metrics: [String: Any]) async throws -> [String: Any] {
        let data = try await call(service: "creator-economy-service", endpoint: "/analyze",
                                  body: ["metrics": metrics])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Generate investor update
    func generateInvestorUpdate(metrics: [String: Any], period: String) async throws -> [String: Any] {
        let data = try await call(service: "investor-narrative-service", endpoint: "/update",
                                  body: ["metrics": metrics, "period": period])
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
