//
//  ProfileAudioIdentityService.swift
//  MyChannel
//
//  Phase 242: Profile Music & Audio Identity.
//  Profile theme song, ambient audio background,
//  sound-reactive banner animations, audio fingerprinting.
//  Uses `voice-ai-v2` + `mychannel-content` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProfileAudioIdentity: Codable, Identifiable {
    let id: String
    let creatorId: String
    let themeSongURL: String?
    let ambientAudioURL: String?
    let introClipURL: String?
    let volume: Double
    let autoPlay: Bool
    let isMutedByDefault: Bool
    let updatedAt: Date
}

struct SoundReaction: Codable, Identifiable {
    let id: String
    let creatorId: String
    let trigger: String
    let soundURL: String
    let animationType: String
}

// MARK: - Service

@MainActor
final class ProfileAudioIdentityService: ObservableObject {
    static let shared = ProfileAudioIdentityService()
    private init() {}

    @Published private(set) var audioIdentity: ProfileAudioIdentity?
    @Published private(set) var reactions: [SoundReaction] = []
    @Published var isPlaying: Bool = false

    func fetchAudioIdentity(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileAudioIdentity else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let id: String; let theme_song: String?; let ambient: String?; let intro: String?; let volume: Double?; let auto_play: Bool?; let muted_default: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "fetch_audio_identity", creatorId: creatorId)
        )
        audioIdentity = ProfileAudioIdentity(id: r.id, creatorId: creatorId,
                                               themeSongURL: r.theme_song, ambientAudioURL: r.ambient,
                                               introClipURL: r.intro, volume: r.volume ?? 0.5,
                                               autoPlay: r.auto_play ?? false, isMutedByDefault: r.muted_default ?? true,
                                               updatedAt: Date())
    }

    func updateAudioIdentity(creatorId: String, themeSongURL: String?, ambientURL: String?, volume: Double, autoPlay: Bool) async throws {
        guard AppConfig.Features.enableProfileAudioIdentity else { return }
        struct Req: Encodable { let task: String; let creatorId: String; let theme_song: String?; let ambient: String?; let volume: Double; let auto_play: Bool }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "update_audio_identity", creatorId: creatorId,
                      theme_song: themeSongURL, ambient: ambientURL, volume: volume, auto_play: autoPlay)
        )
        audioIdentity = ProfileAudioIdentity(id: audioIdentity?.id ?? "", creatorId: creatorId,
                                               themeSongURL: themeSongURL, ambientAudioURL: ambientURL,
                                               introClipURL: audioIdentity?.introClipURL,
                                               volume: volume, autoPlay: autoPlay,
                                               isMutedByDefault: audioIdentity?.isMutedByDefault ?? true, updatedAt: Date())
    }

    func fetchSoundReactions(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileAudioIdentity else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawR: Decodable { let id: String; let trigger: String; let sound: String; let animation: String }
        struct Raw: Decodable { let reactions: [RawR]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .voiceAIv2, path: "/predict",
            body: Req(task: "fetch_sound_reactions", creatorId: creatorId)
        )
        reactions = (r.reactions ?? []).map {
            SoundReaction(id: $0.id, creatorId: creatorId, trigger: $0.trigger, soundURL: $0.sound, animationType: $0.animation)
        }
    }

    func generateAudioFingerprint(creatorId: String, audioURL: String) async throws -> String {
        guard AppConfig.Features.enableProfileAudioIdentity else { return "" }
        struct Req: Encodable { let task: String; let creatorId: String; let audioURL: String }
        struct Raw: Decodable { let fingerprint: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .voiceAIv2, path: "/predict",
            body: Req(task: "generate_audio_fingerprint", creatorId: creatorId, audioURL: audioURL)
        )
        return r.fingerprint ?? ""
    }
}
