//
//  ProfileHighlightsService.swift
//  MyChannel
//
//  Phase 246: Featured Content & Highlights Reel.
//  Pinned content carousel, featured video/short, seasonal highlights,
//  auto-curated best-of, editorial picks.
//  Uses `recommendations` + `mychannel-content` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProfileHighlight: Codable, Identifiable {
    let id: String
    let creatorId: String
    let contentId: String
    let contentType: HighlightType
    let title: String
    let subtitle: String?
    let thumbnailURL: String?
    let isPinned: Bool
    let isAutoCurated: Bool
    let order: Int
    let expiresAt: Date?

    enum HighlightType: String, Codable { case video, short, playlist, live, post }
}

struct HighlightsReel: Codable {
    let creatorId: String
    let items: [ProfileHighlight]
    let autoCuratedIds: [String]
    let season: String?
}

// MARK: - Service

@MainActor
final class ProfileHighlightsService: ObservableObject {
    static let shared = ProfileHighlightsService()
    private init() {}

    @Published private(set) var highlights: [ProfileHighlight] = []
    @Published private(set) var reel: HighlightsReel?

    func fetchHighlights(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileHighlights else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawH: Decodable { let id: String; let content_id: String; let type: String; let title: String; let subtitle: String?; let thumbnail: String?; let pinned: Bool; let auto: Bool; let order: Int; let expires: String? }
        struct Raw: Decodable { let highlights: [RawH]?; let auto_ids: [String]?; let season: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .recommendations, path: "/predict",
            body: Req(task: "fetch_highlights", creatorId: creatorId)
        )
        highlights = (r.highlights ?? []).map {
            ProfileHighlight(id: $0.id, creatorId: creatorId, contentId: $0.content_id,
                             contentType: .init(rawValue: $0.type) ?? .video, title: $0.title, subtitle: $0.subtitle,
                             thumbnailURL: $0.thumbnail, isPinned: $0.pinned, isAutoCurated: $0.auto,
                             order: $0.order, expiresAt: $0.expires.flatMap { ISO8601DateFormatter().date(from: $0) })
        }
        reel = HighlightsReel(creatorId: creatorId, items: highlights, autoCuratedIds: r.auto_ids ?? [], season: r.season)
    }

    func pinContent(creatorId: String, contentId: String, type: ProfileHighlight.HighlightType) async throws -> ProfileHighlight {
        guard AppConfig.Features.enableProfileHighlights else {
            return ProfileHighlight(id: "", creatorId: creatorId, contentId: contentId, contentType: type,
                                     title: "", subtitle: nil, thumbnailURL: nil, isPinned: true, isAutoCurated: false, order: 0, expiresAt: nil)
        }
        struct Req: Encodable { let task: String; let creatorId: String; let contentId: String; let type: String }
        struct Raw: Decodable { let id: String; let title: String; let thumbnail: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "pin_highlight", creatorId: creatorId, contentId: contentId, type: type.rawValue)
        )
        let hl = ProfileHighlight(id: r.id, creatorId: creatorId, contentId: contentId, contentType: type,
                                    title: r.title, subtitle: nil, thumbnailURL: r.thumbnail,
                                    isPinned: true, isAutoCurated: false, order: highlights.count, expiresAt: nil)
        highlights.append(hl)
        return hl
    }

    func autoCurateBestOf(creatorId: String) async throws -> [ProfileHighlight] {
        guard AppConfig.Features.enableProfileHighlights else { return [] }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawH: Decodable { let id: String; let content_id: String; let type: String; let title: String; let thumbnail: String? }
        struct Raw: Decodable { let highlights: [RawH]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .recommendations, path: "/predict",
            body: Req(task: "auto_curate_best_of", creatorId: creatorId), timeout: 30
        )
        return (r.highlights ?? []).map {
            ProfileHighlight(id: $0.id, creatorId: creatorId, contentId: $0.content_id,
                             contentType: .init(rawValue: $0.type) ?? .video, title: $0.title, subtitle: nil,
                             thumbnailURL: $0.thumbnail, isPinned: false, isAutoCurated: true, order: 0, expiresAt: nil)
        }
    }

    func removeHighlight(highlightId: String) async throws {
        guard AppConfig.Features.enableProfileHighlights else { return }
        struct Req: Encodable { let task: String; let highlightId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "remove_highlight", highlightId: highlightId)
        )
        highlights.removeAll { $0.id == highlightId }
    }
}
