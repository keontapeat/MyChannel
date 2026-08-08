//
//  CreatorIntelligenceService.swift
//  MyChannel
//
//  Unified facade for creator-facing AI capabilities.
//  Prefer this over UnifiedAGIBrain / SuperAGI for new call sites.
//

import Foundation

// MARK: - Result types

struct OptimizedVideoMetadata: Sendable {
    let title: String
    let description: String
    let tags: [String]
}

struct EngagementScore: Sendable {
    let videoId: String
    let score: Double
    let performanceScore: Double?
    let engagementScore: Double?
    let source: String
}

struct CreatorActionRecommendation: Sendable {
    let title: String
    let actionItem: String
    let priority: String
    let predictedImpact: String
}

struct SearchAssistResult: Sendable {
    let processedTerms: [String]
    let intent: String?
    let summary: String
}

enum CreatorIntelligenceError: LocalizedError {
    case disabled
    case expensiveAgentsDisabled
    case notImplemented(String)
    case timeout(String)
    case circuitOpen

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "AI is disabled (AppConfig.aiEnabled = false)"
        case .expensiveAgentsDisabled:
            return "Expensive AI agents are disabled (AppConfig.Features.enableExpensiveAIAgents)"
        case .notImplemented(let feature):
            return "\(feature) is not wired yet — TODO"
        case .timeout(let operation):
            return "\(operation) timed out after \(Int(AppConfig.AI.requestTimeoutSeconds))s"
        case .circuitOpen:
            return "AI circuit breaker is open — too many recent failures"
        }
    }
}

// MARK: - Circuit breaker (stub)

/// Lightweight circuit breaker state for outbound AI calls.
/// Opens after repeated failures; auto-resets after a cooldown window.
enum CreatorIntelligenceCircuitState: Sendable, Equatable {
    case closed
    case open(until: Date)
    case halfOpen
}

// MARK: - Facade

/// Thin wrapper over existing AI services. Gates all work behind `AppConfig.aiEnabled`.
// MARK: - Telemetry (latency + estimated cost)

struct AITelemetryEvent: Sendable {
    let operation: String
    let latencyMs: Int
    let estimatedCostUSD: Double
    let sampled: Bool
}

@MainActor
final class CreatorIntelligenceService: ObservableObject {
    static let shared = CreatorIntelligenceService()

    private let myChannelAI = MyChannelAI.shared
    private let openAI = OpenAIService.shared
    private let agentAPI = AgentAPIService.shared
    private let contentOptimizer = CreatorContentOptimizationService.shared
    private let predictiveEngagement = PredictiveEngagementService.shared
    private let conversationalSearch = ConversationalSearchService.shared
    private let creatorSuccess = CreatorSuccessAIService.shared
    private let queryProcessor = QueryProcessor()

    private var circuitState: CreatorIntelligenceCircuitState = .closed
    private var consecutiveFailures = 0
    private static let maxFailuresBeforeOpen = 3
    private static let circuitOpenDuration: TimeInterval = 60

    /// Last recorded telemetry sample (for debug overlays / unit tests).
    private(set) var lastTelemetry: AITelemetryEvent?

    private init() {}

    /// User opt-out of on-device training data collection (Settings toggle).
    static var isTrainingOptedOut: Bool {
        UserDefaults.standard.bool(forKey: AppConfig.AI.trainingOptOutKey)
    }

    private func shouldSampleLog() -> Bool {
        Double.random(in: 0..<1) < AppConfig.AI.logSampleRate
    }

    private func recordTelemetry(operation: String, started: Date, estimatedCostUSD: Double = 0) {
        let latencyMs = Int(Date().timeIntervalSince(started) * 1000)
        let sampled = shouldSampleLog()
        lastTelemetry = AITelemetryEvent(
            operation: operation,
            latencyMs: latencyMs,
            estimatedCostUSD: estimatedCostUSD,
            sampled: sampled
        )
        if sampled {
            print("📊 [AI] \(operation) \(latencyMs)ms ~$\(String(format: "%.4f", estimatedCostUSD))")
        }
    }

    /// Fallback stub when AI is down, disabled, or circuit is open.
    private func fallbackStub(operation: String) -> AIResponse {
        AIResponse(
            text: "[\(operation)] AI temporarily unavailable — try again shortly.",
            confidence: 0,
            modelUsed: "CreatorIntelligenceStub",
            inferenceTime: 0,
            generatedAt: Date()
        )
    }

    // MARK: - Environment gates

    /// UITests pass `-UITests` or set `UITEST_DISABLE_AI=1` to avoid live AI calls.
    private var isUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITests")
            || ProcessInfo.processInfo.environment["UITEST_DISABLE_AI"] == "1"
    }

    private func assertAIEnabled() throws {
        if isUITest { throw CreatorIntelligenceError.disabled }
        guard AppConfig.aiEnabled else { throw CreatorIntelligenceError.disabled }
    }

    private func assertExpensiveAgentsEnabled() throws {
        try assertAIEnabled()
        guard AppConfig.Features.enableExpensiveAIAgents else {
            throw CreatorIntelligenceError.expensiveAgentsDisabled
        }
    }

    // MARK: - Circuit breaker (stub)

    private func assertCircuitClosed() throws {
        switch circuitState {
        case .closed, .halfOpen:
            return
        case .open(let until):
            if Date() >= until {
                circuitState = .halfOpen
                return
            }
            throw CreatorIntelligenceError.circuitOpen
        }
    }

    private func recordSuccess() {
        consecutiveFailures = 0
        circuitState = .closed
    }

    private func recordFailure() {
        consecutiveFailures += 1
        if consecutiveFailures >= Self.maxFailuresBeforeOpen {
            circuitState = .open(until: Date().addingTimeInterval(Self.circuitOpenDuration))
        }
    }

    // MARK: - Timeout + retry wrapper (8s / 1 retry)

    private func withTimeoutAndRetry<T>(
        operation: String,
        _ work: @escaping () async throws -> T
    ) async throws -> T {
        try assertCircuitClosed()

        var lastError: Error?
        let maxAttempts = 1 + AppConfig.AI.maxRetries

        for attempt in 0..<maxAttempts {
            do {
                let result = try await withThrowingTaskGroup(of: T.self) { group in
                    group.addTask { try await work() }
                    group.addTask {
                        try await Task.sleep(
                            nanoseconds: UInt64(AppConfig.AI.requestTimeoutSeconds * 1_000_000_000)
                        )
                        throw CreatorIntelligenceError.timeout(operation)
                    }
                    guard let first = try await group.next() else {
                        throw CreatorIntelligenceError.timeout(operation)
                    }
                    group.cancelAll()
                    return first
                }
                recordSuccess()
                return result
            } catch {
                lastError = error
                recordFailure()
                if attempt < maxAttempts - 1 { continue }
            }
        }
        throw lastError ?? CreatorIntelligenceError.timeout(operation)
    }

    // MARK: - Public API

    /// Generate text via MyChannelAI (teacher ensemble when model is still learning).
    func generate(prompt: String, context: AIContext? = nil) async throws -> AIResponse {
        try assertAIEnabled()
        let started = Date()
        do {
            let response = try await withTimeoutAndRetry(operation: "generate") {
                try await self.myChannelAI.generate(prompt: prompt, context: context)
            }
            recordTelemetry(operation: "generate", started: started, estimatedCostUSD: AppConfig.AI.apiCostBudgetPerAgentUSD * 0.25)
            return response
        } catch CreatorIntelligenceError.circuitOpen {
            return fallbackStub(operation: "generate")
        }
    }

    /// Optimize title, description, and tags for a video upload.
    func optimizeVideoMetadata(
        title: String,
        description: String
    ) async throws -> OptimizedVideoMetadata {
        try assertExpensiveAgentsEnabled()
        let result = try await withTimeoutAndRetry(operation: "optimizeVideoMetadata") {
            try await self.openAI.optimizeForSEO(title: title, description: description)
        }
        return OptimizedVideoMetadata(
            title: result.title,
            description: result.description,
            tags: result.tags
        )
    }

    /// Score engagement for a published video (ML content analysis when available).
    func scoreEngagement(videoId: String, creatorId: String) async throws -> EngagementScore {
        try assertExpensiveAgentsEnabled()
        let analysis = try await withTimeoutAndRetry(operation: "scoreEngagement") {
            try await self.contentOptimizer.analyzeContent(
                videoId: videoId,
                creatorId: creatorId
            )
        }
        return EngagementScore(
            videoId: videoId,
            score: analysis.engagementScore,
            performanceScore: analysis.performanceScore,
            engagementScore: analysis.engagementScore,
            source: "CreatorContentOptimizationService"
        )
    }

    /// Moderate uploaded content via safety agents.
    func moderateContent(
        videoId: String,
        metadata: VertexVideoMetadata,
        transcript: String?
    ) async throws -> CPSTriageResponse {
        try assertAIEnabled()
        return try await withTimeoutAndRetry(operation: "moderateContent") {
            try await self.agentAPI.moderateContent(
                videoId: videoId,
                metadata: metadata,
                transcript: transcript
            )
        }
    }

    /// Assist search: NL query parsing + optional conversational follow-up.
    func assistSearch(query: String, userId: String?) async throws -> SearchAssistResult {
        try assertAIEnabled()
        let processed = await queryProcessor.processNaturalLanguageQuery(query)

        if AppConfig.Features.enableConversationalSearch, let userId {
            let reply = try await withTimeoutAndRetry(operation: "assistSearch") {
                try await self.conversationalSearch.ask(query, userId: userId)
            }
            return SearchAssistResult(
                processedTerms: processed.terms,
                intent: processed.intent.map { String(describing: $0) },
                summary: reply.text
            )
        }

        return SearchAssistResult(
            processedTerms: processed.terms,
            intent: processed.intent.map { String(describing: $0) },
            summary: processed.searchTerms
        )
    }

    /// Recommend the highest-priority creator growth action.
    func recommendCreatorAction(creatorUid: String) async throws -> CreatorActionRecommendation {
        try assertExpensiveAgentsEnabled()
        if AppConfig.Features.enableCreatorSuccessAI {
            try await withTimeoutAndRetry(operation: "recommendCreatorAction") {
                try await self.creatorSuccess.fetchInsights(creatorUid: creatorUid)
            }
            if let top = creatorSuccess.insights.first {
                return CreatorActionRecommendation(
                    title: top.title,
                    actionItem: top.actionItem,
                    priority: top.priority,
                    predictedImpact: top.predictedImpact
                )
            }
        }

        // Fallback: engagement window from analytics predictor when success AI is off.
        let window = try await withTimeoutAndRetry(operation: "recommendCreatorAction") {
            try await self.predictiveEngagement.fetchEngagementWindow(userId: creatorUid)
        }
        let action = window.likelyOnline
            ? "Post while your audience is active (peak hour \(window.peakHour):00)"
            : "Schedule your next upload for peak hour \(window.peakHour):00"
        return CreatorActionRecommendation(
            title: "Engagement timing",
            actionItem: action,
            priority: "medium",
            predictedImpact: "Improved first-hour views"
        )
    }

    /// Identify underserved content gaps in a given niche using AI research signals.
    func analyzeContentGaps(niche: String) async -> [String] {
        guard !niche.isEmpty else { return [] }
        let prompt = "List 5 underserved content gaps for a '\(niche)' creator channel. Be specific and actionable. Return as a numbered list."
        if let response = try? await generate(prompt: prompt) {
            let lines = response.text
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(8)
            return Array(lines)
        }
        // Fallback suggestions when AI is unavailable
        return [
            "Beginner's guide series for '\(niche)' newcomers",
            "Behind-the-scenes content that competitors don't show",
            "Tool/gear comparisons at different budget tiers",
            "Common mistakes and how to avoid them",
            "Trending '\(niche)' news with your unique analysis",
        ]
    }
}
