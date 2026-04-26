//
//  CommunitySpacesService.swift
//  MyChannel
//
//  Phase 121: Community Spaces.
//  Persistent topic-based rooms with threads, roles, reactions,
//  and creator moderation tools. Firestore-backed, `super-ai-team` ranking.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct CommunitySpace: Codable, Identifiable, Equatable {
    let id: String
    let channelId: String
    let name: String
    let description: String
    let iconURL: URL?
    let memberCount: Int
    let threadCount: Int
    let visibility: SpaceVisibility
    let createdAt: Date
}

enum SpaceVisibility: String, Codable { case publicSpace = "public", membersOnly, private_ = "private" }

struct SpaceThread: Codable, Identifiable, Equatable {
    let id: String
    let spaceId: String
    let authorUid: String
    let authorName: String
    let title: String
    let body: String
    let replyCount: Int
    let reactionCounts: [String: Int]
    let pinned: Bool
    let createdAt: Date
}

struct SpaceReply: Codable, Identifiable {
    let id: String
    let threadId: String
    let authorUid: String
    let authorName: String
    let body: String
    let reactionCounts: [String: Int]
    let createdAt: Date
}

enum SpaceRole: String, Codable, CaseIterable { case owner, moderator, member, viewer }

// MARK: - Service

@MainActor
final class CommunitySpacesService: ObservableObject {
    static let shared = CommunitySpacesService()
    private init() {}

    @Published private(set) var spaces: [CommunitySpace] = []
    @Published private(set) var threads: [SpaceThread] = []

    func loadSpaces(channelId: String) async throws {
        guard AppConfig.Features.enableCommunitySpaces else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("community_spaces")
            .whereField("channelId", isEqualTo: channelId)
            .order(by: "memberCount", descending: true)
            .getDocuments()
        spaces = snap.documents.compactMap { doc in
            let d = doc.data()
            return CommunitySpace(
                id: doc.documentID,
                channelId: d["channelId"] as? String ?? "",
                name: d["name"] as? String ?? "",
                description: d["description"] as? String ?? "",
                iconURL: (d["iconURL"] as? String).flatMap(URL.init(string:)),
                memberCount: d["memberCount"] as? Int ?? 0,
                threadCount: d["threadCount"] as? Int ?? 0,
                visibility: SpaceVisibility(rawValue: d["visibility"] as? String ?? "") ?? .publicSpace,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func createSpace(channelId: String, name: String, description: String, visibility: SpaceVisibility) async throws -> String {
        guard AppConfig.Features.enableCommunitySpaces else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("community_spaces").document()
        try await ref.setData([
            "channelId": channelId, "name": name, "description": description,
            "visibility": visibility.rawValue, "memberCount": 1, "threadCount": 0,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func loadThreads(spaceId: String) async throws {
        guard AppConfig.Features.enableCommunitySpaces else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("community_threads")
            .whereField("spaceId", isEqualTo: spaceId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        threads = snap.documents.compactMap { doc in
            let d = doc.data()
            return SpaceThread(
                id: doc.documentID, spaceId: d["spaceId"] as? String ?? "",
                authorUid: d["authorUid"] as? String ?? "", authorName: d["authorName"] as? String ?? "",
                title: d["title"] as? String ?? "", body: d["body"] as? String ?? "",
                replyCount: d["replyCount"] as? Int ?? 0,
                reactionCounts: d["reactionCounts"] as? [String: Int] ?? [:],
                pinned: d["pinned"] as? Bool ?? false,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func postThread(spaceId: String, authorUid: String, authorName: String, title: String, body: String) async throws {
        guard AppConfig.Features.enableCommunitySpaces else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("community_threads").document().setData([
            "spaceId": spaceId, "authorUid": authorUid, "authorName": authorName,
            "title": title, "body": body, "replyCount": 0, "pinned": false,
            "createdAt": FieldValue.serverTimestamp()
        ])
        try await Firestore.firestore().collection("community_spaces").document(spaceId)
            .updateData(["threadCount": FieldValue.increment(Int64(1))])
        #endif
    }

    func react(threadId: String, emoji: String) async throws {
        guard AppConfig.Features.enableCommunitySpaces else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("community_threads").document(threadId)
            .updateData(["reactionCounts.\(emoji)": FieldValue.increment(Int64(1))])
        #endif
    }

    func moderateThread(threadId: String, action: String) async throws {
        guard AppConfig.Features.enableCommunitySpaces else { return }
        struct Request: Encodable { let task: String; let threadId: String; let action: String }
        struct Raw: Decodable { let status: String? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Request(task: "moderate_thread", threadId: threadId, action: action)
        )
    }
}
