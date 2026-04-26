//
//  ProfileBadgeService.swift
//  MyChannel
//
//  Phase 243: Profile Badges & Achievements.
//  Milestone badges, achievement showcase, rarity tiers,
//  badge customization positioning, community-awarded badges.
//  Uses `creator-relations-ai` + `mychannel-content` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProfileBadge: Codable, Identifiable {
    let id: String
    let creatorId: String
    let name: String
    let description: String
    let iconURL: String
    let rarity: BadgeRarity
    let category: BadgeCategory
    let earnedAt: Date
    let isDisplayed: Bool
    let displayPosition: Int

    enum BadgeRarity: String, Codable { case common, uncommon, rare, epic, legendary }
    enum BadgeCategory: String, Codable { case milestone, community, creator, special, seasonal }
}

struct BadgeShowcase: Codable {
    let creatorId: String
    let featuredBadges: [String]
    let layout: ShowcaseLayout

    enum ShowcaseLayout: String, Codable { case row, grid, carousel }
}

// MARK: - Service

@MainActor
final class ProfileBadgeService: ObservableObject {
    static let shared = ProfileBadgeService()
    private init() {}

    @Published private(set) var badges: [ProfileBadge] = []
    @Published private(set) var showcase: BadgeShowcase?

    func fetchBadges(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileBadges else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawB: Decodable { let id: String; let name: String; let desc: String; let icon: String; let rarity: String; let category: String; let earned: String?; let displayed: Bool; let position: Int }
        struct Raw: Decodable { let badges: [RawB]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Req(task: "fetch_badges", creatorId: creatorId)
        )
        badges = (r.badges ?? []).map {
            ProfileBadge(id: $0.id, creatorId: creatorId, name: $0.name, description: $0.desc,
                         iconURL: $0.icon, rarity: .init(rawValue: $0.rarity) ?? .common,
                         category: .init(rawValue: $0.category) ?? .milestone,
                         earnedAt: $0.earned.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(),
                         isDisplayed: $0.displayed, displayPosition: $0.position)
        }
    }

    func updateShowcase(creatorId: String, featuredIds: [String], layout: BadgeShowcase.ShowcaseLayout) async throws {
        guard AppConfig.Features.enableProfileBadges else { return }
        struct Req: Encodable { let task: String; let creatorId: String; let featured: [String]; let layout: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "update_badge_showcase", creatorId: creatorId, featured: featuredIds, layout: layout.rawValue)
        )
        showcase = BadgeShowcase(creatorId: creatorId, featuredBadges: featuredIds, layout: layout)
    }

    func awardBadge(creatorId: String, badgeId: String, reason: String) async throws -> ProfileBadge? {
        guard AppConfig.Features.enableProfileBadges else { return nil }
        struct Req: Encodable { let task: String; let creatorId: String; let badgeId: String; let reason: String }
        struct Raw: Decodable { let id: String; let name: String; let desc: String; let icon: String; let rarity: String; let category: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Req(task: "award_badge", creatorId: creatorId, badgeId: badgeId, reason: reason)
        )
        let badge = ProfileBadge(id: r.id, creatorId: creatorId, name: r.name, description: r.desc,
                                    iconURL: r.icon, rarity: .init(rawValue: r.rarity) ?? .common,
                                    category: .init(rawValue: r.category) ?? .community,
                                    earnedAt: Date(), isDisplayed: true, displayPosition: badges.count)
        badges.append(badge)
        return badge
    }

    func checkMilestoneEligibility(creatorId: String) async throws -> [String] {
        guard AppConfig.Features.enableProfileBadges else { return [] }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let eligible: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Req(task: "check_milestone_eligibility", creatorId: creatorId)
        )
        return r.eligible ?? []
    }
}
