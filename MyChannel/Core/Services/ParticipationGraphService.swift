//
//  ParticipationGraphService.swift
//  MyChannel
//
//  Phase 235: Real-Time Participation Graph.
//  Unified event stream for chat, reactions, polls, purchases,
//  overlays, and live ranking inputs.
//  Uses `engagement-booster-ai` + `analytics-predictor-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct ParticipationEvent: Codable, Identifiable {
    let id: String
    let streamId: String
    let userId: String
    let type: ParticipationType
    let payload: String
    let timestamp: Date

    enum ParticipationType: String, Codable {
        case chat, reaction, poll, purchase, overlay, ranking
    }
}

struct ParticipationAggregate: Codable {
    let streamId: String
    let totalEvents: Int
    let uniqueParticipants: Int
    let byType: [String: Int]
    let peakMoment: String?
    let peakCount: Int
}

struct LiveRanking: Codable, Identifiable {
    let id: String
    let streamId: String
    let userId: String
    let displayName: String
    let score: Int
    let rank: Int
}

// MARK: - Service

@MainActor
final class ParticipationGraphService: ObservableObject {
    static let shared = ParticipationGraphService()
    private init() {}

    @Published private(set) var events: [ParticipationEvent] = []
    @Published private(set) var aggregate: ParticipationAggregate?
    @Published private(set) var rankings: [LiveRanking] = []

    func emitEvent(streamId: String, userId: String, type: ParticipationEvent.ParticipationType, payload: String) async throws {
        guard AppConfig.Features.enableParticipationGraph else { return }
        struct Req: Encodable { let task: String; let streamId: String; let userId: String; let type: String; let payload: String }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .engagementBooster, path: "/predict",
            body: Req(task: "emit_event", streamId: streamId, userId: userId, type: type.rawValue, payload: payload)
        )
        let event = ParticipationEvent(id: r.id, streamId: streamId, userId: userId, type: type, payload: payload, timestamp: Date())
        events.append(event)
        if events.count > 500 { events = Array(events.suffix(200)) }
    }

    func fetchAggregate(streamId: String) async throws {
        guard AppConfig.Features.enableParticipationGraph else { return }
        struct Req: Encodable { let task: String; let streamId: String }
        struct Raw: Decodable { let total: Int?; let unique: Int?; let by_type: [String: Int]?; let peak_moment: String?; let peak_count: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .analyticsPredictor, path: "/predict",
            body: Req(task: "participation_aggregate", streamId: streamId)
        )
        aggregate = ParticipationAggregate(streamId: streamId, totalEvents: r.total ?? 0, uniqueParticipants: r.unique ?? 0,
                                             byType: r.by_type ?? [:], peakMoment: r.peak_moment, peakCount: r.peak_count ?? 0)
    }

    func fetchRankings(streamId: String) async throws {
        guard AppConfig.Features.enableParticipationGraph else { return }
        struct Req: Encodable { let task: String; let streamId: String }
        struct RawRank: Decodable { let id: String; let userId: String; let name: String; let score: Int; let rank: Int }
        struct Raw: Decodable { let rankings: [RawRank]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .engagementBooster, path: "/predict",
            body: Req(task: "fetch_rankings", streamId: streamId)
        )
        rankings = (r.rankings ?? []).map {
            LiveRanking(id: $0.id, streamId: streamId, userId: $0.userId, displayName: $0.name, score: $0.score, rank: $0.rank)
        }
    }
}
