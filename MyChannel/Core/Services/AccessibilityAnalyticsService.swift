//
//  AccessibilityAnalyticsService.swift
//  MyChannel
//
//  Accessibility usage analytics: feature adoption, barrier detection,
//  compliance scoring. Uses `analytics-predictor-ai` Cloud Run.
//

import Foundation

struct AccessibilityUsageMetric: Codable, Identifiable {
    let id: String
    let feature: String
    let usageCount: Int
    let uniqueUsers: Int
    let avgSessionDuration: Double
    let period: String
}

struct AccessibilityBarrier: Codable, Identifiable {
    let id: String
    let screen: String
    let element: String
    let issueType: String
    let severity: String
    let occurrences: Int
    let firstSeen: Date
    let lastSeen: Date
}

@MainActor
final class AccessibilityAnalyticsService: ObservableObject {
    static let shared = AccessibilityAnalyticsService()
    private init() {}
    @Published private(set) var metrics: [AccessibilityUsageMetric] = []
    @Published private(set) var barriers: [AccessibilityBarrier] = []

    func fetchMetrics(period: String = "30d") async throws {
        struct Req: Encodable { let task: String; let period: String }
        struct RawM: Decodable { let id: String; let feature: String; let count: Int; let users: Int; let duration: Double }
        struct Raw: Decodable { let metrics: [RawM]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_accessibility_metrics", period: period))
        metrics = (r.metrics ?? []).map { AccessibilityUsageMetric(id: $0.id, feature: $0.feature, usageCount: $0.count, uniqueUsers: $0.users, avgSessionDuration: $0.duration, period: period) }
    }

    func fetchBarriers() async throws {
        struct Req: Encodable { let task: String }
        struct RawB: Decodable { let id: String; let screen: String; let element: String; let type: String; let severity: String; let occurrences: Int; let first: String?; let last: String? }
        struct Raw: Decodable { let barriers: [RawB]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_accessibility_barriers"))
        barriers = (r.barriers ?? []).map {
            AccessibilityBarrier(id: $0.id, screen: $0.screen, element: $0.element, issueType: $0.type, severity: $0.severity,
                occurrences: $0.occurrences, firstSeen: $0.first.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(),
                lastSeen: $0.last.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date())
        }
    }

    func reportBarrier(screen: String, element: String, issueType: String, severity: String) async throws {
        struct Req: Encodable { let task: String; let screen: String; let element: String; let type: String; let severity: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "report_accessibility_barrier", screen: screen, element: element, type: issueType, severity: severity))
    }
}
