//
//  AlgorithmControlsService.swift
//  MyChannel
//
//  Phase 236: Algorithm Controls & User Tuning.
//  User-adjustable feed preferences, recommendation explainability,
//  ranking transparency controls.
//  Uses `recommendations` + `top-rank-ml` Cloud Run.
//

import Foundation

// MARK: - Models

struct FeedPreference: Codable, Identifiable {
    let id: String
    let userId: String
    let category: String
    let weight: Double
    let isExplicit: Bool
    let updatedAt: Date
}

struct RankingExplanation: Codable, Identifiable {
    let id: String
    let videoId: String
    let userId: String
    let factors: [RankingFactor]
    let overallScore: Double

    struct RankingFactor: Codable {
        let name: String
        let contribution: Double
        let description: String
    }
}

struct TransparencyReport: Codable {
    let userId: String
    let algorithmVersion: String
    let personalizationLevel: Double
    let diversityScore: Double
    let serendipityRate: Double
    let lastUpdated: Date
}

// MARK: - Service

@MainActor
final class AlgorithmControlsService: ObservableObject {
    static let shared = AlgorithmControlsService()
    private init() {}

    @Published private(set) var preferences: [FeedPreference] = []
    @Published private(set) var explanation: RankingExplanation?
    @Published private(set) var transparency: TransparencyReport?

    func fetchPreferences(userId: String) async throws {
        guard AppConfig.Features.enableAlgorithmControls else { return }
        struct Req: Encodable { let task: String; let userId: String }
        struct RawPref: Decodable { let id: String; let category: String; let weight: Double; let explicit: Bool; let updated: String? }
        struct Raw: Decodable { let preferences: [RawPref]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .recommendations, path: "/predict",
            body: Req(task: "fetch_preferences", userId: userId)
        )
        preferences = (r.preferences ?? []).map {
            FeedPreference(id: $0.id, userId: userId, category: $0.category, weight: $0.weight,
                           isExplicit: $0.explicit,
                           updatedAt: $0.updated.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date())
        }
    }

    func updatePreference(userId: String, category: String, weight: Double) async throws {
        guard AppConfig.Features.enableAlgorithmControls else { return }
        struct Req: Encodable { let task: String; let userId: String; let category: String; let weight: Double }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .recommendations, path: "/predict",
            body: Req(task: "update_preference", userId: userId, category: category, weight: weight)
        )
        let pref = FeedPreference(id: r.id, userId: userId, category: category, weight: weight, isExplicit: true, updatedAt: Date())
        if let idx = preferences.firstIndex(where: { $0.category == category }) {
            preferences[idx] = pref
        } else {
            preferences.append(pref)
        }
    }

    func explainRanking(videoId: String, userId: String) async throws {
        guard AppConfig.Features.enableAlgorithmControls else { return }
        struct Req: Encodable { let task: String; let videoId: String; let userId: String }
        struct RawFactor: Decodable { let name: String; let contribution: Double; let desc: String }
        struct Raw: Decodable { let id: String; let factors: [RawFactor]?; let score: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .topRankML, path: "/predict",
            body: Req(task: "explain_ranking", videoId: videoId, userId: userId), timeout: 15
        )
        explanation = RankingExplanation(id: r.id, videoId: videoId, userId: userId,
                                           factors: (r.factors ?? []).map { RankingExplanation.RankingFactor(name: $0.name, contribution: $0.contribution, description: $0.desc) },
                                           overallScore: r.score ?? 0)
    }

    func fetchTransparency(userId: String) async throws {
        guard AppConfig.Features.enableAlgorithmControls else { return }
        struct Req: Encodable { let task: String; let userId: String }
        struct Raw: Decodable { let version: String?; let personalization: Double?; let diversity: Double?; let serendipity: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .topRankML, path: "/predict",
            body: Req(task: "transparency_report", userId: userId)
        )
        transparency = TransparencyReport(userId: userId, algorithmVersion: r.version ?? "v1",
                                            personalizationLevel: r.personalization ?? 0, diversityScore: r.diversity ?? 0,
                                            serendipityRate: r.serendipity ?? 0, lastUpdated: Date())
    }
}
