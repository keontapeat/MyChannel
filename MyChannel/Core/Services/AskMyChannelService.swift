//
//  AskMyChannelService.swift
//  MyChannel
//
//  Phase 31: "Ask MyChannel" AI assistant using super-ai-team Cloud Run.
//  Natural language Q&A, video search intents, and summarization.
//

import Foundation

// MARK: - Models

enum AskMyChannelIntent: String, Codable {
    case search           // "Find cooking videos"
    case summarize        // "Summarize this video"
    case recommend        // "What should I watch tonight?"
    case answer           // Freeform Q&A
}

struct AskMyChannelMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable { case user, assistant, system }
    let id: String
    let role: Role
    let text: String
    let createdAt: Date

    init(id: String = UUID().uuidString, role: Role, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

struct AskMyChannelReply: Codable {
    let text: String
    let intent: AskMyChannelIntent
    /// Optional video IDs the assistant suggests the user open.
    let videoIds: [String]
    /// Optional follow-up quick replies.
    let suggestions: [String]
}

// MARK: - Service

@MainActor
final class AskMyChannelService: ObservableObject {
    static let shared = AskMyChannelService()
    private init() {}

    @Published private(set) var conversation: [AskMyChannelMessage] = []
    @Published private(set) var isThinking: Bool = false
    @Published var lastError: String?

    private let maxHistory = 24

    func reset() {
        conversation.removeAll()
        lastError = nil
    }

    /// Send a user message and await the assistant reply.
    func send(_ userText: String, videoContextId: String? = nil) async throws -> AskMyChannelReply {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AskError.emptyMessage }

        conversation.append(AskMyChannelMessage(role: .user, text: trimmed))
        trimHistory()

        isThinking = true
        lastError = nil
        defer { isThinking = false }

        struct HistoryTurn: Encodable {
            let role: String
            let text: String
        }

        struct Request: Encodable {
            let task: String
            let userId: String
            let message: String
            let history: [HistoryTurn]
            let videoContextId: String?
        }

        struct RawReply: Decodable {
            let text: String?
            let intent: String?
            let video_ids: [String]?
            let suggestions: [String]?
        }

        let history = conversation.suffix(maxHistory).map {
            HistoryTurn(role: $0.role.rawValue, text: $0.text)
        }

        let req = Request(
            task: "ask_mychannel",
            userId: currentUserId(),
            message: trimmed,
            history: history,
            videoContextId: videoContextId
        )

        do {
            let raw: RawReply = try await CloudRunAgentRouter.post(
                .superAITeam,
                path: "/predict",
                body: req,
                timeout: 30
            )

            let intent = AskMyChannelIntent(rawValue: raw.intent ?? "answer") ?? .answer
            let replyText = (raw.text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                ?? "I'm not sure yet — try rephrasing."

            let reply = AskMyChannelReply(
                text: replyText,
                intent: intent,
                videoIds: raw.video_ids ?? [],
                suggestions: raw.suggestions ?? []
            )

            conversation.append(AskMyChannelMessage(role: .assistant, text: replyText))
            trimHistory()
            return reply
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Helpers

    private func trimHistory() {
        if conversation.count > maxHistory {
            conversation.removeFirst(conversation.count - maxHistory)
        }
    }

    private func currentUserId() -> String {
        AuthenticationManager.shared.currentUser?.id ?? "anonymous"
    }

    enum AskError: LocalizedError {
        case emptyMessage
        var errorDescription: String? {
            switch self {
            case .emptyMessage: return "Please type a question."
            }
        }
    }
}
