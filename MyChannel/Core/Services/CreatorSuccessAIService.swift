//
//  CreatorSuccessAIService.swift
//  MyChannel
//
//  Phase 199: Creator Success Manager AI.
//  Personalized growth coaching, content strategy AI, milestone celebrations.
//  Uses `creator-relations-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct GrowthInsight: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let actionItem: String
    let priority: String
    let predictedImpact: String
}

struct SuccessContentStrategy: Codable, Identifiable {
    let id: String
    let period: String
    let recommendedTopics: [String]
    let recommendedFormats: [String]
    let optimalFrequency: String
    let predictedGrowth: Double
}

struct CreatorMilestone: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let threshold: Int
    let currentValue: Int
    let achieved: Bool
    let achievedAt: Date?
}

// MARK: - Service

@MainActor
final class CreatorSuccessAIService: ObservableObject {
    static let shared = CreatorSuccessAIService()
    private init() {}

    @Published private(set) var insights: [GrowthInsight] = []
    @Published private(set) var strategy: SuccessContentStrategy?
    @Published private(set) var milestones: [CreatorMilestone] = []

    func fetchInsights(creatorUid: String) async throws {
        guard AppConfig.Features.enableCreatorSuccessAI else { return }
        struct Request: Encodable { let task: String; let creatorUid: String }
        struct RawInsight: Decodable { let title: String; let desc: String; let action: String; let priority: String; let impact: String }
        struct Raw: Decodable { let insights: [RawInsight]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Request(task: "growth_insights", creatorUid: creatorUid)
        )
        insights = (r.insights ?? []).map {
            GrowthInsight(id: UUID().uuidString, title: $0.title, description: $0.desc,
                         actionItem: $0.action, priority: $0.priority, predictedImpact: $0.impact)
        }
    }

    func generateStrategy(creatorUid: String, period: String) async throws {
        guard AppConfig.Features.enableCreatorSuccessAI else { return }
        struct Request: Encodable { let task: String; let creatorUid: String; let period: String }
        struct Raw: Decodable { let topics: [String]?; let formats: [String]?; let frequency: String?; let growth: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Request(task: "content_strategy", creatorUid: creatorUid, period: period)
        )
        strategy = SuccessContentStrategy(
            id: UUID().uuidString, period: period,
            recommendedTopics: r.topics ?? [], recommendedFormats: r.formats ?? [],
            optimalFrequency: r.frequency ?? "3x/week", predictedGrowth: r.growth ?? 0
        )
    }

    func checkMilestones(creatorUid: String) async throws {
        guard AppConfig.Features.enableCreatorSuccessAI else { return }
        struct Request: Encodable { let task: String; let creatorUid: String }
        struct RawMilestone: Decodable { let name: String; let desc: String; let threshold: Int; let current: Int; let achieved: Bool }
        struct Raw: Decodable { let milestones: [RawMilestone]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Request(task: "milestones", creatorUid: creatorUid)
        )
        milestones = (r.milestones ?? []).map {
            CreatorMilestone(id: UUID().uuidString, name: $0.name, description: $0.desc,
                           threshold: $0.threshold, currentValue: $0.current,
                           achieved: $0.achieved, achievedAt: $0.achieved ? Date() : nil)
        }
    }
}
