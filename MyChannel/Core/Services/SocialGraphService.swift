//
//  SocialGraphService.swift
//  MyChannel
//
//  Social graph: follower/following relationships, mutual connections,
//  graph traversal, community detection. Uses `creator-relations-ai` Cloud Run.
//

import Foundation

struct SocialGraphNode: Codable, Identifiable {
    let id: String
    let userId: String
    let displayName: String
    let followerCount: Int
    let followingCount: Int
    let mutualCount: Int
}

struct SocialConnection: Codable, Identifiable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let type: ConnectionType
    let createdAt: Date
    enum ConnectionType: String, Codable { case follow, mutual, block }
}

@MainActor
final class SocialGraphService: ObservableObject {
    static let shared = SocialGraphService()
    private init() {}
    @Published private(set) var followers: [SocialGraphNode] = []
    @Published private(set) var following: [SocialGraphNode] = []

    func fetchFollowers(userId: String, limit: Int = 50) async throws {
        struct Req: Encodable { let task: String; let userId: String; let limit: Int }
        struct RawN: Decodable { let id: String; let userId: String; let name: String; let followers: Int; let following: Int; let mutual: Int }
        struct Raw: Decodable { let nodes: [RawN]? }
        let r: Raw = try await CloudRunAgentRouter.post(.creatorRelationsAI, path: "/predict",
            body: Req(task: "fetch_followers", userId: userId, limit: limit))
        followers = (r.nodes ?? []).map { SocialGraphNode(id: $0.id, userId: $0.userId, displayName: $0.name, followerCount: $0.followers, followingCount: $0.following, mutualCount: $0.mutual) }
    }

    func fetchFollowing(userId: String, limit: Int = 50) async throws {
        struct Req: Encodable { let task: String; let userId: String; let limit: Int }
        struct RawN: Decodable { let id: String; let userId: String; let name: String; let followers: Int; let following: Int; let mutual: Int }
        struct Raw: Decodable { let nodes: [RawN]? }
        let r: Raw = try await CloudRunAgentRouter.post(.creatorRelationsAI, path: "/predict",
            body: Req(task: "fetch_following", userId: userId, limit: limit))
        following = (r.nodes ?? []).map { SocialGraphNode(id: $0.id, userId: $0.userId, displayName: $0.name, followerCount: $0.followers, followingCount: $0.following, mutualCount: $0.mutual) }
    }

    func follow(fromUserId: String, toUserId: String) async throws {
        struct Req: Encodable { let task: String; let from: String; let to: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.creatorRelationsAI, path: "/predict",
            body: Req(task: "follow_user", from: fromUserId, to: toUserId))
    }

    func unfollow(fromUserId: String, toUserId: String) async throws {
        struct Req: Encodable { let task: String; let from: String; let to: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.creatorRelationsAI, path: "/predict",
            body: Req(task: "unfollow_user", from: fromUserId, to: toUserId))
    }

    func mutualConnections(userIdA: String, userIdB: String) async throws -> [SocialGraphNode] {
        struct Req: Encodable { let task: String; let userA: String; let userB: String }
        struct RawN: Decodable { let id: String; let userId: String; let name: String; let followers: Int; let following: Int; let mutual: Int }
        struct Raw: Decodable { let mutual: [RawN]? }
        let r: Raw = try await CloudRunAgentRouter.post(.creatorRelationsAI, path: "/predict",
            body: Req(task: "mutual_connections", userA: userIdA, userB: userIdB))
        return (r.mutual ?? []).map { SocialGraphNode(id: $0.id, userId: $0.userId, displayName: $0.name, followerCount: $0.followers, followingCount: $0.following, mutualCount: $0.mutual) }
    }
}
