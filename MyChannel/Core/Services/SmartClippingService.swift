//
//  SmartClippingService.swift
//  MyChannel
//
//  Phase 79: Smart Clipping.
//  Detects highlight moments in a VOD (applause, laughter, key transcript
//  phrases, high-retention spikes) and lets the user one-tap publish to
//  Flicks / Stories with AI caption + music.
//

import Foundation

struct SmartClip: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let startSeconds: Double
    let endSeconds: Double
    let score: Double            // 0..1 viral potential from `viral-prediction`
    let reason: String           // "laugh_peak", "retention_spike", "applause", ...
    let suggestedCaption: String
    let suggestedMusicId: String?
    var durationSeconds: Double { endSeconds - startSeconds }
}

struct PublishedClip: Codable, Identifiable {
    let id: String
    let sourceVideoId: String
    let flickId: String?
    let storyId: String?
    let publishedAt: Date
}

@MainActor
final class SmartClippingService: ObservableObject {
    static let shared = SmartClippingService()
    private init() {}

    @Published private(set) var candidates: [SmartClip] = []
    @Published private(set) var isScanning: Bool = false

    // MARK: - Detection

    func detect(videoId: String, maxClips: Int = 5) async throws -> [SmartClip] {
        guard AppConfig.Features.enableSmartClipping else { return [] }
        isScanning = true
        defer { isScanning = false }

        struct Request: Encodable {
            let task: String
            let videoId: String
            let maxClips: Int
        }
        struct RawClip: Decodable {
            let id: String
            let start_seconds: Double
            let end_seconds: Double
            let score: Double?
            let reason: String?
            let suggested_caption: String?
            let suggested_music_id: String?
        }
        struct Raw: Decodable { let clips: [RawClip]? }

        let r: Raw = try await CloudRunAgentRouter.post(
            .shortsOptimizer,
            path: "/predict",
            body: Request(task: "detect_highlights", videoId: videoId, maxClips: maxClips),
            timeout: 60
        )
        let clips = (r.clips ?? []).map {
            SmartClip(
                id: $0.id,
                videoId: videoId,
                startSeconds: $0.start_seconds,
                endSeconds: $0.end_seconds,
                score: $0.score ?? 0,
                reason: $0.reason ?? "highlight",
                suggestedCaption: $0.suggested_caption ?? "",
                suggestedMusicId: $0.suggested_music_id
            )
        }.sorted { $0.score > $1.score }
        candidates = clips
        return clips
    }

    // MARK: - Publish

    /// Publish a clip as a Flick. Backend handles trim+encode+Storage upload.
    func publishAsFlick(_ clip: SmartClip, creatorUid: String) async throws -> PublishedClip {
        guard AppConfig.Features.enableSmartClipping else { throw ClipError.disabled }
        struct Request: Encodable {
            let task: String
            let videoId: String
            let start: Double
            let end: Double
            let caption: String
            let musicId: String?
            let creatorUid: String
        }
        struct Raw: Decodable {
            let id: String
            let flick_id: String?
            let story_id: String?
            let published_at: Double?
        }
        let r: Raw = try await CloudRunAgentRouter.post(
            .shortsOptimizer,
            path: "/predict",
            body: Request(
                task: "publish_flick",
                videoId: clip.videoId,
                start: clip.startSeconds,
                end: clip.endSeconds,
                caption: clip.suggestedCaption,
                musicId: clip.suggestedMusicId,
                creatorUid: creatorUid
            ),
            timeout: 60
        )
        return PublishedClip(
            id: r.id,
            sourceVideoId: clip.videoId,
            flickId: r.flick_id,
            storyId: r.story_id,
            publishedAt: r.published_at.map { Date(timeIntervalSince1970: $0) } ?? Date()
        )
    }

    enum ClipError: LocalizedError {
        case disabled
        var errorDescription: String? { "Smart Clipping is disabled." }
    }
}
