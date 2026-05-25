//
//  FanClubsService.swift
//  MyChannel
//
//  Phase 123: Fan Clubs & Badges.
//  Tiered fan programs, collectible badges, leaderboard, milestone unlocks.
//  Uses `engagement-booster-ai` for milestone tracking.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct FanClub: Codable, Identifiable, Equatable {
    let id: String
    let channelId: String
    let name: String
    let tiers: [FanTier]
    let memberCount: Int
    let createdAt: Date
}

struct FanTier: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let minPoints: Int
    let badgeIconURL: URL?
    let perks: [String]
}

struct FanMembership: Codable, Identifiable, Equatable {
    let id: String
    let clubId: String
    let uid: String
    let points: Int
    let currentTierId: String
    let badges: [FanBadge]
    let joinedAt: Date
}

struct FanBadge: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let iconURL: URL?
    let unlockedAt: Date
    let rarity: BadgeRarity
}

enum BadgeRarity: String, Codable { case common, rare, epic, legendary }

struct FanClubLeaderboardEntry: Codable, Identifiable {
    let id: String
    let uid: String
    let displayName: String
    let points: Int
    let rank: Int
}

// MARK: - Service

@MainActor
final class FanClubsService: ObservableObject {
    static let shared = FanClubsService()
    private init() {}

    @Published private(set) var club: FanClub?
    @Published private(set) var membership: FanMembership?
    @Published private(set) var leaderboard: [FanClubLeaderboardEntry] = []

    func loadClub(channelId: String) async throws {
        guard AppConfig.Features.enableFanClubs else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("fan_clubs").whereField("channelId", isEqualTo: channelId)
            .limit(to: 1).getDocuments()
        guard let doc = snap.documents.first else { return }
        let d = doc.data()
        club = FanClub(
            id: doc.documentID, channelId: d["channelId"] as? String ?? "",
            name: d["name"] as? String ?? "",
            tiers: (d["tiers"] as? [[String: Any]])?.compactMap { t in
                FanTier(id: t["id"] as? String ?? UUID().uuidString, name: t["name"] as? String ?? "",
                        minPoints: t["minPoints"] as? Int ?? 0,
                        badgeIconURL: (t["badgeIconURL"] as? String).flatMap(URL.init(string:)),
                        perks: t["perks"] as? [String] ?? [])
            } ?? [],
            memberCount: d["memberCount"] as? Int ?? 0,
            createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
        #endif
    }

    func loadMembership(clubId: String, uid: String) async throws {
        guard AppConfig.Features.enableFanClubs else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("fan_memberships")
            .whereField("clubId", isEqualTo: clubId)
            .whereField("uid", isEqualTo: uid)
            .limit(to: 1).getDocuments()
        guard let doc = snap.documents.first else { return }
        membership = try? doc.data(as: FanMembership.self)
        #endif
    }

    func awardPoints(clubId: String, uid: String, points: Int) async throws {
        guard AppConfig.Features.enableFanClubs else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("fan_memberships")
            .whereField("clubId", isEqualTo: clubId)
            .whereField("uid", isEqualTo: uid)
            .limit(to: 1).getDocuments()
        if let doc = snap.documents.first {
            try await doc.reference.updateData(["points": FieldValue.increment(Int64(points))])
        }
        #endif
    }

    func checkMilestones(clubId: String, uid: String) async throws -> [FanBadge] {
        guard AppConfig.Features.enableFanClubs else { return [] }
        struct Request: Encodable { let task: String; let clubId: String; let uid: String }
        struct RawBadge: Decodable { let name: String; let icon_url: String?; let rarity: String }
        struct Raw: Decodable { let new_badges: [RawBadge]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .engagementBooster, path: "/predict",
            body: Request(task: "check_milestones", clubId: clubId, uid: uid)
        )
        return (r.new_badges ?? []).map {
            FanBadge(id: UUID().uuidString, name: $0.name, iconURL: $0.icon_url.flatMap(URL.init(string:)),
                     unlockedAt: Date(), rarity: BadgeRarity(rawValue: $0.rarity) ?? .common)
        }
    }

    func loadLeaderboard(clubId: String) async throws {
        guard AppConfig.Features.enableFanClubs else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("fan_memberships")
            .whereField("clubId", isEqualTo: clubId)
            .order(by: "points", descending: true)
            .limit(to: 50).getDocuments()
        leaderboard = snap.documents.enumerated().map { idx, doc in
            let d = doc.data()
            return FanClubLeaderboardEntry(id: doc.documentID, uid: d["uid"] as? String ?? "",
                                   displayName: d["displayName"] as? String ?? "", points: d["points"] as? Int ?? 0, rank: idx + 1)
        }
        #endif
    }
}
