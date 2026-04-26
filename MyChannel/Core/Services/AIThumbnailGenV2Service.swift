//
//  AIThumbnailGenV2Service.swift
//  MyChannel
//
//  Phase 166: AI Thumbnail Generator v2.
//  A/B test thumbnails, CTR prediction, dynamic personalization.
//  Uses `thumbnail-gen-ai` Cloud Run.
//

import Foundation
import UIKit

// MARK: - Models

struct GeneratedThumbnailVariant: Codable, Identifiable {
    let id: String
    let videoId: String
    let imageURL: URL?
    let predictedCTR: Double
    let style: String
    let isControl: Bool
    let impressions: Int
    let clicks: Int
}

struct ThumbnailABTest: Codable, Identifiable {
    let id: String
    let videoId: String
    let variants: [GeneratedThumbnailVariant]
    let status: String
    let winnerVariantId: String?
    let startedAt: Date
}

// MARK: - Service

@MainActor
final class AIThumbnailGenV2Service: ObservableObject {
    static let shared = AIThumbnailGenV2Service()
    private init() {}

    @Published private(set) var variants: [GeneratedThumbnailVariant] = []
    @Published private(set) var activeTest: ThumbnailABTest?
    @Published var isGenerating: Bool = false

    func generateVariants(videoId: String, count: Int = 4) async throws {
        guard AppConfig.Features.enableAIThumbnailGenV2 else { return }
        isGenerating = true
        defer { isGenerating = false }
        struct Request: Encodable { let task: String; let videoId: String; let count: Int }
        struct RawVariant: Decodable { let url: String; let ctr: Double; let style: String }
        struct Raw: Decodable { let variants: [RawVariant]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .thumbnailGenerator, path: "/predict",
            body: Request(task: "generate_thumbnails", videoId: videoId, count: count), timeout: 60
        )
        variants = (r.variants ?? []).enumerated().map { idx, v in
            GeneratedThumbnailVariant(id: UUID().uuidString, videoId: videoId,
                           imageURL: URL(string: v.url), predictedCTR: v.ctr,
                           style: v.style, isControl: idx == 0, impressions: 0, clicks: 0)
        }
    }

    func predictCTR(videoId: String, thumbnailURL: String) async throws -> Double {
        guard AppConfig.Features.enableAIThumbnailGenV2 else { return 0 }
        struct Request: Encodable { let task: String; let videoId: String; let thumbnail: String }
        struct Raw: Decodable { let ctr: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .thumbnailGenerator, path: "/predict",
            body: Request(task: "predict_ctr", videoId: videoId, thumbnail: thumbnailURL)
        )
        return r.ctr ?? 0
    }

    func startABTest(videoId: String, variantIds: [String]) async throws -> String {
        guard AppConfig.Features.enableAIThumbnailGenV2 else { return "" }
        let test = ThumbnailABTest(id: UUID().uuidString, videoId: videoId,
                                   variants: variants.filter { variantIds.contains($0.id) },
                                   status: "running", winnerVariantId: nil, startedAt: Date())
        activeTest = test
        return test.id
    }
}
