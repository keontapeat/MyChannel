//
//  ProfileSocialLinksService.swift
//  MyChannel
//
//  Phase 244: Social Links & Cross-Platform Presence.
//  Instagram, TikTok, Twitter/X, YouTube, Spotify link cards,
//  link-in-bio style layout, verified link indicators, click tracking.
//  Uses `mychannel-content` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProfileSocialLink: Codable, Identifiable {
    let id: String
    let creatorId: String
    let platform: SocialPlatform
    let url: String
    let displayName: String?
    let isVerified: Bool
    let clickCount: Int
    let order: Int
    let addedAt: Date

    enum SocialPlatform: String, Codable {
        case instagram, tiktok, twitter, youtube, spotify, twitch, discord, patreon, website, linkedin, github, other
    }
}

struct ProfileSocialLinkLayout: Codable {
    let creatorId: String
    let style: LinkStyle
    let showVerifiedOnly: Bool

    enum LinkStyle: String, Codable { case cards, list, compact, bio }
}

// MARK: - Service

@MainActor
final class ProfileSocialLinksService: ObservableObject {
    static let shared = ProfileSocialLinksService()
    private init() {}

    @Published private(set) var links: [ProfileSocialLink] = []
    @Published private(set) var layout: ProfileSocialLinkLayout?

    func fetchLinks(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileSocialLinks else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawL: Decodable { let id: String; let platform: String; let url: String; let display: String?; let verified: Bool; let clicks: Int; let order: Int; let added: String? }
        struct Raw: Decodable { let links: [RawL]?; let style: String?; let verified_only: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "fetch_social_links", creatorId: creatorId)
        )
        links = (r.links ?? []).map {
            ProfileSocialLink(id: $0.id, creatorId: creatorId, platform: .init(rawValue: $0.platform) ?? .other,
                              url: $0.url, displayName: $0.display, isVerified: $0.verified,
                              clickCount: $0.clicks, order: $0.order,
                              addedAt: $0.added.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date())
        }
        if let style = r.style {
            layout = ProfileSocialLinkLayout(creatorId: creatorId, style: .init(rawValue: style) ?? .cards,
                                             showVerifiedOnly: r.verified_only ?? false)
        }
    }

    func addLink(creatorId: String, platform: ProfileSocialLink.SocialPlatform, url: String, displayName: String?) async throws -> ProfileSocialLink {
        guard AppConfig.Features.enableProfileSocialLinks else {
            return ProfileSocialLink(id: "", creatorId: creatorId, platform: platform, url: url,
                                     displayName: displayName, isVerified: false, clickCount: 0, order: links.count, addedAt: Date())
        }
        struct Req: Encodable { let task: String; let creatorId: String; let platform: String; let url: String; let display: String? }
        struct Raw: Decodable { let id: String; let verified: Bool }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "add_social_link", creatorId: creatorId, platform: platform.rawValue, url: url, display: displayName)
        )
        let link = ProfileSocialLink(id: r.id, creatorId: creatorId, platform: platform, url: url,
                                     displayName: displayName, isVerified: r.verified, clickCount: 0, order: links.count, addedAt: Date())
        links.append(link)
        return link
    }

    func trackClick(linkId: String) async throws {
        guard AppConfig.Features.enableProfileSocialLinks else { return }
        struct Req: Encodable { let task: String; let linkId: String }
        struct Raw: Decodable { let clicks: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "track_link_click", linkId: linkId)
        )
        if let idx = links.firstIndex(where: { $0.id == linkId }) {
            let old = links[idx]
            links[idx] = ProfileSocialLink(id: old.id, creatorId: old.creatorId, platform: old.platform, url: old.url,
                                           displayName: old.displayName, isVerified: old.isVerified,
                                           clickCount: r.clicks ?? old.clickCount + 1, order: old.order, addedAt: old.addedAt)
        }
    }

    func removeLink(linkId: String) async throws {
        guard AppConfig.Features.enableProfileSocialLinks else { return }
        struct Req: Encodable { let task: String; let linkId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "remove_social_link", linkId: linkId)
        )
        links.removeAll { $0.id == linkId }
    }
}
