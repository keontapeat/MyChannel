//
//  PredictiveInfraService.swift
//  MyChannel
//
//  Phase 138: Predictive Infrastructure.
//  Pre-warm CDN edges before viral spikes, demand-curve forecasting, auto-capacity.
//  Uses `cdn-optimizer` + `demand-forecasting-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct DemandForecast: Codable, Identifiable {
    let id: String
    let region: String
    let predictedRPS: Int            // requests per second
    let peakTimeUTC: String
    let confidence: Double
    let recommendedCapacity: String
}

struct CDNPrewarmJob: Codable, Identifiable {
    let id: String
    let videoId: String
    let targetEdges: [String]
    let status: PrewarmStatus
    let triggeredAt: Date
}

enum PrewarmStatus: String, Codable { case pending, warming, ready, failed }

struct ViralSpikeAlert: Codable, Identifiable {
    let id: String
    let videoId: String
    let currentRPS: Int
    let predictedPeakRPS: Int
    let minutesToPeak: Int
    let autoScaled: Bool
}

struct CapacityPlan: Codable {
    let region: String
    let currentInstances: Int
    let recommendedInstances: Int
    let estimatedCostDelta: Double
    let reason: String
}

// MARK: - Service

@MainActor
final class PredictiveInfraService: ObservableObject {
    static let shared = PredictiveInfraService()
    private init() {}

    @Published private(set) var forecasts: [DemandForecast] = []
    @Published private(set) var prewarmJobs: [CDNPrewarmJob] = []
    @Published private(set) var spikeAlerts: [ViralSpikeAlert] = []
    @Published private(set) var capacityPlans: [CapacityPlan] = []

    func forecastDemand() async throws {
        guard AppConfig.Features.enablePredictiveInfra else { return }
        struct Request: Encodable { let task: String }
        struct RawForecast: Decodable { let region: String; let rps: Int; let peak_time: String; let confidence: Double; let capacity: String }
        struct Raw: Decodable { let forecasts: [RawForecast]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .demandForecasting, path: "/predict",
            body: Request(task: "demand_forecast")
        )
        forecasts = (r.forecasts ?? []).map {
            DemandForecast(id: UUID().uuidString, region: $0.region, predictedRPS: $0.rps,
                          peakTimeUTC: $0.peak_time, confidence: $0.confidence, recommendedCapacity: $0.capacity)
        }
    }

    func prewarmCDN(videoId: String, targetEdges: [String]) async throws -> String {
        guard AppConfig.Features.enablePredictiveInfra else { return "" }
        struct Request: Encodable { let task: String; let videoId: String; let edges: [String] }
        struct Raw: Decodable { let job_id: String?; let status: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .cdnOptimizer, path: "/predict",
            body: Request(task: "prewarm_edges", videoId: videoId, edges: targetEdges)
        )
        let jobId = r.job_id ?? UUID().uuidString
        prewarmJobs.append(CDNPrewarmJob(
            id: jobId, videoId: videoId, targetEdges: targetEdges,
            status: PrewarmStatus(rawValue: r.status ?? "pending") ?? .pending, triggeredAt: Date()
        ))
        return jobId
    }

    func detectViralSpikes() async throws {
        guard AppConfig.Features.enablePredictiveInfra else { return }
        struct Request: Encodable { let task: String }
        struct RawSpike: Decodable { let video_id: String; let current_rps: Int; let peak_rps: Int; let minutes: Int; let auto_scaled: Bool }
        struct Raw: Decodable { let spikes: [RawSpike]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .demandForecasting, path: "/predict",
            body: Request(task: "detect_viral_spikes")
        )
        spikeAlerts = (r.spikes ?? []).map {
            ViralSpikeAlert(id: UUID().uuidString, videoId: $0.video_id, currentRPS: $0.current_rps,
                           predictedPeakRPS: $0.peak_rps, minutesToPeak: $0.minutes, autoScaled: $0.auto_scaled)
        }
    }

    func planCapacity() async throws {
        guard AppConfig.Features.enablePredictiveInfra else { return }
        struct Request: Encodable { let task: String }
        struct RawPlan: Decodable { let region: String; let current: Int; let recommended: Int; let cost_delta: Double; let reason: String }
        struct Raw: Decodable { let plans: [RawPlan]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .autoScaler, path: "/predict",
            body: Request(task: "capacity_plan")
        )
        capacityPlans = (r.plans ?? []).map {
            CapacityPlan(region: $0.region, currentInstances: $0.current, recommendedInstances: $0.recommended,
                        estimatedCostDelta: $0.cost_delta, reason: $0.reason)
        }
    }
}
