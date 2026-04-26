//
//  BotFrameworkService.swift
//  MyChannel
//
//  Bot framework: chat bots, moderation bots, creator bots,
//  custom bot creation, webhook integration. Uses `super-ai-team` Cloud Run.
//

import Foundation

struct Bot: Codable, Identifiable {
    let id: String
    let name: String
    let creatorId: String
    let type: BotType
    let avatarURL: String?
    let isActive: Bool
    let commandPrefix: String
    let createdAt: Date
    enum BotType: String, Codable { case moderation, welcome, custom, analytics, engagement }
}

struct BotCommand: Codable, Identifiable {
    let id: String
    let botId: String
    let trigger: String
    let response: String
    let responseType: String
    let cooldownSec: Int
}

@MainActor
final class BotFrameworkService: ObservableObject {
    static let shared = BotFrameworkService()
    private init() {}
    @Published private(set) var bots: [Bot] = []

    func createBot(creatorId: String, name: String, type: Bot.BotType, prefix: String = "!") async throws -> Bot {
        struct Req: Encodable { let task: String; let creatorId: String; let name: String; let type: String; let prefix: String }
        struct Raw: Decodable { let id: String; let avatar: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict",
            body: Req(task: "create_bot", creatorId: creatorId, name: name, type: type.rawValue, prefix: prefix))
        let bot = Bot(id: r.id, name: name, creatorId: creatorId, type: type, avatarURL: r.avatar, isActive: true, commandPrefix: prefix, createdAt: Date())
        bots.append(bot); return bot
    }

    func addCommand(botId: String, trigger: String, response: String, cooldown: Int = 10) async throws {
        struct Req: Encodable { let task: String; let botId: String; let trigger: String; let response: String; let cooldown: Int }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict",
            body: Req(task: "add_bot_command", botId: botId, trigger: trigger, response: response, cooldown: cooldown))
    }

    func toggleBot(botId: String, active: Bool) async throws {
        struct Req: Encodable { let task: String; let botId: String; let active: Bool }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict",
            body: Req(task: "toggle_bot", botId: botId, active: active))
        if let idx = bots.firstIndex(where: { $0.id == botId }) {
            let old = bots[idx]
            bots[idx] = Bot(id: old.id, name: old.name, creatorId: old.creatorId, type: old.type, avatarURL: old.avatarURL, isActive: active, commandPrefix: old.commandPrefix, createdAt: old.createdAt)
        }
    }

    func deleteBot(botId: String) async throws {
        struct Req: Encodable { let task: String; let botId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict",
            body: Req(task: "delete_bot", botId: botId))
        bots.removeAll { $0.id == botId }
    }
}
