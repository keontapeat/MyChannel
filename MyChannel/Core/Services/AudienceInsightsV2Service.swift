//
//  AudienceInsightsV2Service.swift
//  MyChannel
//
//  Phase 168: Audience Insights Dashboard v2.
//  Cohort analysis, funnel visualization, churn prediction.
//  Uses `audience-segmentation-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct AudienceCohort: Codable, Identifiable {
    let id: String
    let name: String
    let size: Int
    let retentionRate: Double
    let avgWatchTimeSec: Double
    let topContentCategory: String
}

struct AudienceFunnelStage: Codable, Identifiable {
    let id: String
    let name: String
    let count: Int
    let conversionRate: Double
}

struct ChurnRiskUser: Codable, Identifiable {
    let id: String
    let uid: String
    let riskScore: Double
    let lastActiveDate: Date
    let recommendedAction: String
}

// MARK: - Service

@MainActor
final class AudienceInsightsV2Service: ObservableObject {
    static let shared = AudienceInsightsV2Service()
    private init() {}

    @Published private(set) var cohorts: [AudienceCohort] = []
    @Published private(set) var funnel: [AudienceFunnelStage] = []
    @Published private(set) var churnRisks: [ChurnRiskUser] = []

    func loadCohorts(creatorUid: String) async throws {
        guard AppConfig.Features.enableAudienceInsightsV2 else { return }
        struct Request: Encodable { let task: String; let creatorUid: String }
        struct RawCohort: Decodable { let name: String; let size: Int; let retention: Double; let watch_time: Double; let category: String }
        struct Raw: Decodable { let cohorts: [RawCohort]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .audienceSegmentation, path: "/predict",
            body: Request(task: "cohort_analysis", creatorUid: creatorUid)
        )
        cohorts = (r.cohorts ?? []).map {
            AudienceCohort(id: UUID().uuidString, name: $0.name, size: $0.size,
                          retentionRate: $0.retention, avgWatchTimeSec: $0.watch_time,
                          topContentCategory: $0.category)
        }
    }

    func loadFunnel(creatorUid: String) async throws {
        guard AppConfig.Features.enableAudienceInsightsV2 else { return }
        struct Request: Encodable { let task: String; let creatorUid: String }
        struct RawStage: Decodable { let name: String; let count: Int; let conversion: Double }
        struct Raw: Decodable { let stages: [RawStage]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .audienceSegmentation, path: "/predict",
            body: Request(task: "funnel_analysis", creatorUid: creatorUid)
        )
        funnel = (r.stages ?? []).map {
            AudienceFunnelStage(id: UUID().uuidString, name: $0.name, count: $0.count, conversionRate: $0.conversion)
        }
    }

    func predictChurn(creatorUid: String) async throws {
        guard AppConfig.Features.enableAudienceInsightsV2 else { return }
        struct Request: Encodable { let task: String; let creatorUid: String }
        struct RawRisk: Decodable { let uid: String; let score: Double; let last_active: String; let action: String }
        struct Raw: Decodable { let risks: [RawRisk]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .audienceSegmentation, path: "/predict",
            body: Request(task: "churn_prediction", creatorUid: creatorUid)
        )
        churnRisks = (r.risks ?? []).map {
            ChurnRiskUser(id: UUID().uuidString, uid: $0.uid, riskScore: $0.score,
                         lastActiveDate: Date(), recommendedAction: $0.action)
        }
    }
}
