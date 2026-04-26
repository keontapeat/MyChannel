//
//  AutoDubService.swift
//  MyChannel
//
//  Auto-dubbing: AI voice translation for video content.
//  Language detection, voice cloning, lip sync. Uses `voice-ai-v2` Cloud Run.
//

import Foundation

struct DubTrack: Codable, Identifiable {
    let id: String
    let videoId: String
    let sourceLanguage: String
    let targetLanguage: String
    let audioURL: String?
    let status: DubStatus
    let createdAt: Date
    let voiceId: String?
    enum DubStatus: String, Codable { case queued, processing, completed, failed }
}

@MainActor
final class AutoDubService: ObservableObject {
    static let shared = AutoDubService()
    private init() {}
    @Published private(set) var tracks: [DubTrack] = []
    @Published var isDubbing: Bool = false

    func requestDub(videoId: String, sourceLang: String, targetLang: String, voiceId: String? = nil) async throws -> DubTrack {
        isDubbing = true; defer { isDubbing = false }
        struct Req: Encodable { let task: String; let videoId: String; let source: String; let target: String; let voiceId: String? }
        struct Raw: Decodable { let id: String; let status: String; let audio: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.voiceAIv2, path: "/predict",
            body: Req(task: "request_dub", videoId: videoId, source: sourceLang, target: targetLang, voiceId: voiceId), timeout: 60)
        let track = DubTrack(id: r.id, videoId: videoId, sourceLanguage: sourceLang, targetLanguage: targetLang,
            audioURL: r.audio, status: .init(rawValue: r.status) ?? .queued, createdAt: Date(), voiceId: voiceId)
        tracks.append(track); return track
    }

    func checkStatus(trackId: String) async throws -> DubTrack? {
        struct Req: Encodable { let task: String; let trackId: String }
        struct Raw: Decodable { let status: String; let audio: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.voiceAIv2, path: "/predict",
            body: Req(task: "check_dub_status", trackId: trackId))
        if let idx = tracks.firstIndex(where: { $0.id == trackId }) {
            let old = tracks[idx]
            tracks[idx] = DubTrack(id: old.id, videoId: old.videoId, sourceLanguage: old.sourceLanguage, targetLanguage: old.targetLanguage,
                audioURL: r.audio ?? old.audioURL, status: .init(rawValue: r.status) ?? old.status, createdAt: old.createdAt, voiceId: old.voiceId)
            return tracks[idx]
        }
        return nil
    }

    func fetchAvailableLanguages() async throws -> [String] {
        struct Req: Encodable { let task: String }
        struct Raw: Decodable { let languages: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(.voiceAIv2, path: "/predict", body: Req(task: "fetch_dub_languages"))
        return r.languages ?? ["en", "es", "fr", "de", "ja", "ko", "pt", "zh"]
    }
}
