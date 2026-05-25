//
//  SearchQualityService.swift
//  MyChannel
//
//  Phase 290: Search Quality Metrics — relevance grading, click satisfaction,
//  zero-result rate, query success rate, search NPS.
//  Uses `analytics-predictor-ai` Cloud Run.
//

import Foundation

struct SearchQualityMetric: Codable, Identifiable {
    let id: String
    let metric: String
    let value: Double
    let period: String
}

@MainActor
final class SearchQualityService: ObservableObject {
    static let shared = SearchQualityService()
    private init() {}

    @Published private(set) var metrics: [SearchQualityMetric] = []

    func fetchMetrics(period: String = "7d") async throws {
        guard AppConfig.Features.enableSearchQuality else { return }
        struct Req: Encodable { let task: String; let period: String }
        struct RawM: Decodable { let metric: String; let value: Double }
        struct Raw: Decodable { let metrics: [RawM]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict", body: Req(task: "search_quality_metrics", period: period))
        metrics = (r.metrics ?? []).map { SearchQualityMetric(id: UUID().uuidString, metric: $0.metric, value: $0.value, period: period) }
    }

    func metric(named name: String) -> Double {
        metrics.first(where: { $0.metric == name })?.value ?? 0
    }
}
