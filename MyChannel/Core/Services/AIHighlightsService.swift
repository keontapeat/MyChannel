//
//  AIHighlightsService.swift
//  MyChannel
//
//  Phase 193: Personalized AI Highlights.
//  Auto-generated personal highlight reels, best-of compilations.
//  Uses `recommendations` Cloud Run.
//

import Foundation

// MARK: - Models

struct HighlightReel: Codable, Identifiable {
    let id: String
    let uid: String
    let title: String
    let clips: [HighlightClip]
    let totalDurationSec: Double
    let generatedAt: Date
}

struct HighlightClip: Codable, Identifiable {
    let id: String
    let videoId: String
    let videoTitle: String
    let startSec: Double
    let endSec: Double
    let reason: String
    let thumbnailURL: URL?
}

// MARK: - Service

@MainActor
final class AIHighlightsService: ObservableObject {
    static let shared = AIHighlightsService()
    private init() {}

    @Published private(set) var reels: [HighlightReel] = []
    @Published var isGenerating: Bool = false

    func generatePersonalHighlights(uid: String, maxDurationMin: Int = 5) async throws {
        guard AppConfig.Features.enableAIHighlights else { return }
        isGenerating = true; defer { isGenerating = false }
        struct Request: Encodable { let task: String; let uid: String; let max_duration: Int }
        struct RawClip: Decodable { let video_id: String; let title: String; let start: Double; let end: Double; let reason: String; let thumb: String? }
        struct Raw: Decodable { let reel_id: String?; let title: String?; let clips: [RawClip]?; let duration: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .recommendations, path: "/predict",
            body: Request(task: "personal_highlights", uid: uid, max_duration: maxDurationMin * 60), timeout: 60
        )
        let reel = HighlightReel(
            id: r.reel_id ?? UUID().uuidString, uid: uid, title: r.title ?? "Your Highlights",
            clips: (r.clips ?? []).map {
                HighlightClip(id: UUID().uuidString, videoId: $0.video_id, videoTitle: $0.title,
                            startSec: $0.start, endSec: $0.end, reason: $0.reason,
                            thumbnailURL: $0.thumb.flatMap(URL.init(string:)))
            },
            totalDurationSec: r.duration ?? 0, generatedAt: Date()
        )
        reels.insert(reel, at: 0)
    }

    func generateBestOf(creatorUid: String, period: String) async throws {
        guard AppConfig.Features.enableAIHighlights else { return }
        isGenerating = true; defer { isGenerating = false }
        struct Request: Encodable { let task: String; let creatorUid: String; let period: String }
        struct RawClip: Decodable { let video_id: String; let title: String; let start: Double; let end: Double; let reason: String; let thumb: String? }
        struct Raw: Decodable { let reel_id: String?; let title: String?; let clips: [RawClip]?; let duration: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .recommendations, path: "/predict",
            body: Request(task: "best_of", creatorUid: creatorUid, period: period), timeout: 60
        )
        let reel = HighlightReel(
            id: r.reel_id ?? UUID().uuidString, uid: creatorUid, title: r.title ?? "Best Of",
            clips: (r.clips ?? []).map {
                HighlightClip(id: UUID().uuidString, videoId: $0.video_id, videoTitle: $0.title,
                            startSec: $0.start, endSec: $0.end, reason: $0.reason,
                            thumbnailURL: $0.thumb.flatMap(URL.init(string:)))
            },
            totalDurationSec: r.duration ?? 0, generatedAt: Date()
        )
        reels.insert(reel, at: 0)
    }
}
