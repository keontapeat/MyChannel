//
//  CreatorGuildsService.swift
//  MyChannel
//
//  Phase 136: Creator Guilds & Collectives.
//  Shared revenue pools, cross-promotion engine, collective bargaining tools.
//  Uses `creator-relations-ai` + `creator-fund-allocator`.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct CreatorGuild: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let founderUid: String
    let memberUids: [String]
    let revenuePoolEnabled: Bool
    let revenueShareModel: RevenueShareModel
    let createdAt: Date
}

enum RevenueShareModel: String, Codable { case equal, proportional, custom }

struct GuildMember: Codable, Identifiable, Equatable {
    let id: String
    let guildId: String
    let uid: String
    let displayName: String
    let role: GuildRole
    let revenueSharePercent: Double
    let joinedAt: Date
}

enum GuildRole: String, Codable { case founder, officer, member }

struct CrossPromotion: Codable, Identifiable {
    let id: String
    let guildId: String
    let sourceCreatorUid: String
    let targetCreatorUid: String
    let videoId: String
    let impressions: Int
    let clicks: Int
    let status: String
}

struct CollectiveDeal: Codable, Identifiable {
    let id: String
    let guildId: String
    let brandName: String
    let totalBudgetUSD: Double
    let memberAllocations: [String: Double]
    let status: String
    let createdAt: Date
}

// MARK: - Service

@MainActor
final class CreatorGuildsService: ObservableObject {
    static let shared = CreatorGuildsService()
    init() {}

    @Published private(set) var guilds: [CreatorGuild] = []
    @Published private(set) var members: [GuildMember] = []
    @Published private(set) var promotions: [CrossPromotion] = []

    func loadGuilds(uid: String) async throws {
        guard AppConfig.Features.enableCreatorGuilds else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("creator_guilds").whereField("memberUids", arrayContains: uid).getDocuments()
        guilds = snap.documents.compactMap { doc in
            let d = doc.data()
            return CreatorGuild(
                id: doc.documentID, name: d["name"] as? String ?? "",
                description: d["description"] as? String ?? "",
                founderUid: d["founderUid"] as? String ?? "",
                memberUids: d["memberUids"] as? [String] ?? [],
                revenuePoolEnabled: d["revenuePoolEnabled"] as? Bool ?? false,
                revenueShareModel: RevenueShareModel(rawValue: d["revenueShareModel"] as? String ?? "") ?? .equal,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func createGuild(name: String, description: String, founderUid: String, revenueModel: RevenueShareModel) async throws -> String {
        guard AppConfig.Features.enableCreatorGuilds else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("creator_guilds").document()
        try await ref.setData([
            "name": name, "description": description, "founderUid": founderUid,
            "memberUids": [founderUid], "revenuePoolEnabled": true,
            "revenueShareModel": revenueModel.rawValue, "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func inviteMember(guildId: String, uid: String) async throws {
        guard AppConfig.Features.enableCreatorGuilds else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("creator_guilds").document(guildId)
            .updateData(["memberUids": FieldValue.arrayUnion([uid])])
        try await Firestore.firestore().collection("guild_members").document().setData([
            "guildId": guildId, "uid": uid, "role": GuildRole.member.rawValue,
            "revenueSharePercent": 0, "joinedAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func generateCrossPromo(guildId: String) async throws {
        guard AppConfig.Features.enableCreatorGuilds else { return }
        struct Request: Encodable { let task: String; let guildId: String }
        struct RawPromo: Decodable { let source: String; let target: String; let video_id: String }
        struct Raw: Decodable { let promotions: [RawPromo]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Request(task: "cross_promo", guildId: guildId)
        )
        promotions = (r.promotions ?? []).map {
            CrossPromotion(id: UUID().uuidString, guildId: guildId, sourceCreatorUid: $0.source,
                          targetCreatorUid: $0.target, videoId: $0.video_id,
                          impressions: 0, clicks: 0, status: "active")
        }
    }

    func allocateRevenue(guildId: String) async throws -> [String: Double] {
        guard AppConfig.Features.enableCreatorGuilds else { return [:] }
        struct Request: Encodable { let task: String; let guildId: String }
        struct Raw: Decodable { let allocations: [String: Double]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorFundAllocator, path: "/predict",
            body: Request(task: "allocate_revenue", guildId: guildId)
        )
        return r.allocations ?? [:]
    }
}
