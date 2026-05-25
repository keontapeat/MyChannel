//
//  SearchFreshnessService.swift
//  MyChannel
//
//  Phase 288: Search Freshness & Trending — recency boosting, trending detection,
//  seasonal relevance, breaking content prioritization, time-decay scoring.
//  Uses `analytics-predictor-ai` Cloud Run.
//

import Foundation

struct SearchFreshnessSignal: Codable, Identifiable {
    let id: String
    let contentId: String
    let recencyHours: Double
    let trendScore: Double
    let seasonalBoost: Double
    let finalFreshness: Double
}

@MainActor
final class SearchFreshnessService: ObservableObject {
    static let shared = SearchFreshnessService()
    private init() {}

    @Published private(set) var signals: [SearchFreshnessSignal] = []

    func evaluate(contentIds: [String], query: String) async throws {
        guard AppConfig.Features.enableSearchFreshness else { return }
        struct Req: Encodable { let task: String; let contentIds: [String]; let query: String }
        struct RawS: Decodable { let contentId: String; let recencyHours: Double; let trend: Double; let seasonal: Double; let finalFreshness: Double }
        struct Raw: Decodable { let signals: [RawS]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict", body: Req(task: "search_freshness", contentIds: contentIds, query: query))
        signals = (r.signals ?? []).map {
            SearchFreshnessSignal(id: UUID().uuidString, contentId: $0.contentId, recencyHours: $0.recencyHours, trendScore: $0.trend, seasonalBoost: $0.seasonal, finalFreshness: $0.finalFreshness)
        }
    }

    func sortByFreshness() -> [String] {
        signals.sorted { $0.finalFreshness > $1.finalFreshness }.map(\ .contentId)
    }
}
