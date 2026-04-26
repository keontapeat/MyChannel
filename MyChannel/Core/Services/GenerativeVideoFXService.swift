//
//  GenerativeVideoFXService.swift
//  MyChannel
//
//  Phase 195: Generative Video Effects.
//  AI background replace, style transfer, aging filter.
//  Uses `video-editor-ai-v2` Cloud Run.
//

import Foundation

// MARK: - Models

struct VideoEffect: Codable, Identifiable {
    let id: String
    let name: String
    let category: EffectCategory
    let thumbnailURL: URL?
    let isPremium: Bool
}

enum EffectCategory: String, Codable, CaseIterable {
    case backgroundReplace, styleTransfer, aging, colorGrade, particleOverlay, textToVideo
}

struct EffectJob: Codable, Identifiable {
    let id: String
    let videoId: String
    let effectId: String
    let status: String
    let progressPercent: Int
    let outputURL: URL?
}

// MARK: - Service

@MainActor
final class GenerativeVideoFXService: ObservableObject {
    static let shared = GenerativeVideoFXService()
    private init() {}

    @Published private(set) var effects: [VideoEffect] = []
    @Published private(set) var activeJob: EffectJob?
    @Published var isProcessing: Bool = false

    func loadEffects() {
        guard AppConfig.Features.enableGenerativeVideoFX else { return }
        effects = [
            VideoEffect(id: "bg-beach", name: "Beach Background", category: .backgroundReplace, thumbnailURL: nil, isPremium: false),
            VideoEffect(id: "bg-office", name: "Modern Office", category: .backgroundReplace, thumbnailURL: nil, isPremium: false),
            VideoEffect(id: "style-anime", name: "Anime Style", category: .styleTransfer, thumbnailURL: nil, isPremium: true),
            VideoEffect(id: "style-oil", name: "Oil Painting", category: .styleTransfer, thumbnailURL: nil, isPremium: true),
            VideoEffect(id: "age-young", name: "Youth Filter", category: .aging, thumbnailURL: nil, isPremium: true),
            VideoEffect(id: "age-old", name: "Aging Filter", category: .aging, thumbnailURL: nil, isPremium: true),
            VideoEffect(id: "color-cinema", name: "Cinematic", category: .colorGrade, thumbnailURL: nil, isPremium: false),
        ]
    }

    func applyEffect(videoId: String, effectId: String) async throws -> EffectJob {
        guard AppConfig.Features.enableGenerativeVideoFX else {
            return EffectJob(id: "", videoId: videoId, effectId: effectId, status: "disabled", progressPercent: 0, outputURL: nil)
        }
        isProcessing = true; defer { isProcessing = false }
        struct Request: Encodable { let task: String; let videoId: String; let effectId: String }
        struct Raw: Decodable { let job_id: String?; let status: String?; let output: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .videoEditorAIv2, path: "/predict",
            body: Request(task: "apply_effect", videoId: videoId, effectId: effectId), timeout: 120
        )
        let job = EffectJob(id: r.job_id ?? UUID().uuidString, videoId: videoId, effectId: effectId,
                           status: r.status ?? "processing", progressPercent: 0,
                           outputURL: r.output.flatMap(URL.init(string:)))
        activeJob = job
        return job
    }

    func replaceBackground(videoId: String, backgroundPrompt: String) async throws -> EffectJob {
        guard AppConfig.Features.enableGenerativeVideoFX else {
            return EffectJob(id: "", videoId: videoId, effectId: "bg-custom", status: "disabled", progressPercent: 0, outputURL: nil)
        }
        struct Request: Encodable { let task: String; let videoId: String; let prompt: String }
        struct Raw: Decodable { let job_id: String?; let output: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .videoEditorAIv2, path: "/predict",
            body: Request(task: "replace_background", videoId: videoId, prompt: backgroundPrompt), timeout: 120
        )
        let job = EffectJob(id: r.job_id ?? UUID().uuidString, videoId: videoId, effectId: "bg-custom",
                           status: "processing", progressPercent: 0, outputURL: r.output.flatMap(URL.init(string:)))
        activeJob = job
        return job
    }
}
