//
//  FeedAutopilotService.swift
//  MyChannel
//
//  Phase 112: Real-Time Feed Autopilot.
//  Per-scroll reranking, satisfaction optimization loop, drift guardrails.
//  Uses `hyper-personalization-ai` + `engagement-predictor`.
//

import Foundation

// MARK: - Models

struct FeedSlot: Codable, Identifiable {
    let id: String          // videoId
    var position: Int
    var predictedSatisfaction: Double  // 0–1
    let source: FeedSource
}

enum FeedSource: String, Codable {
    case personalized, trending, subscriptions, explore, boosted
}

struct SatisfactionSignal: Codable {
    let videoId: String
    let watchPercent: Double   // 0–1
    let liked: Bool
    let shared: Bool
    let skippedQuickly: Bool
    let timestamp: Date
}

struct DriftReport: Codable {
    let driftDetected: Bool
    let driftMagnitude: Double
    let recommendation: String
}

// MARK: - Service

@MainActor
final class FeedAutopilotService: ObservableObject {
    static let shared = FeedAutopilotService()
    private init() {}

    @Published private(set) var feedSlots: [FeedSlot] = []
    @Published private(set) var latestDrift: DriftReport?

    private var signals: [SatisfactionSignal] = []

    // MARK: - Rerank on scroll

    func rerank(currentFeed: [FeedSlot], userId: String) async throws -> [FeedSlot] {
        guard AppConfig.Features.enableFeedAutopilot else { return currentFeed }
        struct SlotPayload: Encodable { let videoId: String; let position: Int; let source: String }
        struct SignalPayload: Encodable { let videoId: String; let watchPercent: Double; let liked: Bool; let shared: Bool; let skippedQuickly: Bool }
        struct Request: Encodable {
            let task: String; let userId: String
            let slots: [SlotPayload]; let signals: [SignalPayload]
        }
        struct RawSlot: Decodable { let video_id: String; let position: Int; let satisfaction: Double; let source: String? }
        struct Raw: Decodable { let slots: [RawSlot]? }

        let r: Raw = try await CloudRunAgentRouter.post(
            .hyperPersonalization,
            path: "/predict",
            body: Request(
                task: "feed_rerank",
                userId: userId,
                slots: currentFeed.map { SlotPayload(videoId: $0.id, position: $0.position, source: $0.source.rawValue) },
                signals: signals.suffix(20).map { SignalPayload(videoId: $0.videoId, watchPercent: $0.watchPercent, liked: $0.liked, shared: $0.shared, skippedQuickly: $0.skippedQuickly) }
            )
        )
        let reranked = (r.slots ?? []).map {
            FeedSlot(id: $0.video_id, position: $0.position, predictedSatisfaction: $0.satisfaction, source: FeedSource(rawValue: $0.source ?? "") ?? .personalized)
        }
        feedSlots = reranked
        return reranked
    }

    // MARK: - Satisfaction tracking

    func recordSatisfactionSignal(_ signal: SatisfactionSignal) {
        guard AppConfig.Features.enableFeedAutopilot else { return }
        signals.append(signal)
        if signals.count > 200 { signals.removeFirst(50) }
    }

    // MARK: - Drift guardrail

    func checkDrift(userId: String) async throws {
        guard AppConfig.Features.enableFeedAutopilot else { return }
        struct Request: Encodable { let task: String; let userId: String; let signalCount: Int }
        struct Raw: Decodable { let drift_detected: Bool?; let magnitude: Double?; let recommendation: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .engagementPredictor,
            path: "/predict",
            body: Request(task: "drift_check", userId: userId, signalCount: signals.count)
        )
        latestDrift = DriftReport(
            driftDetected: r.drift_detected ?? false,
            driftMagnitude: r.magnitude ?? 0,
            recommendation: r.recommendation ?? ""
        )
    }
}
