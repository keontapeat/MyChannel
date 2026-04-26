//
//  SelfHealingRuntimeService.swift
//  MyChannel
//
//  Phase 240: Self-Healing Platform Runtime.
//  Anomaly-triggered rollback, traffic shift, degraded mode UX,
//  autonomous incident containment.
//  Uses `auto-scaler` Cloud Run.
//

import Foundation

// MARK: - Models

struct AnomalyEvent: Codable, Identifiable {
    let id: String
    let type: AnomalyType
    let severity: Severity
    let description: String
    let metric: String
    let threshold: Double
    let actual: Double
    let detectedAt: Date
    let isResolved: Bool

    enum AnomalyType: String, Codable { case errorRate, latency, traffic, revenue, availability }
    enum Severity: String, Codable { case low, medium, high, critical }
}

struct HealingAction: Codable, Identifiable {
    let id: String
    let anomalyId: String
    let action: HealingActionType
    let target: String
    let status: String
    let executedAt: Date?
    let result: String?
    let requiresApproval: Bool

    enum HealingActionType: String, Codable {
        case rollback, trafficShift, degradedMode, scaleUp, restart, quarantine
    }
}

struct IncidentReport: Codable, Identifiable {
    let id: String
    let anomalyIds: [String]
    let healingActions: [String]
    let status: String
    let startedAt: Date
    let resolvedAt: Date?
    let impactSummary: String
}

// MARK: - Service

@MainActor
final class SelfHealingRuntimeService: ObservableObject {
    static let shared = SelfHealingRuntimeService()
    private init() {}

    @Published private(set) var anomalies: [AnomalyEvent] = []
    @Published private(set) var healingActions: [HealingAction] = []
    @Published private(set) var incidents: [IncidentReport] = []
    @Published private(set) var isDegraded: Bool = false

    func detectAnomalies() async throws {
        guard AppConfig.Features.enableSelfHealingRuntime else { return }
        struct Req: Encodable { let task: String }
        struct RawAnom: Decodable { let id: String; let type: String; let severity: String; let desc: String; let metric: String; let threshold: Double; let actual: Double; let detected: String?; let resolved: Bool }
        struct Raw: Decodable { let anomalies: [RawAnom]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .autoScaler, path: "/predict",
            body: Req(task: "detect_anomalies")
        )
        anomalies = (r.anomalies ?? []).map {
            AnomalyEvent(id: $0.id, type: .init(rawValue: $0.type) ?? .errorRate,
                         severity: .init(rawValue: $0.severity) ?? .medium,
                         description: $0.desc, metric: $0.metric,
                         threshold: $0.threshold, actual: $0.actual,
                         detectedAt: $0.detected.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(),
                         isResolved: $0.resolved)
        }
        isDegraded = anomalies.contains { $0.severity == .critical && !$0.isResolved }
    }

    func executeHealing(anomalyId: String, action: HealingAction.HealingActionType, target: String, requiresApproval: Bool = false) async throws -> HealingAction {
        guard AppConfig.Features.enableSelfHealingRuntime else {
            return HealingAction(id: "", anomalyId: anomalyId, action: action, target: target,
                                  status: "pending", executedAt: nil, result: nil, requiresApproval: requiresApproval)
        }
        struct Req: Encodable { let task: String; let anomalyId: String; let action: String; let target: String; let approval: Bool }
        struct Raw: Decodable { let id: String; let status: String?; let result: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .autoScaler, path: "/predict",
            body: Req(task: "execute_healing", anomalyId: anomalyId, action: action.rawValue,
                      target: target, approval: requiresApproval), timeout: 30
        )
        let healing = HealingAction(id: r.id, anomalyId: anomalyId, action: action, target: target,
                                      status: r.status ?? "executed", executedAt: Date(), result: r.result,
                                      requiresApproval: requiresApproval)
        healingActions.append(healing)
        return healing
    }

    func rollback(version: String) async throws {
        guard AppConfig.Features.enableSelfHealingRuntime else { return }
        struct Req: Encodable { let task: String; let version: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .autoScaler, path: "/predict",
            body: Req(task: "rollback", version: version), timeout: 45
        )
    }

    func shiftTraffic(from source: String, to target: String, pct: Double) async throws {
        guard AppConfig.Features.enableSelfHealingRuntime else { return }
        struct Req: Encodable { let task: String; let source: String; let target: String; let pct: Double }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .autoScaler, path: "/predict",
            body: Req(task: "shift_traffic", source: source, target: target, pct: pct)
        )
    }

    func fetchIncidents(limit: Int = 20) async throws {
        guard AppConfig.Features.enableSelfHealingRuntime else { return }
        struct Req: Encodable { let task: String; let limit: Int }
        struct RawInc: Decodable { let id: String; let anomaly_ids: [String]?; let actions: [String]?; let status: String; let started: String?; let resolved: String?; let impact: String }
        struct Raw: Decodable { let incidents: [RawInc]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .autoScaler, path: "/predict",
            body: Req(task: "fetch_incidents", limit: limit)
        )
        incidents = (r.incidents ?? []).map {
            IncidentReport(id: $0.id, anomalyIds: $0.anomaly_ids ?? [], healingActions: $0.actions ?? [],
                           status: $0.status,
                           startedAt: $0.started.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(),
                           resolvedAt: $0.resolved.flatMap { ISO8601DateFormatter().date(from: $0) },
                           impactSummary: $0.impact)
        }
    }
}
