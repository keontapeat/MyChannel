//
//  ConversationalSearchService.swift
//  MyChannel
//
//  Phase 77: Voice-first multi-turn search.
//  Wraps `super-ai-team` for NL understanding + `search-ranking-ai` for
//  candidate retrieval, with transcript-grounded citations.
//  Works alongside the existing `VoiceSearchService` for audio capture.
//

import Foundation

struct ConversationalHit: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let title: String
    let thumbnailURL: URL?
    let creatorName: String
    /// The transcript timestamp to seek to when the user taps this hit.
    let citationSeconds: Double?
    let snippet: String        // transcript excerpt
    let score: Double
}

struct ConversationalReply: Codable {
    let text: String           // natural-language summary answer
    let hits: [ConversationalHit]
    let followUps: [String]    // suggested follow-up queries
}

@MainActor
final class ConversationalSearchService: ObservableObject {
    static let shared = ConversationalSearchService()
    private init() {}

    @Published private(set) var isThinking: Bool = false
    @Published private(set) var history: [HistoryTurn] = []

    struct HistoryTurn: Codable, Identifiable, Equatable {
        let id: String
        let userText: String
        let assistantText: String
        let createdAt: Date
    }

    private let maxHistory = 12

    // MARK: - Ask

    func ask(_ text: String, userId: String?) async throws -> ConversationalReply {
        guard AppConfig.Features.enableConversationalSearch else {
            throw CSError.disabled
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CSError.empty }

        isThinking = true
        defer { isThinking = false }

        struct HistoryEntry: Encodable {
            let user: String
            let assistant: String
        }
        struct Request: Encodable {
            let task: String
            let userId: String?
            let message: String
            let history: [HistoryEntry]
        }
        struct RawHit: Decodable {
            let id: String
            let video_id: String
            let title: String
            let thumbnail_url: String?
            let creator_name: String
            let citation_seconds: Double?
            let snippet: String
            let score: Double?
        }
        struct Raw: Decodable {
            let text: String?
            let hits: [RawHit]?
            let follow_ups: [String]?
        }

        let payload = Request(
            task: "conversational_search",
            userId: userId,
            message: trimmed,
            history: history.suffix(maxHistory).map {
                HistoryEntry(user: $0.userText, assistant: $0.assistantText)
            }
        )

        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam,
            path: "/predict",
            body: payload,
            timeout: 30
        )

        let hits = (r.hits ?? []).map {
            ConversationalHit(
                id: $0.id,
                videoId: $0.video_id,
                title: $0.title,
                thumbnailURL: $0.thumbnail_url.flatMap(URL.init),
                creatorName: $0.creator_name,
                citationSeconds: $0.citation_seconds,
                snippet: $0.snippet,
                score: $0.score ?? 0
            )
        }

        let answer = r.text ?? "I'm not sure — try rephrasing."
        history.append(HistoryTurn(
            id: UUID().uuidString,
            userText: trimmed,
            assistantText: answer,
            createdAt: Date()
        ))
        if history.count > maxHistory {
            history.removeFirst(history.count - maxHistory)
        }

        return ConversationalReply(
            text: answer,
            hits: hits,
            followUps: r.follow_ups ?? []
        )
    }

    func reset() {
        history.removeAll()
    }

    enum CSError: LocalizedError {
        case disabled, empty
        var errorDescription: String? {
            switch self {
            case .disabled: return "Conversational search is disabled."
            case .empty: return "Ask me something."
            }
        }
    }
}
