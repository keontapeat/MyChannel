//
//  FeedPreviewService.swift
//  MyChannel
//
//  Phase 272: Feed Preview & Peek — long-press preview, audio preview,
//  metadata peek, channel preview card, progressive reveal.
//  Uses `mychannel-content` Cloud Run.
//

import Foundation

struct FeedPreview: Codable, Identifiable {
    let id: String
    let videoId: String
    let previewURL: String?
    let audioPreviewURL: String?
    let title: String
    let creatorName: String
    let duration: Double
    let summary: String
}

@MainActor
final class FeedPreviewService: ObservableObject {
    static let shared = FeedPreviewService()
    private init() {}

    @Published private(set) var activePreview: FeedPreview?

    func fetchPreview(videoId: String) async throws {
        guard AppConfig.Features.enableFeedPreview else { return }
        struct Req: Encodable { let task: String; let videoId: String }
        struct Raw: Decodable { let preview: String?; let audio: String?; let title: String; let creator: String; let duration: Double?; let summary: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict", body: Req(task: "feed_preview", videoId: videoId))
        activePreview = FeedPreview(id: UUID().uuidString, videoId: videoId, previewURL: r.preview, audioPreviewURL: r.audio, title: r.title, creatorName: r.creator, duration: r.duration ?? 0, summary: r.summary ?? "")
    }

    func clear() { activePreview = nil }
}
