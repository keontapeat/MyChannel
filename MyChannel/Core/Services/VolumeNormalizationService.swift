//
//  VolumeNormalizationService.swift
//  MyChannel
//
//  Audio volume normalization: loudness detection, target LUFS,
//  dynamic range compression, per-video normalization.
//  Uses `voice-ai-v2` Cloud Run.
//

import Foundation

struct VolumeProfile: Codable, Identifiable {
    let id: String
    let videoId: String
    let integratedLUFS: Double
    let truePeak: Double
    let loudnessRange: Double
    let targetLUFS: Double
    let isNormalized: Bool
    let normalizedAudioURL: String?
}

@MainActor
final class VolumeNormalizationService: ObservableObject {
    static let shared = VolumeNormalizationService()
    private init() {}
    @Published private(set) var profiles: [String: VolumeProfile] = [:]
    private let targetLUFS: Double = -14.0

    func analyzeVolume(videoId: String) async throws -> VolumeProfile {
        struct Req: Encodable { let task: String; let videoId: String }
        struct Raw: Decodable { let id: String; let lufs: Double?; let peak: Double?; let range: Double?; let normalized: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.voiceAIv2, path: "/predict",
            body: Req(task: "analyze_volume", videoId: videoId))
        let profile = VolumeProfile(id: r.id, videoId: videoId, integratedLUFS: r.lufs ?? -14, truePeak: r.peak ?? -1,
            loudnessRange: r.range ?? 10, targetLUFS: targetLUFS, isNormalized: r.normalized != nil, normalizedAudioURL: r.normalized)
        profiles[videoId] = profile; return profile
    }

    func normalize(videoId: String, targetLUFS: Double = -14.0) async throws -> VolumeProfile {
        struct Req: Encodable { let task: String; let videoId: String; let target: Double }
        struct Raw: Decodable { let id: String; let lufs: Double?; let peak: Double?; let range: Double?; let url: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.voiceAIv2, path: "/predict",
            body: Req(task: "normalize_volume", videoId: videoId, target: targetLUFS), timeout: 60)
        let profile = VolumeProfile(id: r.id, videoId: videoId, integratedLUFS: r.lufs ?? targetLUFS, truePeak: r.peak ?? -1,
            loudnessRange: r.range ?? 5, targetLUFS: targetLUFS, isNormalized: true, normalizedAudioURL: r.url)
        profiles[videoId] = profile; return profile
    }
}
