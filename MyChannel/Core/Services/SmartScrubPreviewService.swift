//
//  SmartScrubPreviewService.swift
//  MyChannel
//
//  Phase 144: Smart Scrub Previews.
//  Thumbnail strip on seek, frame-accurate sprite sheets, hover preview generation.
//

import Foundation
import UIKit
import AVFoundation

// MARK: - Models

struct SpriteSheet: Identifiable {
    let id: String          // videoId
    let imageURL: URL?
    let columns: Int
    let rows: Int
    let thumbWidth: Int
    let thumbHeight: Int
    let intervalSec: Double
    let totalFrames: Int
}

struct ScrubFrame: Identifiable {
    let id: Int             // frame index
    let image: UIImage
    let timestampSec: Double
}

// MARK: - Service

@MainActor
final class SmartScrubPreviewService: ObservableObject {
    static let shared = SmartScrubPreviewService()
    private init() {}

    @Published var spriteSheet: SpriteSheet?
    @Published var currentPreviewFrame: ScrubFrame?
    @Published var isGenerating: Bool = false

    private var imageGenerator: AVAssetImageGenerator?
    private var cachedFrames: [Int: UIImage] = [:]
    private let maxCacheSize = 200

    func prepareGenerator(for asset: AVAsset) {
        guard AppConfig.Features.enableSmartScrubPreviews else { return }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 90)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        imageGenerator = generator
    }

    func previewFrame(at fraction: Double, duration: Double) async -> UIImage? {
        guard AppConfig.Features.enableSmartScrubPreviews else { return nil }
        guard let generator = imageGenerator, duration > 0 else { return nil }

        let timestamp = fraction * duration
        let frameIndex = Int(timestamp / 2.0) // one frame every 2 seconds

        if let cached = cachedFrames[frameIndex] {
            currentPreviewFrame = ScrubFrame(id: frameIndex, image: cached, timestampSec: timestamp)
            return cached
        }

        let time = CMTime(seconds: timestamp, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: time)
            let image = UIImage(cgImage: cgImage)
            if cachedFrames.count >= maxCacheSize {
                cachedFrames.removeAll()
            }
            cachedFrames[frameIndex] = image
            currentPreviewFrame = ScrubFrame(id: frameIndex, image: image, timestampSec: timestamp)
            return image
        } catch {
            return nil
        }
    }

    func generateSpriteSheet(videoId: String, videoURL: String) async throws -> SpriteSheet? {
        guard AppConfig.Features.enableSmartScrubPreviews else { return nil }
        isGenerating = true
        defer { isGenerating = false }

        struct Request: Encodable { let task: String; let videoId: String; let videoURL: String; let interval: Double }
        struct Raw: Decodable { let url: String?; let cols: Int?; let rows: Int?; let width: Int?; let height: Int?; let total: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .videoEditorAIv2, path: "/predict",
            body: Request(task: "sprite_sheet", videoId: videoId, videoURL: videoURL, interval: 2.0),
            timeout: 120
        )
        let sheet = SpriteSheet(
            id: videoId, imageURL: r.url.flatMap(URL.init(string:)),
            columns: r.cols ?? 10, rows: r.rows ?? 10,
            thumbWidth: r.width ?? 160, thumbHeight: r.height ?? 90,
            intervalSec: 2.0, totalFrames: r.total ?? 0
        )
        spriteSheet = sheet
        return sheet
    }

    func clearCache() {
        cachedFrames.removeAll()
        imageGenerator = nil
        spriteSheet = nil
        currentPreviewFrame = nil
    }
}
