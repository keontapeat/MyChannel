//
//  RealTimeABTestService.swift
//  MyChannel
//
//  Real-time A/B testing: experiment assignment, variant delivery,
//  metric tracking, statistical significance. Uses `ab-testing-ai` Cloud Run.
//

import Foundation

struct ABExperiment: Codable, Identifiable {
    let id: String
    let name: String
    let variants: [ABVariant]
    let status: ExperimentStatus
    let startDate: Date
    let endDate: Date?
    struct ABVariant: Codable { let name: String; let weight: Double; let isControl: Bool }
    enum ExperimentStatus: String, Codable { case draft, running, paused, completed }
}

struct ABAssignment: Codable {
    let userId: String
    let experimentId: String
    let variant: String
    let assignedAt: Date
}

@MainActor
final class RealTimeABTestService: ObservableObject {
    static let shared = RealTimeABTestService()
    private init() {}
    @Published private(set) var experiments: [ABExperiment] = []
    @Published private(set) var assignments: [String: ABAssignment] = [:]

    func fetchExperiments() async throws {
        struct Req: Encodable { let task: String }
        struct RawV: Decodable { let name: String; let weight: Double; let control: Bool }
        struct RawE: Decodable { let id: String; let name: String; let variants: [RawV]?; let status: String; let start: String?; let end: String? }
        struct Raw: Decodable { let experiments: [RawE]? }
        let r: Raw = try await CloudRunAgentRouter.post(.abTestingAI, path: "/predict", body: Req(task: "fetch_experiments"))
        experiments = (r.experiments ?? []).map {
            ABExperiment(id: $0.id, name: $0.name,
                variants: ($0.variants ?? []).map { ABExperiment.ABVariant(name: $0.name, weight: $0.weight, isControl: $0.control) },
                status: .init(rawValue: $0.status) ?? .draft,
                startDate: $0.start.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(),
                endDate: $0.end.flatMap { ISO8601DateFormatter().date(from: $0) })
        }
    }

    func assignVariant(userId: String, experimentId: String) async throws -> String {
        struct Req: Encodable { let task: String; let userId: String; let experimentId: String }
        struct Raw: Decodable { let variant: String }
        let r: Raw = try await CloudRunAgentRouter.post(.abTestingAI, path: "/predict",
            body: Req(task: "assign_variant", userId: userId, experimentId: experimentId))
        assignments[experimentId] = ABAssignment(userId: userId, experimentId: experimentId, variant: r.variant, assignedAt: Date())
        return r.variant
    }

    func trackMetric(experimentId: String, variant: String, metric: String, value: Double) async throws {
        struct Req: Encodable { let task: String; let experimentId: String; let variant: String; let metric: String; let value: Double }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.abTestingAI, path: "/predict",
            body: Req(task: "track_ab_metric", experimentId: experimentId, variant: variant, metric: metric, value: value))
    }

    func getVariant(experimentId: String) -> String { assignments[experimentId]?.variant ?? "control" }
}
