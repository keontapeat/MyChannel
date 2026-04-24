//
//  GenerativeThumbnailService.swift
//  MyChannel
//
//  Phase 80: Generative Thumbnails & Titles at publish time.
//  Wraps `thumbnail-gen-v2` + `title-gen-ai` for inline preview in the
//  uploader, with CTR-predicted ranking from `creative-performance-predictor`.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct GeneratedCreative: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let thumbnailURL: URL
    let ctrScore: Double         // 0..1 predicted CTR
    let rationale: String        // short explainer
}

@MainActor
final class GenerativeThumbnailService: ObservableObject {
    static let shared = GenerativeThumbnailService()
    private init() {}

    @Published private(set) var variants: [GeneratedCreative] = []
    @Published private(set) var isGenerating: Bool = false

    // MARK: - Generate

    /// Given a draft video (title idea + storage ref + optional script), return
    /// N title+thumbnail pairs ranked by predicted CTR.
    func generate(
        videoId: String,
        workingTitle: String,
        videoStorageURL: URL,
        tone: String = "energetic",
        count: Int = 4
    ) async throws -> [GeneratedCreative] {
        guard AppConfig.Features.enableGenerativeThumbnails else { return [] }
        isGenerating = true
        defer { isGenerating = false }

        struct Request: Encodable {
            let task: String
            let videoId: String
            let workingTitle: String
            let videoStorageURL: String
            let tone: String
            let count: Int
        }
        struct RawItem: Decodable {
            let id: String
            let title: String
            let thumbnail_url: String
            let ctr_score: Double?
            let rationale: String?
        }
        struct Raw: Decodable { let variants: [RawItem]? }

        let r: Raw = try await CloudRunAgentRouter.post(
            .thumbnailGen,
            path: "/predict",
            body: Request(
                task: "generate_variants",
                videoId: videoId,
                workingTitle: workingTitle,
                videoStorageURL: videoStorageURL.absoluteString,
                tone: tone,
                count: count
            ),
            timeout: 60
        )

        let result = (r.variants ?? []).compactMap { item -> GeneratedCreative? in
            guard let url = URL(string: item.thumbnail_url) else { return nil }
            return GeneratedCreative(
                id: item.id,
                title: item.title,
                thumbnailURL: url,
                ctrScore: item.ctr_score ?? 0,
                rationale: item.rationale ?? ""
            )
        }.sorted { $0.ctrScore > $1.ctrScore }
        variants = result
        return result
    }

    // MARK: - Score a single existing creative

    /// Ask `creative-performance-predictor` how the current title+thumbnail compare.
    func scoreExisting(title: String, thumbnailURL: URL) async throws -> Double {
        guard AppConfig.Features.enableGenerativeThumbnails else { return 0 }
        struct Request: Encodable {
            let task: String
            let title: String
            let thumbnail_url: String
        }
        struct Raw: Decodable { let ctr_score: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creativePerformance,
            path: "/predict",
            body: Request(task: "score", title: title, thumbnail_url: thumbnailURL.absoluteString)
        )
        return r.ctr_score ?? 0
    }

    // MARK: - A/B apply (ties into Phase 8 AI Thumbnail Studio)

    /// Attach a chosen generated creative to a video as the canonical.
    func applyChoice(videoId: String, choice: GeneratedCreative) async throws {
        guard AppConfig.Features.enableGenerativeThumbnails else { throw GenError.disabled }
        struct Request: Encodable {
            let task: String
            let videoId: String
            let chosenId: String
            let thumbnailURL: String
            let title: String
        }
        _ = try await CloudRunAgentRouter.post(
            .thumbnailGen,
            path: "/predict",
            body: Request(
                task: "apply_choice",
                videoId: videoId,
                chosenId: choice.id,
                thumbnailURL: choice.thumbnailURL.absoluteString,
                title: choice.title
            )
        ) as _Ack
    }

    private struct _Ack: Decodable { let ok: Bool? }

    enum GenError: LocalizedError {
        case disabled
        var errorDescription: String? { "Generative thumbnails are disabled." }
    }
}
