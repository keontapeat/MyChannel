//
//  AIAudioDescriptionService.swift
//  MyChannel
//
//  Phase 211: AI Audio Descriptions — auto-generated scene narration
//  for blind users. Uses `super-ai-team` Cloud Run.
//

import Foundation

struct AudioDescriptionTrack: Codable, Identifiable {
    let id: String
    let videoId: String
    let language: String
    let segments: [DescriptionSegment]
    let generatedAt: Date
    struct DescriptionSegment: Codable { let startSec: Double; let endSec: Double; let text: String }
}

@MainActor
final class AIAudioDescriptionService: ObservableObject {
    static let shared = AIAudioDescriptionService()
    private init() {}
    @Published private(set) var tracks: [AudioDescriptionTrack] = []
    @Published var isGenerating: Bool = false

    func generateDescription(videoId: String, language: String = "en") async throws -> AudioDescriptionTrack {
        guard AppConfig.Features.enableAIAudioDescription else { return AudioDescriptionTrack(id: "", videoId: videoId, language: language, segments: [], generatedAt: Date()) }
        isGenerating = true; defer { isGenerating = false }
        struct Req: Encodable { let task: String; let videoId: String; let language: String }
        struct RawSeg: Decodable { let start: Double; let end: Double; let text: String }
        struct Raw: Decodable { let id: String; let segments: [RawSeg]? }
        let r: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict",
            body: Req(task: "generate_audio_description", videoId: videoId, language: language), timeout: 60)
        let track = AudioDescriptionTrack(id: r.id, videoId: videoId, language: language,
            segments: (r.segments ?? []).map { AudioDescriptionTrack.DescriptionSegment(startSec: $0.start, endSec: $0.end, text: $0.text) }, generatedAt: Date())
        tracks.append(track); return track
    }

    func fetchTrack(videoId: String, language: String = "en") async throws -> AudioDescriptionTrack? {
        struct Req: Encodable { let task: String; let videoId: String; let language: String }
        struct RawSeg: Decodable { let start: Double; let end: Double; let text: String }
        struct Raw: Decodable { let id: String; let segments: [RawSeg]? }
        let r: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict",
            body: Req(task: "fetch_audio_description", videoId: videoId, language: language))
        guard !r.id.isEmpty else { return nil }
        return AudioDescriptionTrack(id: r.id, videoId: videoId, language: language,
            segments: (r.segments ?? []).map { AudioDescriptionTrack.DescriptionSegment(startSec: $0.start, endSec: $0.end, text: $0.text) }, generatedAt: Date())
    }

    func editSegment(trackId: String, index: Int, newText: String) {
        guard let tIdx = tracks.firstIndex(where: { $0.id == trackId }), index < tracks[tIdx].segments.count else { return }
        var segs = tracks[tIdx].segments
        segs[index] = AudioDescriptionTrack.DescriptionSegment(startSec: segs[index].startSec, endSec: segs[index].endSec, text: newText)
        tracks[tIdx] = AudioDescriptionTrack(id: tracks[tIdx].id, videoId: tracks[tIdx].videoId, language: tracks[tIdx].language, segments: segs, generatedAt: tracks[tIdx].generatedAt)
    }
}
