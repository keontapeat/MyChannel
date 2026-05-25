//
//  AnomalyDetectionService.swift
//  MyChannel
//
//  Phase 205: Anomaly Detection Dashboard.
//  Metric anomalies, revenue spikes, traffic pattern alerts.
//  Uses `auto-scaler` Cloud Run.
//

import Foundation

struct MetricAnomaly: Codable, Identifiable {
    let id: String
    let metric: String
    let expectedValue: Double
    let actualValue: Double
    let deviationPercent: Double
    let severity: AnomalySeverity
    let description: String
    let detectedAt: Date
    let isAcknowledged: Bool
    enum AnomalySeverity: String, Codable { case low, medium, high, critical }
}

struct AnomalyThreshold: Codable {
    let metric: String
    let warningPct: Double
    let criticalPct: Double
    let windowMinutes: Int
}

@MainActor
final class AnomalyDetectionService: ObservableObject {
    static let shared = AnomalyDetectionService()
    private init() {}
    @Published private(set) var anomalies: [MetricAnomaly] = []
    @Published private(set) var thresholds: [AnomalyThreshold] = []
    @Published private(set) var isMonitoring: Bool = false

    func checkAnomalies() async throws {
        struct Req: Encodable { let task: String }
        struct RawA: Decodable { let metric: String; let expected: Double; let actual: Double; let deviation: Double; let severity: String; let desc: String }
        struct Raw: Decodable { let anomalies: [RawA]? }
        let r: Raw = try await CloudRunAgentRouter.post(.autoScaler, path: "/predict", body: Req(task: "detect_anomalies"))
        anomalies = (r.anomalies ?? []).map {
            MetricAnomaly(id: UUID().uuidString, metric: $0.metric, expectedValue: $0.expected, actualValue: $0.actual,
                deviationPercent: $0.deviation, severity: .init(rawValue: $0.severity) ?? .medium, description: $0.desc, detectedAt: Date(), isAcknowledged: false)
        }
    }

    func fetchThresholds() async throws {
        struct Req: Encodable { let task: String }
        struct RawT: Decodable { let metric: String; let warning: Double; let critical: Double; let window: Int }
        struct Raw: Decodable { let thresholds: [RawT]? }
        let r: Raw = try await CloudRunAgentRouter.post(.autoScaler, path: "/predict", body: Req(task: "fetch_anomaly_thresholds"))
        thresholds = (r.thresholds ?? []).map { AnomalyThreshold(metric: $0.metric, warningPct: $0.warning, criticalPct: $0.critical, windowMinutes: $0.window) }
    }

    func updateThreshold(metric: String, warning: Double, critical: Double, window: Int) async throws {
        struct Req: Encodable { let task: String; let metric: String; let warning: Double; let critical: Double; let window: Int }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.autoScaler, path: "/predict",
            body: Req(task: "update_anomaly_threshold", metric: metric, warning: warning, critical: critical, window: window))
        if let idx = thresholds.firstIndex(where: { $0.metric == metric }) {
            thresholds[idx] = AnomalyThreshold(metric: metric, warningPct: warning, criticalPct: critical, windowMinutes: window)
        }
    }

    func acknowledge(anomalyId: String) {
        if let idx = anomalies.firstIndex(where: { $0.id == anomalyId }) {
            let old = anomalies[idx]
            anomalies[idx] = MetricAnomaly(id: old.id, metric: old.metric, expectedValue: old.expectedValue, actualValue: old.actualValue,
                deviationPercent: old.deviationPercent, severity: old.severity, description: old.description, detectedAt: old.detectedAt, isAcknowledged: true)
        }
    }

    func startMonitoring() { isMonitoring = true }
    func stopMonitoring() { isMonitoring = false }
}
