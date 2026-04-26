//
//  EmbedSDKService.swift
//  MyChannel
//
//  Phase 217: Embed SDK — embeddable player widget, iframe API,
//  customization options. Uses `mychannel-content` Cloud Run.
//

import Foundation

struct EmbedConfig: Codable, Identifiable {
    let id: String
    let creatorId: String
    let videoId: String
    let autoplay: Bool
    let muted: Bool
    let showControls: Bool
    let showTitle: Bool
    let theme: String
    let width: Int
    let height: Int
    let embedURL: String
}

struct EmbedAnalytics: Codable {
    let embedId: String
    let impressions: Int
    let plays: Int
    let avgWatchTime: Double
    let topDomains: [String]
}

@MainActor
final class EmbedSDKService: ObservableObject {
    static let shared = EmbedSDKService()
    private init() {}
    @Published private(set) var embeds: [EmbedConfig] = []

    func generateEmbed(creatorId: String, videoId: String, autoplay: Bool = false, muted: Bool = false, showControls: Bool = true, theme: String = "dark") async throws -> EmbedConfig {
        struct Req: Encodable { let task: String; let creatorId: String; let videoId: String; let autoplay: Bool; let muted: Bool; let controls: Bool; let theme: String }
        struct Raw: Decodable { let id: String; let url: String; let width: Int?; let height: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "generate_embed", creatorId: creatorId, videoId: videoId, autoplay: autoplay, muted: muted, controls: showControls, theme: theme))
        let embed = EmbedConfig(id: r.id, creatorId: creatorId, videoId: videoId, autoplay: autoplay, muted: muted,
            showControls: showControls, showTitle: true, theme: theme, width: r.width ?? 640, height: r.height ?? 360, embedURL: r.url)
        embeds.append(embed); return embed
    }

    func fetchEmbedAnalytics(embedId: String) async throws -> EmbedAnalytics {
        struct Req: Encodable { let task: String; let embedId: String }
        struct Raw: Decodable { let impressions: Int?; let plays: Int?; let avg_watch: Double?; let domains: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_embed_analytics", embedId: embedId))
        return EmbedAnalytics(embedId: embedId, impressions: r.impressions ?? 0, plays: r.plays ?? 0,
            avgWatchTime: r.avg_watch ?? 0, topDomains: r.domains ?? [])
    }

    func revokeEmbed(embedId: String) async throws {
        struct Req: Encodable { let task: String; let embedId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "revoke_embed", embedId: embedId))
        embeds.removeAll { $0.id == embedId }
    }
}
