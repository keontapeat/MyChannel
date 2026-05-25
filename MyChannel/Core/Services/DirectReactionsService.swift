//
//  DirectReactionsService.swift
//  MyChannel
//
//  Direct reactions: emoji reactions, reaction counts,
//  reaction analytics per content. Uses `mychannel-events` Cloud Run.
//

import Foundation

struct DirectReaction: Codable, Identifiable {
    let id: String
    let contentId: String
    let userId: String
    let emoji: String
    let createdAt: Date
}

struct ReactionSummary: Codable {
    let contentId: String
    let total: Int
    let breakdown: [String: Int]
    let topEmoji: String
}

@MainActor
final class DirectReactionsService: ObservableObject {
    static let shared = DirectReactionsService()
    private init() {}
    @Published private(set) var myReactions: [DirectReaction] = []

    func react(contentId: String, userId: String, emoji: String) async throws -> DirectReaction {
        struct Req: Encodable { let task: String; let contentId: String; let userId: String; let emoji: String }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelEvents, path: "/predict",
            body: Req(task: "add_reaction", contentId: contentId, userId: userId, emoji: emoji))
        let reaction = DirectReaction(id: r.id, contentId: contentId, userId: userId, emoji: emoji, createdAt: Date())
        myReactions.append(reaction); return reaction
    }

    func removeReaction(reactionId: String) async throws {
        struct Req: Encodable { let task: String; let reactionId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.myChannelEvents, path: "/predict",
            body: Req(task: "remove_reaction", reactionId: reactionId))
        myReactions.removeAll { $0.id == reactionId }
    }

    func fetchSummary(contentId: String) async throws -> ReactionSummary {
        struct Req: Encodable { let task: String; let contentId: String }
        struct Raw: Decodable { let total: Int?; let breakdown: [String: Int]?; let top: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelEvents, path: "/predict",
            body: Req(task: "fetch_reaction_summary", contentId: contentId))
        return ReactionSummary(contentId: contentId, total: r.total ?? 0, breakdown: r.breakdown ?? [:], topEmoji: r.top ?? "❤️")
    }
}
