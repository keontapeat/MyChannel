//
//  SessionGraphRecommenderService.swift
//  MyChannel
//
//  Phase 111: Session Graph Recommender.
//  Blends short-term intent with long-term taste, novelty controls,
//  repeat-suppression. Uses `recommendations` + `hyper-personalization-ai`.
//

import Foundation

// MARK: - Models

struct SessionNode: Codable {
    let videoId: String
    let watchDurationSec: Double
    let engagement: Double   // 0–1 (likes, comments, shares normalized)
    let timestamp: Date
}

struct SessionRecommendationSlot: Codable, Identifiable {
    let id: String           // videoId
    let score: Double
    let reason: SessionRecommendationReason
}

enum SessionRecommendationReason: String, Codable {
    case sessionContinuity, longTermTaste, trending, novelty, socialProof, editorial
}

struct RecommenderConfig: Codable {
    var noveltyWeight: Double    // 0–1
    var repeatSuppressionDays: Int
    var maxPerCreator: Int       // diversity cap
}

// MARK: - Service

@MainActor
final class SessionGraphRecommenderService: ObservableObject {
    static let shared = SessionGraphRecommenderService()
    private init() {}

    @Published private(set) var recommendations: [SessionRecommendationSlot] = []
    private var sessionNodes: [SessionNode] = []
    private var seenVideoIds: Set<String> = []

    var config = RecommenderConfig(noveltyWeight: 0.3, repeatSuppressionDays: 14, maxPerCreator: 3)

    // MARK: - Session tracking

    func recordWatch(videoId: String, durationSec: Double, engagement: Double) {
        guard AppConfig.Features.enableSessionGraphRecommender else { return }
        let node = SessionNode(videoId: videoId, watchDurationSec: durationSec, engagement: engagement, timestamp: Date())
        sessionNodes.append(node)
        seenVideoIds.insert(videoId)
        if sessionNodes.count > 100 { sessionNodes.removeFirst() }
    }

    // MARK: - Recommend

    func recommend(userId: String, count: Int = 20) async throws {
        guard AppConfig.Features.enableSessionGraphRecommender else { return }
        struct NodePayload: Encodable { let videoId: String; let watch: Double; let engagement: Double }
        struct Request: Encodable {
            let task: String
            let userId: String
            let sessionNodes: [NodePayload]
            let seenIds: [String]
            let noveltyWeight: Double
            let repeatSuppressionDays: Int
            let maxPerCreator: Int
            let count: Int
        }
        struct RawSlot: Decodable { let video_id: String; let score: Double; let reason: String? }
        struct Raw: Decodable { let slots: [RawSlot]? }

        let payload = sessionNodes.suffix(20).map {
            NodePayload(videoId: $0.videoId, watch: $0.watchDurationSec, engagement: $0.engagement)
        }
        let r: Raw = try await CloudRunAgentRouter.post(
            .recommendations,
            path: "/predict",
            body: Request(
                task: "session_graph_recommend",
                userId: userId,
                sessionNodes: payload,
                seenIds: Array(seenVideoIds),
                noveltyWeight: config.noveltyWeight,
                repeatSuppressionDays: config.repeatSuppressionDays,
                maxPerCreator: config.maxPerCreator,
                count: count
            )
        )
        recommendations = (r.slots ?? []).map {
            SessionRecommendationSlot(id: $0.video_id, score: $0.score, reason: SessionRecommendationReason(rawValue: $0.reason ?? "") ?? .sessionContinuity)
        }
    }

    func clearSession() {
        sessionNodes.removeAll()
        seenVideoIds.removeAll()
        recommendations.removeAll()
    }
}
