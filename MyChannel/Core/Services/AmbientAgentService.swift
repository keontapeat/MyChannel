//
//  AmbientAgentService.swift
//  MyChannel
//
//  Phase 76: Ambient Agent Layer.
//  Surfaces proactive, context-aware suggestions via App Intents / Siri
//  (e.g. "resume last video", "clip this", "subscribe?"). Pulls signals
//  from the current player, recent history, and the `autoplay-intelligence`
//  agent.
//

import Foundation
#if canImport(AppIntents)
import AppIntents
#endif

enum AmbientSuggestionKind: String, Codable {
    case resumeLast
    case clipThis
    case subscribe
    case saveForLater
    case nextInSeries
    case shareToFriend
    case startWatchParty
}

struct AmbientSuggestion: Codable, Identifiable, Equatable {
    let id: String
    let kind: AmbientSuggestionKind
    let title: String
    let subtitle: String?
    let videoId: String?
    let creatorId: String?
    let score: Double           // 0..1 — rendering priority
    let expiresAt: Date?
}

@MainActor
final class AmbientAgentService: ObservableObject {
    static let shared = AmbientAgentService()
    private init() {}

    @Published private(set) var suggestions: [AmbientSuggestion] = []

    /// Compute context-aware suggestions. Call on app foreground and after
    /// major user actions (finishing a video, unsubscribing, etc.).
    func refresh(
        userId: String?,
        currentVideoId: String?,
        lastWatchedVideoId: String?,
        hasResumablePosition: Bool
    ) async {
        guard AppConfig.Features.enableAmbientAgent else {
            suggestions = []
            return
        }

        struct Request: Encodable {
            let task: String
            let userId: String?
            let currentVideoId: String?
            let lastWatchedVideoId: String?
            let hasResumablePosition: Bool
        }
        struct RawItem: Decodable {
            let id: String
            let kind: String
            let title: String
            let subtitle: String?
            let video_id: String?
            let creator_id: String?
            let score: Double?
            let expires_at: Double?
        }
        struct Raw: Decodable { let items: [RawItem]? }

        do {
            let r: Raw = try await CloudRunAgentRouter.post(
                .autoplayIntelligence,
                path: "/predict",
                body: Request(
                    task: "ambient_suggestions",
                    userId: userId,
                    currentVideoId: currentVideoId,
                    lastWatchedVideoId: lastWatchedVideoId,
                    hasResumablePosition: hasResumablePosition
                )
            )
            suggestions = (r.items ?? []).compactMap { item in
                guard let kind = AmbientSuggestionKind(rawValue: item.kind) else { return nil }
                return AmbientSuggestion(
                    id: item.id,
                    kind: kind,
                    title: item.title,
                    subtitle: item.subtitle,
                    videoId: item.video_id,
                    creatorId: item.creator_id,
                    score: item.score ?? 0,
                    expiresAt: item.expires_at.map { Date(timeIntervalSince1970: $0) }
                )
            }.sorted { $0.score > $1.score }
        } catch {
            suggestions = []
        }
    }

    /// The single most-important suggestion to surface right now (banner, widget, Siri tip).
    var topSuggestion: AmbientSuggestion? {
        suggestions.first(where: { $0.expiresAt.map { $0 > Date() } ?? true })
    }
}

// MARK: - App Intents (Siri / Shortcuts)

#if canImport(AppIntents)
@available(iOS 16.0, *)
struct ResumeLastVideoIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume My Last Video"
    static var description: IntentDescription = "Opens MyChannel and resumes your last video where you left off."

    func perform() async throws -> some IntentResult {
        // The concrete deep-link handler in DeepLinkManager will pick this up.
        return .result()
    }
}

@available(iOS 16.0, *)
struct OpenAskMyChannelIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask MyChannel"
    static var description: IntentDescription = "Opens the AskMyChannel assistant."

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
#endif
