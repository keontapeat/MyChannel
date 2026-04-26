//
//  AIMusicComposerService.swift
//  MyChannel
//
//  Phase 133: AI Music Composer.
//  Royalty-free soundtrack generation per-video mood, beat-sync to edits.
//  Uses `ai-music` + `ai-music-v2` Cloud Run.
//

import Foundation

// MARK: - Models

struct ComposedMusicTrack: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let genre: ComposerMusicGenre
    let mood: String
    let durationSec: Double
    let bpm: Int
    let audioURL: URL?
    let waveformURL: URL?
    let royaltyFree: Bool
}

enum ComposerMusicGenre: String, Codable, CaseIterable {
    case cinematic, electronic, lofi, pop, rock, hiphop, ambient, classical, jazz, acoustic
}

struct MusicGenerationRequest: Codable {
    let videoId: String?
    let mood: String
    let genre: ComposerMusicGenre
    let durationSec: Double
    let bpm: Int?
}

struct BeatSyncResult: Codable {
    let beatTimestamps: [Double]
    let suggestedCuts: [Double]
    let matchScore: Double
}

// MARK: - Service

@MainActor
final class AIMusicComposerService: ObservableObject {
    static let shared = AIMusicComposerService()
    private init() {}

    @Published private(set) var generatedTracks: [ComposedMusicTrack] = []
    @Published private(set) var libraryTracks: [ComposedMusicTrack] = []

    func compose(request: MusicGenerationRequest) async throws -> ComposedMusicTrack {
        guard AppConfig.Features.enableAIMusicComposer else {
            return ComposedMusicTrack(id: "", title: "", genre: request.genre, mood: request.mood,
                            durationSec: request.durationSec, bpm: request.bpm ?? 120,
                            audioURL: nil, waveformURL: nil, royaltyFree: true)
        }
        struct Request: Encodable { let task: String; let videoId: String?; let mood: String; let genre: String; let duration: Double; let bpm: Int? }
        struct Raw: Decodable { let track_id: String?; let title: String?; let audio_url: String?; let waveform_url: String?; let bpm: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .aiMusicv2, path: "/predict",
            body: Request(task: "compose", videoId: request.videoId, mood: request.mood,
                         genre: request.genre.rawValue, duration: request.durationSec, bpm: request.bpm),
            timeout: 90
        )
        let track = ComposedMusicTrack(
            id: r.track_id ?? UUID().uuidString, title: r.title ?? "AI Track",
            genre: request.genre, mood: request.mood,
            durationSec: request.durationSec, bpm: r.bpm ?? request.bpm ?? 120,
            audioURL: r.audio_url.flatMap(URL.init(string:)),
            waveformURL: r.waveform_url.flatMap(URL.init(string:)), royaltyFree: true
        )
        generatedTracks.append(track)
        return track
    }

    func composeForVideo(videoId: String) async throws -> ComposedMusicTrack {
        guard AppConfig.Features.enableAIMusicComposer else {
            return ComposedMusicTrack(id: "", title: "", genre: .ambient, mood: "neutral",
                            durationSec: 0, bpm: 120, audioURL: nil, waveformURL: nil, royaltyFree: true)
        }
        struct Request: Encodable { let task: String; let videoId: String }
        struct Raw: Decodable { let mood: String?; let genre: String?; let duration: Double?; let bpm: Int?; let audio_url: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .aiMusic, path: "/predict",
            body: Request(task: "compose_for_video", videoId: videoId), timeout: 90
        )
        let track = ComposedMusicTrack(
            id: UUID().uuidString, title: "Auto-composed for \(videoId)",
            genre: ComposerMusicGenre(rawValue: r.genre ?? "") ?? .ambient,
            mood: r.mood ?? "neutral", durationSec: r.duration ?? 60,
            bpm: r.bpm ?? 120, audioURL: r.audio_url.flatMap(URL.init(string:)),
            waveformURL: nil, royaltyFree: true
        )
        generatedTracks.append(track)
        return track
    }

    func beatSync(videoURL: String, audioURL: String) async throws -> BeatSyncResult {
        guard AppConfig.Features.enableAIMusicComposer else {
            return BeatSyncResult(beatTimestamps: [], suggestedCuts: [], matchScore: 0)
        }
        struct Request: Encodable { let task: String; let videoURL: String; let audioURL: String }
        struct Raw: Decodable { let beats: [Double]?; let cuts: [Double]?; let score: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .aiMusicv2, path: "/predict",
            body: Request(task: "beat_sync", videoURL: videoURL, audioURL: audioURL), timeout: 60
        )
        return BeatSyncResult(beatTimestamps: r.beats ?? [], suggestedCuts: r.cuts ?? [], matchScore: r.score ?? 0)
    }

    func browseLibrary(genre: ComposerMusicGenre? = nil) async throws {
        guard AppConfig.Features.enableAIMusicComposer else { return }
        struct Request: Encodable { let task: String; let genre: String? }
        struct RawTrack: Decodable { let id: String; let title: String; let genre: String; let mood: String; let duration: Double; let bpm: Int; let url: String? }
        struct Raw: Decodable { let tracks: [RawTrack]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .aiMusic, path: "/predict",
            body: Request(task: "browse_library", genre: genre?.rawValue)
        )
        libraryTracks = (r.tracks ?? []).map {
            ComposedMusicTrack(id: $0.id, title: $0.title, genre: ComposerMusicGenre(rawValue: $0.genre) ?? .ambient,
                      mood: $0.mood, durationSec: $0.duration, bpm: $0.bpm,
                      audioURL: $0.url.flatMap(URL.init(string:)), waveformURL: nil, royaltyFree: true)
        }
    }
}
