//
//  GlobalControlPlaneService.swift
//  MyChannel
//
//  Phase 116: Active-Active Global Control Plane.
//  Regional failover <60s, traffic steering, graceful degradation policies.
//  Uses `global-expansion-ai` + `auto-scaler` Cloud Run.
//

import Foundation

// MARK: - Models

struct RegionHealth: Codable, Identifiable {
    let id: String           // region code e.g. "us-central1"
    let region: String
    let status: RegionStatus
    let latencyP50Ms: Int
    let latencyP99Ms: Int
    let errorRate: Double    // 0–1
    let activeConnections: Int
    let lastCheckedAt: Date
}

enum RegionStatus: String, Codable { case healthy, degraded, failing, offline }

struct TrafficRule: Codable, Identifiable {
    let id: String
    let sourceRegion: String
    let targetRegion: String
    let weight: Double       // 0–1
    let reason: String
}

struct FailoverEvent: Codable, Identifiable {
    let id: String
    let fromRegion: String
    let toRegion: String
    let triggeredAt: Date
    let durationSec: Int
    let cause: String
}

struct DegradationPolicy: Codable, Identifiable {
    let id: String
    let name: String
    let trigger: String
    let action: String
    let enabled: Bool
}

// MARK: - Service

@MainActor
final class GlobalControlPlaneService: ObservableObject {
    static let shared = GlobalControlPlaneService()
    private init() {}

    @Published private(set) var regionHealths: [RegionHealth] = []
    @Published private(set) var trafficRules: [TrafficRule] = []
    @Published private(set) var failoverHistory: [FailoverEvent] = []
    @Published private(set) var policies: [DegradationPolicy] = []

    func checkRegionHealth() async throws {
        guard AppConfig.Features.enableGlobalControlPlane else { return }
        struct Request: Encodable { let task: String }
        struct RawRegion: Decodable {
            let region: String; let status: String; let p50: Int; let p99: Int
            let error_rate: Double; let connections: Int
        }
        struct Raw: Decodable { let regions: [RawRegion]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .globalExpansion,
            path: "/predict",
            body: Request(task: "region_health")
        )
        regionHealths = (r.regions ?? []).map {
            RegionHealth(
                id: $0.region, region: $0.region,
                status: RegionStatus(rawValue: $0.status) ?? .healthy,
                latencyP50Ms: $0.p50, latencyP99Ms: $0.p99,
                errorRate: $0.error_rate,
                activeConnections: $0.connections,
                lastCheckedAt: Date()
            )
        }
    }

    func steerTraffic(sourceRegion: String, targetRegion: String, weight: Double) async throws {
        guard AppConfig.Features.enableGlobalControlPlane else { return }
        struct Request: Encodable { let task: String; let source: String; let target: String; let weight: Double }
        struct Raw: Decodable { let applied: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .autoScaler,
            path: "/predict",
            body: Request(task: "steer_traffic", source: sourceRegion, target: targetRegion, weight: weight)
        )
        let rule = TrafficRule(id: UUID().uuidString, sourceRegion: sourceRegion, targetRegion: targetRegion, weight: weight, reason: "manual")
        trafficRules.append(rule)
    }

    func triggerFailover(fromRegion: String, toRegion: String) async throws {
        guard AppConfig.Features.enableGlobalControlPlane else { return }
        struct Request: Encodable { let task: String; let from: String; let to: String }
        struct Raw: Decodable { let duration_sec: Int?; let success: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .globalExpansion,
            path: "/predict",
            body: Request(task: "failover", from: fromRegion, to: toRegion)
        )
        let event = FailoverEvent(
            id: UUID().uuidString,
            fromRegion: fromRegion,
            toRegion: toRegion,
            triggeredAt: Date(),
            durationSec: r.duration_sec ?? 0,
            cause: "manual_trigger"
        )
        failoverHistory.append(event)
    }
}
