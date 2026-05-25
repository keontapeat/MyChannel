//
//  DeveloperAnalyticsService.swift
//  MyChannel
//
//  Phase 220: Developer platform analytics — API usage, SDK metrics,
//  error rates, latency percentiles. Uses `analytics-predictor-ai` Cloud Run.
//

import Foundation

struct APIUsageMetric: Codable, Identifiable {
    let id: String
    let endpoint: String
    let method: String
    let callCount: Int
    let errorCount: Int
    let avgLatencyMs: Double
    let p99LatencyMs: Double
    let period: String
}

struct SDKMetric: Codable, Identifiable {
    let id: String
    let sdkVersion: String
    let platform: String
    let activeInstalls: Int
    let crashRate: Double
    let adoptionRate: Double
}

@MainActor
final class DeveloperAnalyticsService: ObservableObject {
    static let shared = DeveloperAnalyticsService()
    private init() {}
    @Published private(set) var apiMetrics: [APIUsageMetric] = []
    @Published private(set) var sdkMetrics: [SDKMetric] = []

    func fetchAPIMetrics(period: String = "7d") async throws {
        struct Req: Encodable { let task: String; let period: String }
        struct RawM: Decodable { let id: String; let endpoint: String; let method: String; let calls: Int; let errors: Int; let avg: Double; let p99: Double }
        struct Raw: Decodable { let metrics: [RawM]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_api_metrics", period: period))
        apiMetrics = (r.metrics ?? []).map { APIUsageMetric(id: $0.id, endpoint: $0.endpoint, method: $0.method, callCount: $0.calls, errorCount: $0.errors, avgLatencyMs: $0.avg, p99LatencyMs: $0.p99, period: period) }
    }

    func fetchSDKMetrics() async throws {
        struct Req: Encodable { let task: String }
        struct RawS: Decodable { let id: String; let version: String; let platform: String; let installs: Int; let crashes: Double; let adoption: Double }
        struct Raw: Decodable { let sdks: [RawS]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_sdk_metrics"))
        sdkMetrics = (r.sdks ?? []).map { SDKMetric(id: $0.id, sdkVersion: $0.version, platform: $0.platform, activeInstalls: $0.installs, crashRate: $0.crashes, adoptionRate: $0.adoption) }
    }

    func logAPICall(endpoint: String, method: String, latencyMs: Double, isError: Bool) {
        struct Req: Encodable { let task: String; let endpoint: String; let method: String; let latency: Double; let error: Bool }
        struct RawAck: Decodable { let ok: Bool? }
        Task {
            let _: RawAck? = try? await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "log_api_call", endpoint: endpoint, method: method, latency: latencyMs, error: isError))
        }
    }
}
