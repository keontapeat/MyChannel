//
//  RealTimeTrendDetectorService.swift
//  MyChannel
//
//  Real-time trend detection: spike detection, emerging topics,
//  geographic trend mapping. Uses `analytics-predictor-ai` Cloud Run.
//

import Foundation

struct TrendSignal: Codable, Identifiable {
    let id: String
    let topic: String
    let velocity: Double
    let volume: Int
    let geographicSpread: [String]
    let firstDetectedAt: Date
    let isEmerging: Bool
    let relatedTopics: [String]
}

struct TrendReport: Codable {
    let period: String
    let topTrends: [TrendSignal]
    let decliningTopics: [String]
    let regionalHighlights: [String: [String]]
}

@MainActor
final class RealTimeTrendDetectorService: ObservableObject {
    static let shared = RealTimeTrendDetectorService()
    private init() {}
    @Published private(set) var trends: [TrendSignal] = []

    func detectTrends(region: String = "global") async throws {
        struct Req: Encodable { let task: String; let region: String }
        struct RawT: Decodable { let id: String; let topic: String; let velocity: Double; let volume: Int; let geo: [String]?; let first: String?; let emerging: Bool; let related: [String]? }
        struct Raw: Decodable { let trends: [RawT]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "detect_trends", region: region))
        trends = (r.trends ?? []).map {
            TrendSignal(id: $0.id, topic: $0.topic, velocity: $0.velocity, volume: $0.volume,
                geographicSpread: $0.geo ?? [], firstDetectedAt: $0.first.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(),
                isEmerging: $0.emerging, relatedTopics: $0.related ?? [])
        }
    }

    func fetchReport(period: String = "24h") async throws -> TrendReport {
        struct Req: Encodable { let task: String; let period: String }
        struct RawT: Decodable { let id: String; let topic: String; let velocity: Double; let volume: Int; let geo: [String]?; let first: String?; let emerging: Bool; let related: [String]? }
        struct Raw: Decodable { let trends: [RawT]?; let declining: [String]?; let regional: [String: [String]]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_trend_report", period: period))
        return TrendReport(period: period,
            topTrends: (r.trends ?? []).map { TrendSignal(id: $0.id, topic: $0.topic, velocity: $0.velocity, volume: $0.volume,
                geographicSpread: $0.geo ?? [], firstDetectedAt: $0.first.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(),
                isEmerging: $0.emerging, relatedTopics: $0.related ?? []) },
            decliningTopics: r.declining ?? [], regionalHighlights: r.regional ?? [:])
    }
}
