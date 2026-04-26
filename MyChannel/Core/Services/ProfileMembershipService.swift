//
//  ProfileMembershipService.swift
//  MyChannel
//
//  Phase 250: Profile Membership & Tiers Showcase.
//  Tier cards with perks, member-only content preview,
//  membership comparison UI, gift membership flow.
//  Uses `membership-optimizer` + `revenue-maximizer-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProfileMembershipTier: Codable, Identifiable {
    let id: String
    let creatorId: String
    let name: String
    let price: Double
    let currency: String
    let perks: [TierPerk]
    let memberCount: Int
    let colorHex: String
    let iconURL: String?

    struct TierPerk: Codable {
        let name: String
        let description: String
        let isExclusive: Bool
    }
}

struct ProfileMembershipComparison: Codable {
    let tiers: [ProfileMembershipTier]
    let highlightedPerks: [String]
}

struct GiftMembership: Codable, Identifiable {
    let id: String
    let tierId: String
    let fromUserId: String
    let toUserId: String
    let message: String?
    let redeemedAt: Date?
    let expiresAt: Date
}

// MARK: - Service

@MainActor
final class ProfileMembershipService: ObservableObject {
    static let shared = ProfileMembershipService()
    private init() {}

    @Published private(set) var tiers: [ProfileMembershipTier] = []
    @Published private(set) var comparison: ProfileMembershipComparison?

    func fetchTiers(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileMembershipShowcase else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawPerk: Decodable { let name: String; let desc: String; let exclusive: Bool }
        struct RawTier: Decodable { let id: String; let name: String; let price: Double; let currency: String; let perks: [RawPerk]?; let members: Int; let color: String; let icon: String? }
        struct Raw: Decodable { let tiers: [RawTier]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .membershipOptimizer, path: "/predict",
            body: Req(task: "fetch_membership_tiers", creatorId: creatorId)
        )
        tiers = (r.tiers ?? []).map {
            ProfileMembershipTier(id: $0.id, creatorId: creatorId, name: $0.name, price: $0.price, currency: $0.currency,
                                  perks: ($0.perks ?? []).map { ProfileMembershipTier.TierPerk(name: $0.name, description: $0.desc, isExclusive: $0.exclusive) },
                                  memberCount: $0.members, colorHex: $0.color, iconURL: $0.icon)
        }
    }

    func fetchComparison(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileMembershipShowcase else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let highlighted: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .membershipOptimizer, path: "/predict",
            body: Req(task: "fetch_membership_comparison", creatorId: creatorId)
        )
        comparison = ProfileMembershipComparison(
            tiers: tiers,
            highlightedPerks: r.highlighted ?? []
        )
    }

    func giftMembership(tierId: String, fromUserId: String, toUserId: String, message: String?) async throws -> GiftMembership {
        guard AppConfig.Features.enableProfileMembershipShowcase else {
            return GiftMembership(id: "", tierId: tierId, fromUserId: fromUserId, toUserId: toUserId,
                                   message: message, redeemedAt: nil, expiresAt: Date().addingTimeInterval(30*86400))
        }
        struct Req: Encodable { let task: String; let tierId: String; let from: String; let to: String; let message: String? }
        struct Raw: Decodable { let id: String; let expires: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .revenueMaximizer, path: "/predict",
            body: Req(task: "gift_membership", tierId: tierId, from: fromUserId, to: toUserId, message: message)
        )
        return GiftMembership(id: r.id, tierId: tierId, fromUserId: fromUserId, toUserId: toUserId,
                                message: message, redeemedAt: nil,
                                expiresAt: r.expires.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date().addingTimeInterval(30*86400))
    }
}
