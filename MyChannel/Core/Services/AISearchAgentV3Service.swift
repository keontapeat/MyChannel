//
//  AISearchAgentV3Service.swift
//  MyChannel
//
//  Phase 113: AI Search Agent v3.
//  Multi-modal query (text/voice/image), answer cards with citations,
//  follow-up chaining. Uses `search-ranking-ai` + `super-ai-team`.
//

import Foundation

// MARK: - Models

struct MultimodalSearchQuery: Codable {
    let text: String?
    let imageData: Data?       // base64-encoded for Cloud Run
    let voiceTranscript: String?
    let conversationId: String?  // for follow-up chaining
}

struct AnswerCard: Codable, Identifiable {
    let id: String
    let summary: String
    let citations: [Citation]
    let confidence: Double
}

struct Citation: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let title: String
    let timestampSec: Int?
    let snippet: String
}

struct SearchV3Result: Codable {
    let answerCard: AnswerCard?
    let videoResults: [SearchVideoHit]
    let followUpSuggestions: [String]
    let conversationId: String
}

struct SearchVideoHit: Codable, Identifiable {
    let id: String          // videoId
    let title: String
    let thumbnailURL: URL?
    let relevanceScore: Double
}

// MARK: - Service

@MainActor
final class AISearchAgentV3Service: ObservableObject {
    static let shared = AISearchAgentV3Service()
    private init() {}

    @Published private(set) var latestResult: SearchV3Result?
    @Published private(set) var conversationHistory: [SearchV3Result] = []

    func multiModalQuery(_ query: MultimodalSearchQuery) async throws -> SearchV3Result {
        guard AppConfig.Features.enableAISearchV3 else {
            return SearchV3Result(answerCard: nil, videoResults: [], followUpSuggestions: [], conversationId: "")
        }
        struct Request: Encodable {
            let task: String; let text: String?; let voiceTranscript: String?
            let imageBase64: String?; let conversationId: String?
        }
        struct RawCitation: Decodable { let video_id: String; let title: String; let timestamp_sec: Int?; let snippet: String }
        struct RawCard: Decodable { let summary: String; let citations: [RawCitation]?; let confidence: Double? }
        struct RawVideo: Decodable { let video_id: String; let title: String; let thumbnail_url: String?; let score: Double }
        struct Raw: Decodable { let answer_card: RawCard?; let videos: [RawVideo]?; let follow_ups: [String]?; let conversation_id: String? }

        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam,
            path: "/predict",
            body: Request(
                task: "search_v3",
                text: query.text,
                voiceTranscript: query.voiceTranscript,
                imageBase64: query.imageData?.base64EncodedString(),
                conversationId: query.conversationId
            ),
            timeout: 45
        )

        let card: AnswerCard? = r.answer_card.map { ac in
            AnswerCard(
                id: UUID().uuidString,
                summary: ac.summary,
                citations: (ac.citations ?? []).map {
                    Citation(id: UUID().uuidString, videoId: $0.video_id, title: $0.title, timestampSec: $0.timestamp_sec, snippet: $0.snippet)
                },
                confidence: ac.confidence ?? 0
            )
        }

        let result = SearchV3Result(
            answerCard: card,
            videoResults: (r.videos ?? []).map {
                SearchVideoHit(id: $0.video_id, title: $0.title, thumbnailURL: $0.thumbnail_url.flatMap(URL.init(string:)), relevanceScore: $0.score)
            },
            followUpSuggestions: r.follow_ups ?? [],
            conversationId: r.conversation_id ?? UUID().uuidString
        )
        latestResult = result
        conversationHistory.append(result)
        return result
    }

    func continueChain(followUp: String) async throws -> SearchV3Result {
        let convId = latestResult?.conversationId
        return try await multiModalQuery(MultimodalSearchQuery(text: followUp, imageData: nil, voiceTranscript: nil, conversationId: convId))
    }

    func clearConversation() {
        latestResult = nil
        conversationHistory.removeAll()
    }
}
