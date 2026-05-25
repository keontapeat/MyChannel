//
//  PlatformSimulationService.swift
//  MyChannel
//
//  Phase 238: Platform Simulation Lab.
//  Ranking, pricing, and policy scenario modeling before rollout,
//  creator impact forecasting.
//  Uses `ab-testing-ai` + `analytics-predictor-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct SimulationScenario: Codable, Identifiable {
    let id: String
    let name: String
    let type: ScenarioType
    let parameters: [String: Double]
    let status: ScenarioStatus
    let createdAt: Date

    enum ScenarioType: String, Codable { case ranking, pricing, policy, feature }
    enum ScenarioStatus: String, Codable { case draft, running, completed, cancelled }
}

struct SimulationResult: Codable, Identifiable {
    let id: String
    let scenarioId: String
    let metrics: [MetricDelta]
    let creatorImpact: CreatorImpact
    let completedAt: Date

    struct MetricDelta: Codable {
        let metric: String
        let baseline: Double
        let simulated: Double
        let delta: Double
        let confidence: Double
    }

    struct CreatorImpact: Codable {
        let avgRevenueChange: Double
        let affectedPct: Double
        let negativelyAffectedPct: Double
        let topDecileChange: Double
    }
}

// MARK: - Service

@MainActor
final class PlatformSimulationService: ObservableObject {
    static let shared = PlatformSimulationService()
    private init() {}

    @Published private(set) var scenarios: [SimulationScenario] = []
    @Published private(set) var results: [SimulationResult] = []
    @Published var isRunning: Bool = false

    func createScenario(name: String, type: SimulationScenario.ScenarioType, parameters: [String: Double]) async throws -> SimulationScenario {
        guard AppConfig.Features.enablePlatformSimulation else {
            return SimulationScenario(id: "", name: name, type: type, parameters: parameters, status: .draft, createdAt: Date())
        }
        struct Req: Encodable { let task: String; let name: String; let type: String; let parameters: [String: Double] }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .abTestingAI, path: "/predict",
            body: Req(task: "create_scenario", name: name, type: type.rawValue, parameters: parameters)
        )
        let scenario = SimulationScenario(id: r.id, name: name, type: type, parameters: parameters, status: .draft, createdAt: Date())
        scenarios.append(scenario)
        return scenario
    }

    func runSimulation(scenarioId: String) async throws {
        guard AppConfig.Features.enablePlatformSimulation else { return }
        isRunning = true
        defer { isRunning = false }
        struct Req: Encodable { let task: String; let scenarioId: String }
        struct RawMetric: Decodable { let metric: String; let baseline: Double; let simulated: Double; let delta: Double; let confidence: Double }
        struct RawImpact: Decodable { let avg_revenue: Double; let affected: Double; let negative: Double; let top_decile: Double }
        struct Raw: Decodable { let id: String; let metrics: [RawMetric]?; let impact: RawImpact? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .analyticsPredictor, path: "/predict",
            body: Req(task: "run_simulation", scenarioId: scenarioId), timeout: 60
        )
        let result = SimulationResult(id: r.id, scenarioId: scenarioId,
                                        metrics: (r.metrics ?? []).map { SimulationResult.MetricDelta(metric: $0.metric, baseline: $0.baseline, simulated: $0.simulated, delta: $0.delta, confidence: $0.confidence) },
                                        creatorImpact: SimulationResult.CreatorImpact(avgRevenueChange: r.impact?.avg_revenue ?? 0,
                                                                                        affectedPct: r.impact?.affected ?? 0,
                                                                                        negativelyAffectedPct: r.impact?.negative ?? 0,
                                                                                        topDecileChange: r.impact?.top_decile ?? 0),
                                        completedAt: Date())
        results.append(result)
    }

    func forecastCreatorImpact(scenarioId: String, creatorId: String) async throws -> [String: Double] {
        guard AppConfig.Features.enablePlatformSimulation else { return [:] }
        struct Req: Encodable { let task: String; let scenarioId: String; let creatorId: String }
        struct Raw: Decodable { let impact: [String: Double]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .analyticsPredictor, path: "/predict",
            body: Req(task: "forecast_creator_impact", scenarioId: scenarioId, creatorId: creatorId)
        )
        return r.impact ?? [:]
    }
}
