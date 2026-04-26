//
//  CreatorGrowthCopilotV2Service.swift
//  MyChannel
//
//  Phase 114: Creator Growth Copilot v2.
//  Per-video action playbooks, publish-time optimizer, scenario simulation.
//  Uses `creator-coach-ai` + `viral-prediction`.
//

import Foundation

// MARK: - Models

struct GrowthPlaybook: Codable, Identifiable {
    let id: String
    let videoId: String
    let actions: [PlaybookAction]
    let projectedViewLift: Double  // e.g. 0.35 = +35%
    let generatedAt: Date
}

struct PlaybookAction: Codable, Identifiable, Equatable {
    let id: String
    let priority: Int
    let title: String
    let description: String
    let completed: Bool
}

struct PublishTimeSlot: Codable, Identifiable {
    let id: String
    let dayOfWeek: Int      // 1=Sun … 7=Sat
    let hourUTC: Int
    let predictedReach: Double
}

struct ScenarioSimulation: Codable {
    let scenarioName: String
    let projectedViews: Int
    let projectedSubs: Int
    let projectedRevenue: Double
    let confidence: Double
}

// MARK: - Service

@MainActor
final class CreatorGrowthCopilotV2Service: ObservableObject {
    static let shared = CreatorGrowthCopilotV2Service()
    private init() {}

    @Published private(set) var playbook: GrowthPlaybook?
    @Published private(set) var publishTimeSlots: [PublishTimeSlot] = []
    @Published private(set) var simulations: [ScenarioSimulation] = []

    func generatePlaybook(videoId: String, creatorUid: String) async throws {
        guard AppConfig.Features.enableCreatorGrowthCopilotV2 else { return }
        struct Request: Encodable { let task: String; let videoId: String; let creatorUid: String }
        struct RawAction: Decodable { let priority: Int; let title: String; let description: String }
        struct Raw: Decodable { let actions: [RawAction]?; let projected_view_lift: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorCoachAI,
            path: "/predict",
            body: Request(task: "growth_playbook", videoId: videoId, creatorUid: creatorUid)
        )
        playbook = GrowthPlaybook(
            id: UUID().uuidString,
            videoId: videoId,
            actions: (r.actions ?? []).map {
                PlaybookAction(id: UUID().uuidString, priority: $0.priority, title: $0.title, description: $0.description, completed: false)
            },
            projectedViewLift: r.projected_view_lift ?? 0,
            generatedAt: Date()
        )
    }

    func optimizePublishTime(creatorUid: String) async throws {
        guard AppConfig.Features.enableCreatorGrowthCopilotV2 else { return }
        struct Request: Encodable { let task: String; let creatorUid: String }
        struct RawSlot: Decodable { let day: Int; let hour: Int; let reach: Double }
        struct Raw: Decodable { let slots: [RawSlot]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .viralPrediction,
            path: "/predict",
            body: Request(task: "publish_time_optimizer", creatorUid: creatorUid)
        )
        publishTimeSlots = (r.slots ?? []).map {
            PublishTimeSlot(id: UUID().uuidString, dayOfWeek: $0.day, hourUTC: $0.hour, predictedReach: $0.reach)
        }
    }

    func simulateScenario(creatorUid: String, scenario: String) async throws {
        guard AppConfig.Features.enableCreatorGrowthCopilotV2 else { return }
        struct Request: Encodable { let task: String; let creatorUid: String; let scenario: String }
        struct RawSim: Decodable { let name: String; let views: Int; let subs: Int; let revenue: Double; let confidence: Double }
        struct Raw: Decodable { let simulations: [RawSim]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorCoachAI,
            path: "/predict",
            body: Request(task: "scenario_sim", creatorUid: creatorUid, scenario: scenario)
        )
        simulations = (r.simulations ?? []).map {
            ScenarioSimulation(scenarioName: $0.name, projectedViews: $0.views, projectedSubs: $0.subs, projectedRevenue: $0.revenue, confidence: $0.confidence)
        }
    }
}
