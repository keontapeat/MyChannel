//
//  FinOpsService.swift
//  MyChannel
//
//  Phase 93: Cost control & FinOps.
//  Powers the internal FinOps dashboard (owner-only). Aggregates spend
//  by feature, surfaces anomalies, and lets SRE auto-shutdown idle
//  Cloud Run services. Complements the existing `CostGuardrailsService`.
//

import Foundation

struct FinOpsSnapshot: Codable, Equatable {
    let windowStart: Date
    let windowEnd: Date
    let totalUSD: Decimal
    let byFeature: [FeatureSpend]
    let topLineItems: [LineItem]
    let anomalies: [Anomaly]
}

struct FeatureSpend: Codable, Identifiable, Equatable {
    let id: String            // feature key, e.g. "flicks", "creator_coach", "ads"
    let usdSpent: Decimal
    let percentOfTotal: Double
    let changeVsPrevPeriod: Double  // -1..+inf
}

struct LineItem: Codable, Identifiable, Equatable {
    let id: String
    let service: String       // "Cloud Run", "Firestore", "Cloud Storage", ...
    let sku: String
    let usdSpent: Decimal
}

struct Anomaly: Codable, Identifiable, Equatable {
    let id: String
    let service: String
    let severity: Severity
    let message: String
    let delta: Double
    enum Severity: String, Codable { case info, warn, critical }
}

@MainActor
final class FinOpsService: ObservableObject {
    static let shared = FinOpsService()
    private init() {}

    @Published private(set) var latest: FinOpsSnapshot?
    @Published private(set) var isLoading = false

    // MARK: - Load

    func loadLast30Days() async throws -> FinOpsSnapshot {
        guard AppConfig.Features.enableFinOpsDashboard else { throw FinOpsError.disabled }
        isLoading = true
        defer { isLoading = false }

        struct Request: Encodable { let task: String; let days: Int }
        struct RawFeature: Decodable {
            let id: String
            let usd: Double
            let percent: Double
            let change_pct: Double?
        }
        struct RawLineItem: Decodable {
            let id: String
            let service: String
            let sku: String
            let usd: Double
        }
        struct RawAnomaly: Decodable {
            let id: String
            let service: String
            let severity: String
            let message: String
            let delta: Double
        }
        struct Raw: Decodable {
            let window_start: Double
            let window_end: Double
            let total_usd: Double
            let by_feature: [RawFeature]?
            let top_line_items: [RawLineItem]?
            let anomalies: [RawAnomaly]?
        }

        let r: Raw = try await CloudRunAgentRouter.post(
            .autoScaler,
            path: "/predict",
            body: Request(task: "finops_snapshot", days: 30),
            timeout: 30
        )

        let snap = FinOpsSnapshot(
            windowStart: Date(timeIntervalSince1970: r.window_start),
            windowEnd: Date(timeIntervalSince1970: r.window_end),
            totalUSD: Decimal(r.total_usd),
            byFeature: (r.by_feature ?? []).map {
                FeatureSpend(
                    id: $0.id,
                    usdSpent: Decimal($0.usd),
                    percentOfTotal: $0.percent,
                    changeVsPrevPeriod: $0.change_pct ?? 0
                )
            },
            topLineItems: (r.top_line_items ?? []).map {
                LineItem(id: $0.id, service: $0.service, sku: $0.sku, usdSpent: Decimal($0.usd))
            },
            anomalies: (r.anomalies ?? []).compactMap {
                guard let sev = Anomaly.Severity(rawValue: $0.severity) else { return nil }
                return Anomaly(id: $0.id, service: $0.service, severity: sev, message: $0.message, delta: $0.delta)
            }
        )
        latest = snap
        return snap
    }

    // MARK: - Actions (owner-only)

    /// Request idle-shutdown for a given Cloud Run service (scales min-instances to 0).
    func shutdownIdle(service: String) async throws {
        guard AppConfig.Features.enableFinOpsDashboard else { throw FinOpsError.disabled }
        struct Request: Encodable { let task: String; let service: String }
        _ = try await CloudRunAgentRouter.post(
            .autoScaler,
            path: "/predict",
            body: Request(task: "shutdown_idle", service: service)
        ) as _Ack
    }

    private struct _Ack: Decodable { let ok: Bool? }

    enum FinOpsError: LocalizedError {
        case disabled
        var errorDescription: String? { "FinOps dashboard is disabled." }
    }
}
