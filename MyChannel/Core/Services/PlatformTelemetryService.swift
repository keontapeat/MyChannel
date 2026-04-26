//
//  PlatformTelemetryService.swift
//  MyChannel
//
//  Phase 180: Platform Telemetry & Observability.
//  Distributed tracing, SLO dashboards, anomaly detection.
//  Uses `auto-scaler` Cloud Run.
//

import Foundation

// MARK: - Models

struct TelemetryTraceSpan: Codable, Identifiable {
    let id: String
    let traceId: String
    let parentSpanId: String?
    let operationName: String
    let service: String
    let durationMs: Int
    let status: SpanStatus
    let startTime: Date
}

enum SpanStatus: String, Codable { case ok, error, timeout }

struct SLOMetric: Codable, Identifiable {
    let id: String
    let name: String
    let target: Double
    let current: Double
    let isHealthy: Bool
    let errorBudgetRemaining: Double
}

struct AnomalyAlert: Codable, Identifiable {
    let id: String
    let metric: String
    let severity: String
    let currentValue: Double
    let expectedRange: String
    let detectedAt: Date
    let autoResolved: Bool
}

// MARK: - Service

@MainActor
final class PlatformTelemetryService: ObservableObject {
    static let shared = PlatformTelemetryService()
    private init() {}

    @Published private(set) var sloMetrics: [SLOMetric] = []
    @Published private(set) var anomalies: [AnomalyAlert] = []
    @Published private(set) var recentTraces: [TelemetryTraceSpan] = []

    func loadSLOs() async throws {
        guard AppConfig.Features.enablePlatformTelemetry else { return }
        struct Request: Encodable { let task: String }
        struct RawSLO: Decodable { let name: String; let target: Double; let current: Double; let healthy: Bool; let budget: Double }
        struct Raw: Decodable { let slos: [RawSLO]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .autoScaler, path: "/predict",
            body: Request(task: "slo_dashboard")
        )
        sloMetrics = (r.slos ?? []).map {
            SLOMetric(id: UUID().uuidString, name: $0.name, target: $0.target,
                     current: $0.current, isHealthy: $0.healthy, errorBudgetRemaining: $0.budget)
        }
    }

    func detectAnomalies() async throws {
        guard AppConfig.Features.enablePlatformTelemetry else { return }
        struct Request: Encodable { let task: String }
        struct RawAnomaly: Decodable { let metric: String; let severity: String; let value: Double; let range: String; let auto_resolved: Bool }
        struct Raw: Decodable { let anomalies: [RawAnomaly]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .autoScaler, path: "/predict",
            body: Request(task: "detect_anomalies")
        )
        anomalies = (r.anomalies ?? []).map {
            AnomalyAlert(id: UUID().uuidString, metric: $0.metric, severity: $0.severity,
                        currentValue: $0.value, expectedRange: $0.range, detectedAt: Date(),
                        autoResolved: $0.auto_resolved)
        }
    }

    func traceRequest(operationName: String, service: String) -> String {
        guard AppConfig.Features.enablePlatformTelemetry else { return "" }
        let traceId = UUID().uuidString
        let span = TelemetryTraceSpan(id: UUID().uuidString, traceId: traceId, parentSpanId: nil,
                            operationName: operationName, service: service,
                            durationMs: 0, status: .ok, startTime: Date())
        recentTraces.append(span)
        if recentTraces.count > 100 { recentTraces.removeFirst(50) }
        return traceId
    }

    func endTrace(traceId: String, durationMs: Int, status: SpanStatus) {
        if let idx = recentTraces.firstIndex(where: { $0.traceId == traceId }) {
            let old = recentTraces[idx]
            recentTraces[idx] = TelemetryTraceSpan(id: old.id, traceId: old.traceId, parentSpanId: old.parentSpanId,
                                         operationName: old.operationName, service: old.service,
                                         durationMs: durationMs, status: status, startTime: old.startTime)
        }
    }
}
