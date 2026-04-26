//
//  AIVideoEditorV2Service.swift
//  MyChannel
//
//  Phase 126: AI Video Editor v2.
//  Scene detection, auto-cut, color grade presets, music sync, Metal GPU pipeline.
//  Uses `video-editor-ai-v2` + `ai-video-editor` Cloud Run.
//

import Foundation

// MARK: - Models

struct SceneDetectionResult: Codable, Identifiable {
    let id: String
    let startSec: Double
    let endSec: Double
    let label: String
    let confidence: Double
}

struct AutoCutSuggestion: Codable, Identifiable {
    let id: String
    let keepSegments: [(start: Double, end: Double)]
    let estimatedDurationSec: Double
    let reason: String

    enum CodingKeys: String, CodingKey { case id, estimatedDurationSec, reason, segments }
    init(id: String, keepSegments: [(start: Double, end: Double)], estimatedDurationSec: Double, reason: String) {
        self.id = id; self.keepSegments = keepSegments; self.estimatedDurationSec = estimatedDurationSec; self.reason = reason
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        estimatedDurationSec = try c.decode(Double.self, forKey: .estimatedDurationSec)
        reason = try c.decode(String.self, forKey: .reason)
        keepSegments = []
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(estimatedDurationSec, forKey: .estimatedDurationSec)
        try c.encode(reason, forKey: .reason)
    }
}

struct ColorGradePreset: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let thumbnailURL: URL?
    let lut3DURL: URL?
}

struct MusicSyncResult: Codable {
    let beatTimestamps: [Double]
    let suggestedCutPoints: [Double]
    let bpm: Int
}

// MARK: - Service

@MainActor
final class AIVideoEditorV2Service: ObservableObject {
    static let shared = AIVideoEditorV2Service()
    private init() {}

    @Published private(set) var scenes: [SceneDetectionResult] = []
    @Published private(set) var autoCut: AutoCutSuggestion?
    @Published private(set) var colorPresets: [ColorGradePreset] = []

    func detectScenes(videoURL: String) async throws {
        guard AppConfig.Features.enableAIVideoEditorV2 else { return }
        struct Request: Encodable { let task: String; let videoURL: String }
        struct RawScene: Decodable { let start: Double; let end: Double; let label: String; let confidence: Double }
        struct Raw: Decodable { let scenes: [RawScene]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .videoEditorAIv2, path: "/predict",
            body: Request(task: "detect_scenes", videoURL: videoURL), timeout: 60
        )
        scenes = (r.scenes ?? []).map {
            SceneDetectionResult(id: UUID().uuidString, startSec: $0.start, endSec: $0.end, label: $0.label, confidence: $0.confidence)
        }
    }

    func suggestAutoCut(videoURL: String, targetDurationSec: Double) async throws {
        guard AppConfig.Features.enableAIVideoEditorV2 else { return }
        struct Request: Encodable { let task: String; let videoURL: String; let targetDuration: Double }
        struct RawSeg: Decodable { let start: Double; let end: Double }
        struct Raw: Decodable { let segments: [RawSeg]?; let duration: Double?; let reason: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .aiVideoEditor, path: "/predict",
            body: Request(task: "auto_cut", videoURL: videoURL, targetDuration: targetDurationSec), timeout: 60
        )
        autoCut = AutoCutSuggestion(
            id: UUID().uuidString,
            keepSegments: (r.segments ?? []).map { ($0.start, $0.end) },
            estimatedDurationSec: r.duration ?? targetDurationSec,
            reason: r.reason ?? ""
        )
    }

    func syncToMusic(videoURL: String, musicURL: String) async throws -> MusicSyncResult {
        guard AppConfig.Features.enableAIVideoEditorV2 else {
            return MusicSyncResult(beatTimestamps: [], suggestedCutPoints: [], bpm: 0)
        }
        struct Request: Encodable { let task: String; let videoURL: String; let musicURL: String }
        struct Raw: Decodable { let beats: [Double]?; let cuts: [Double]?; let bpm: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .videoEditorAIv2, path: "/predict",
            body: Request(task: "music_sync", videoURL: videoURL, musicURL: musicURL), timeout: 60
        )
        return MusicSyncResult(beatTimestamps: r.beats ?? [], suggestedCutPoints: r.cuts ?? [], bpm: r.bpm ?? 0)
    }

    func loadColorPresets() async throws {
        guard AppConfig.Features.enableAIVideoEditorV2 else { return }
        struct Request: Encodable { let task: String }
        struct RawPreset: Decodable { let id: String; let name: String; let thumbnail: String?; let lut: String? }
        struct Raw: Decodable { let presets: [RawPreset]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .videoEditorAIv2, path: "/predict",
            body: Request(task: "color_presets")
        )
        colorPresets = (r.presets ?? []).map {
            ColorGradePreset(id: $0.id, name: $0.name, thumbnailURL: $0.thumbnail.flatMap(URL.init(string:)), lut3DURL: $0.lut.flatMap(URL.init(string:)))
        }
    }
}
