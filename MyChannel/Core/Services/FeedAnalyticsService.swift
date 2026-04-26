//
//  FeedAnalyticsService.swift
//  MyChannel
//
//  Phase 278: Feed Analytics & Telemetry — scroll depth, impressions,
//  CTR, dwell time, feed health metrics.
//  Uses `analytics-predictor-ai` Cloud Run.
//

import Foundation

struct FeedMetric: Codable, Identifiable {
    let id: String
    let name: String
    let value: Double
    let timestamp: Date
}

@MainActor
final class FeedAnalyticsService: ObservableObject {
    static let shared = FeedAnalyticsService()
    private init() {}

    @Published private(set) var metrics: [FeedMetric] = []

    func track(name: String, value: Double) {
        guard AppConfig.Features.enableFeedAnalytics else { return }
        metrics.append(FeedMetric(id: UUID().uuidString, name: name, value: value, timestamp: Date()))
        if metrics.count > 500 { metrics = Array(metrics.suffix(250)) }
    }

    func flush() async throws {
        struct Req: Encodable { let task: String; let count: Int }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict", body: Req(task: "flush_feed_metrics", count: metrics.count))
    }
}
