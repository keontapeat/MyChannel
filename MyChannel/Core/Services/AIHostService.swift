//
//  AIHostService.swift
//  MyChannel
//
//  Phase 78: Personalized AI Host.
//  Every evening the user gets a 60-second digest narrated by their chosen
//  avatar+voice. Built from feed highlights, creator milestones, and trends.
//  Voice cloning is strictly opt-in (MyChannel Plus+ Pro feature).
//

import Foundation

struct AIHostVoice: Codable, Identifiable, Equatable {
    let id: String                // "mychannel.default" / "mychannel.warm" / custom-cloned
    let displayName: String
    let previewURL: URL?
    let isCloned: Bool
}

struct AIHostAvatar: Codable, Identifiable, Equatable {
    let id: String
    let displayName: String
    let thumbnailURL: URL?
    let stylePack: String         // "neon" / "news" / "cozy"
}

struct AIHostDigest: Codable, Identifiable {
    let id: String
    let userUid: String
    let generatedAt: Date
    let durationSeconds: Double
    let audioURL: URL             // narrated track
    let videoURL: URL?            // avatar + visuals (optional)
    let script: String            // transcript
    let highlights: [Highlight]

    struct Highlight: Codable, Identifiable, Equatable {
        let id: String
        let videoId: String
        let title: String
        let thumbnailURL: URL?
        let creatorName: String
    }
}

@MainActor
final class AIHostService: ObservableObject {
    static let shared = AIHostService()
    private init() {}

    @Published private(set) var availableVoices: [AIHostVoice] = []
    @Published private(set) var availableAvatars: [AIHostAvatar] = []
    @Published private(set) var todaysDigest: AIHostDigest?
    @Published private(set) var isGenerating: Bool = false

    // MARK: - Catalog

    func loadCatalog() async throws {
        guard AppConfig.Features.enableAIHost else { return }
        struct Request: Encodable { let task: String }
        struct RawVoice: Decodable {
            let id: String
            let display_name: String
            let preview_url: String?
            let is_cloned: Bool?
        }
        struct RawAvatar: Decodable {
            let id: String
            let display_name: String
            let thumbnail_url: String?
            let style_pack: String?
        }
        struct Raw: Decodable {
            let voices: [RawVoice]?
            let avatars: [RawAvatar]?
        }

        let r: Raw = try await CloudRunAgentRouter.post(
            .aiAvatarv2,
            path: "/predict",
            body: Request(task: "catalog")
        )
        availableVoices = (r.voices ?? []).map {
            AIHostVoice(
                id: $0.id,
                displayName: $0.display_name,
                previewURL: $0.preview_url.flatMap(URL.init),
                isCloned: $0.is_cloned ?? false
            )
        }
        availableAvatars = (r.avatars ?? []).map {
            AIHostAvatar(
                id: $0.id,
                displayName: $0.display_name,
                thumbnailURL: $0.thumbnail_url.flatMap(URL.init),
                stylePack: $0.style_pack ?? "default"
            )
        }
    }

    // MARK: - Nightly digest

    func generateDigest(userUid: String, voiceId: String, avatarId: String?) async throws -> AIHostDigest {
        guard AppConfig.Features.enableAIHost else { throw AIHostError.disabled }
        isGenerating = true
        defer { isGenerating = false }

        struct Request: Encodable {
            let task: String
            let userUid: String
            let voiceId: String
            let avatarId: String?
        }
        struct RawH: Decodable {
            let id: String
            let video_id: String
            let title: String
            let thumbnail_url: String?
            let creator_name: String
        }
        struct Raw: Decodable {
            let id: String
            let duration_seconds: Double?
            let audio_url: String
            let video_url: String?
            let script: String?
            let highlights: [RawH]?
        }

        let raw: Raw = try await CloudRunAgentRouter.post(
            .aiAvatarv2,
            path: "/predict",
            body: Request(task: "generate_digest", userUid: userUid, voiceId: voiceId, avatarId: avatarId),
            timeout: 120
        )
        guard let audio = URL(string: raw.audio_url) else { throw AIHostError.badResponse }
        let digest = AIHostDigest(
            id: raw.id,
            userUid: userUid,
            generatedAt: Date(),
            durationSeconds: raw.duration_seconds ?? 60,
            audioURL: audio,
            videoURL: raw.video_url.flatMap(URL.init),
            script: raw.script ?? "",
            highlights: (raw.highlights ?? []).map {
                AIHostDigest.Highlight(
                    id: $0.id,
                    videoId: $0.video_id,
                    title: $0.title,
                    thumbnailURL: $0.thumbnail_url.flatMap(URL.init),
                    creatorName: $0.creator_name
                )
            }
        )
        todaysDigest = digest
        return digest
    }

    enum AIHostError: LocalizedError {
        case disabled, badResponse
        var errorDescription: String? {
            switch self {
            case .disabled: return "AI Host is disabled."
            case .badResponse: return "Invalid host response."
            }
        }
    }
}
