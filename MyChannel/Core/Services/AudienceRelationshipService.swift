//
//  AudienceRelationshipService.swift
//  MyChannel
//
//  Phase 228: Audience Relationship Engine.
//  Lifecycle segments, superfan ladders, churn prevention,
//  reactivation campaigns.
//  Uses `audience-segmentation-ai` + `churn-prevention` Cloud Run.
//

import Foundation

// MARK: - Models

struct AudienceSegment: Codable, Identifiable {
    let id: String
    let creatorId: String
    let name: String
    let size: Int
    let avgWatchTime: Double
    let churnRisk: Double
    let tier: SegmentTier

    enum SegmentTier: String, Codable {
        case new, casual, engaged, superfan, atRisk, churned
    }
}

struct ReactivationCampaign: Codable, Identifiable {
    let id: String
    let creatorId: String
    let targetSegment: String
    let channel: String
    let message: String
    let sentAt: Date?
    let reactivatedCount: Int
    let status: String
}

// MARK: - Service

@MainActor
final class AudienceRelationshipService: ObservableObject {
    static let shared = AudienceRelationshipService()
    private init() {}

    @Published private(set) var segments: [AudienceSegment] = []
    @Published private(set) var campaigns: [ReactivationCampaign] = []

    func fetchSegments(creatorId: String) async throws {
        guard AppConfig.Features.enableAudienceRelationship else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawSeg: Decodable { let id: String; let name: String; let size: Int; let watch: Double; let churn: Double; let tier: String }
        struct Raw: Decodable { let segments: [RawSeg]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .audienceSegmentation, path: "/predict",
            body: Req(task: "fetch_segments", creatorId: creatorId)
        )
        segments = (r.segments ?? []).map {
            AudienceSegment(id: $0.id, creatorId: creatorId, name: $0.name, size: $0.size,
                            avgWatchTime: $0.watch, churnRisk: $0.churn, tier: .init(rawValue: $0.tier) ?? .new)
        }
    }

    func predictChurn(creatorId: String) async throws -> [String: Double] {
        guard AppConfig.Features.enableAudienceRelationship else { return [:] }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let predictions: [String: Double]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .churnPrevention, path: "/predict",
            body: Req(task: "predict_churn", creatorId: creatorId)
        )
        return r.predictions ?? [:]
    }

    func launchReactivation(creatorId: String, targetSegment: String, channel: String, message: String) async throws -> ReactivationCampaign {
        guard AppConfig.Features.enableAudienceRelationship else {
            return ReactivationCampaign(id: "", creatorId: creatorId, targetSegment: targetSegment,
                                         channel: channel, message: message, sentAt: nil, reactivatedCount: 0, status: "draft")
        }
        struct Req: Encodable { let task: String; let creatorId: String; let segment: String; let channel: String; let message: String }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .churnPrevention, path: "/predict",
            body: Req(task: "launch_reactivation", creatorId: creatorId, segment: targetSegment,
                      channel: channel, message: message), timeout: 30
        )
        let campaign = ReactivationCampaign(id: r.id, creatorId: creatorId, targetSegment: targetSegment,
                                             channel: channel, message: message, sentAt: Date(), reactivatedCount: 0, status: "sent")
        campaigns.append(campaign)
        return campaign
    }

    func promoteSuperfan(creatorId: String, userId: String) async throws -> String {
        guard AppConfig.Features.enableAudienceRelationship else { return "" }
        struct Req: Encodable { let task: String; let creatorId: String; let userId: String }
        struct Raw: Decodable { let new_tier: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .audienceSegmentation, path: "/predict",
            body: Req(task: "promote_superfan", creatorId: creatorId, userId: userId)
        )
        return r.new_tier ?? ""
    }
}
