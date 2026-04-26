//
//  ProfileMilestoneService.swift
//  MyChannel
//
//  Phase 252: Profile Milestone Celebrations.
//  Subscriber milestone animations, view count celebrations,
//  anniversary effects, confetti/lottie overlays, milestone sharing.
//  Uses `creator-relations-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProfileMilestone: Codable, Identifiable {
    let id: String
    let creatorId: String
    let type: MilestoneType
    let value: Int
    let title: String
    let description: String
    let animationAsset: String?
    let reachedAt: Date
    let isShared: Bool

    enum MilestoneType: String, Codable {
        case subscribers, views, videos, anniversary, likes, engagement
    }
}

struct MilestoneCelebration: Codable {
    let milestoneId: String
    let animationType: AnimationType
    let duration: TimeInterval
    let shareTemplate: String?

    enum AnimationType: String, Codable {
        case confetti, lottie, particle, shimmer, pulse
    }
}

// MARK: - Service

@MainActor
final class ProfileMilestoneService: ObservableObject {
    static let shared = ProfileMilestoneService()
    private init() {}

    @Published private(set) var milestones: [ProfileMilestone] = []
    @Published private(set) var pendingCelebration: MilestoneCelebration?

    func fetchMilestones(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileMilestones else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawM: Decodable { let id: String; let type: String; let value: Int; let title: String; let desc: String; let asset: String?; let reached: String?; let shared: Bool }
        struct Raw: Decodable { let milestones: [RawM]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Req(task: "fetch_milestones", creatorId: creatorId)
        )
        milestones = (r.milestones ?? []).map {
            ProfileMilestone(id: $0.id, creatorId: creatorId, type: .init(rawValue: $0.type) ?? .subscribers,
                             value: $0.value, title: $0.title, description: $0.desc, animationAsset: $0.asset,
                             reachedAt: $0.reached.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(), isShared: $0.shared)
        }
    }

    func checkNewMilestones(creatorId: String, subscriberCount: Int, viewCount: Int, videoCount: Int) async throws -> [ProfileMilestone] {
        guard AppConfig.Features.enableProfileMilestones else { return [] }
        struct Req: Encodable { let task: String; let creatorId: String; let subs: Int; let views: Int; let videos: Int }
        struct RawM: Decodable { let id: String; let type: String; let value: Int; let title: String; let desc: String; let asset: String?; let animation: String? }
        struct Raw: Decodable { let new_milestones: [RawM]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Req(task: "check_new_milestones", creatorId: creatorId, subs: subscriberCount, views: viewCount, videos: videoCount)
        )
        let newMilestones: [ProfileMilestone] = (r.new_milestones ?? []).map {
            ProfileMilestone(id: $0.id, creatorId: creatorId, type: .init(rawValue: $0.type) ?? .subscribers,
                             value: $0.value, title: $0.title, description: $0.desc, animationAsset: $0.asset,
                             reachedAt: Date(), isShared: false)
        }
        if let first = newMilestones.first, let anim = (r.new_milestones ?? []).first?.animation {
            pendingCelebration = MilestoneCelebration(milestoneId: first.id,
                                                        animationType: .init(rawValue: anim) ?? .confetti,
                                                        duration: 3.0, shareTemplate: nil)
        }
        milestones.append(contentsOf: newMilestones)
        return newMilestones
    }

    func shareMilestone(milestoneId: String) async throws {
        guard AppConfig.Features.enableProfileMilestones else { return }
        struct Req: Encodable { let task: String; let milestoneId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Req(task: "share_milestone", milestoneId: milestoneId)
        )
        if let idx = milestones.firstIndex(where: { $0.id == milestoneId }) {
            let old = milestones[idx]
            milestones[idx] = ProfileMilestone(id: old.id, creatorId: old.creatorId, type: old.type, value: old.value,
                                                 title: old.title, description: old.description, animationAsset: old.animationAsset,
                                                 reachedAt: old.reachedAt, isShared: true)
        }
    }
}
