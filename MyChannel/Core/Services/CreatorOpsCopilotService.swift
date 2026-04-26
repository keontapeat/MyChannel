//
//  CreatorOpsCopilotService.swift
//  MyChannel
//
//  Phase 226: Creator Ops Copilot.
//  AI planning for uploads, titling, scheduling, packaging,
//  monetization strategy.
//  Uses `creator-relations-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct OpsPlan: Codable, Identifiable {
    let id: String
    let creatorId: String
    let title: String
    let steps: [OpsStep]
    let estimatedImpact: String
    let createdAt: Date
    let status: PlanStatus

    struct OpsStep: Codable, Identifiable {
        let id: String
        let action: String
        let detail: String
        let scheduledAt: Date?
        let isComplete: Bool
    }

    enum PlanStatus: String, Codable { case draft, active, completed, cancelled }
}

struct MonetizationStrategy: Codable {
    let currentRevenue: Double
    let projectedRevenue: Double
    let recommendations: [StrategyRec]
    let riskLevel: String
}

struct StrategyRec: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let expectedLift: Double
    let effort: String
}

// MARK: - Service

@MainActor
final class CreatorOpsCopilotService: ObservableObject {
    static let shared = CreatorOpsCopilotService()
    private init() {}

    @Published private(set) var plans: [OpsPlan] = []
    @Published private(set) var strategy: MonetizationStrategy?
    @Published var isGenerating: Bool = false

    func generatePlan(creatorId: String, goal: String) async throws -> OpsPlan {
        guard AppConfig.Features.enableCreatorOpsCopilot else {
            return OpsPlan(id: "", creatorId: creatorId, title: goal, steps: [],
                           estimatedImpact: "", createdAt: Date(), status: .draft)
        }
        isGenerating = true
        defer { isGenerating = false }
        struct Req: Encodable { let task: String; let creatorId: String; let goal: String }
        struct RawStep: Decodable { let id: String; let action: String; let detail: String; let scheduled: String?; let complete: Bool }
        struct Raw: Decodable { let id: String; let title: String; let steps: [RawStep]?; let impact: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Req(task: "generate_ops_plan", creatorId: creatorId, goal: goal), timeout: 30
        )
        let plan = OpsPlan(id: r.id, creatorId: creatorId, title: r.title,
                            steps: (r.steps ?? []).map {
                                OpsPlan.OpsStep(id: $0.id, action: $0.action, detail: $0.detail,
                                                scheduledAt: $0.scheduled.flatMap { ISO8601DateFormatter().date(from: $0) },
                                                isComplete: $0.complete)
                            },
                            estimatedImpact: r.impact ?? "", createdAt: Date(), status: .draft)
        plans.append(plan)
        return plan
    }

    func suggestTitle(videoDescription: String, creatorId: String) async throws -> [String] {
        guard AppConfig.Features.enableCreatorOpsCopilot else { return [] }
        struct Req: Encodable { let task: String; let description: String; let creatorId: String }
        struct Raw: Decodable { let titles: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Req(task: "suggest_title", description: videoDescription, creatorId: creatorId)
        )
        return r.titles ?? []
    }

    func suggestSchedule(creatorId: String) async throws -> [String] {
        guard AppConfig.Features.enableCreatorOpsCopilot else { return [] }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let slots: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Req(task: "suggest_schedule", creatorId: creatorId)
        )
        return r.slots ?? []
    }

    func fetchMonetizationStrategy(creatorId: String) async throws {
        guard AppConfig.Features.enableCreatorOpsCopilot else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawRec: Decodable { let id: String; let title: String; let desc: String; let lift: Double; let effort: String }
        struct Raw: Decodable { let current: Double?; let projected: Double?; let recs: [RawRec]?; let risk: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Req(task: "monetization_strategy", creatorId: creatorId), timeout: 30
        )
        strategy = MonetizationStrategy(currentRevenue: r.current ?? 0, projectedRevenue: r.projected ?? 0,
                                         recommendations: (r.recs ?? []).map { StrategyRec(id: $0.id, title: $0.title, description: $0.desc, expectedLift: $0.lift, effort: $0.effort) },
                                         riskLevel: r.risk ?? "low")
    }
}
