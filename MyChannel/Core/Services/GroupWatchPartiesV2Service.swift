//
//  GroupWatchPartiesV2Service.swift
//  MyChannel
//
//  Phase 125: Group Watch Parties v2.
//  Cross-platform sync (iOS/web/TV), shared queue, live reactions overlay.
//  Uses `live-stream-optimizer-ai` for sync quality.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct WatchPartyV2: Codable, Identifiable, Equatable {
    let id: String
    let hostUid: String
    let hostName: String
    let title: String
    let currentVideoId: String?
    let queue: [String]
    let participantCount: Int
    let syncTimestampSec: Double
    let isPlaying: Bool
    let reactionsEnabled: Bool
    let createdAt: Date
}

struct PartyParticipant: Codable, Identifiable, Equatable {
    let id: String
    let uid: String
    let displayName: String
    let platform: String   // "ios", "web", "tvos"
    let joinedAt: Date
}

struct PartyReaction: Codable {
    let uid: String
    let emoji: String
    let videoTimeSec: Double
    let timestamp: Date
}

// MARK: - Service

@MainActor
final class GroupWatchPartiesV2Service: ObservableObject {
    static let shared = GroupWatchPartiesV2Service()
    private init() {}

    @Published private(set) var activeParty: WatchPartyV2?
    @Published private(set) var participants: [PartyParticipant] = []

    func createParty(hostUid: String, hostName: String, title: String, firstVideoId: String) async throws -> String {
        guard AppConfig.Features.enableGroupWatchPartiesV2 else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("watch_parties_v2").document()
        try await ref.setData([
            "hostUid": hostUid, "hostName": hostName, "title": title,
            "currentVideoId": firstVideoId, "queue": [firstVideoId],
            "participantCount": 1, "syncTimestampSec": 0.0, "isPlaying": false,
            "reactionsEnabled": true, "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func joinParty(partyId: String, uid: String, displayName: String, platform: String) async throws {
        guard AppConfig.Features.enableGroupWatchPartiesV2 else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("watch_party_participants").document().setData([
            "partyId": partyId, "uid": uid, "displayName": displayName,
            "platform": platform, "joinedAt": FieldValue.serverTimestamp()
        ])
        try await Firestore.firestore().collection("watch_parties_v2").document(partyId)
            .updateData(["participantCount": FieldValue.increment(Int64(1))])
        #endif
    }

    func syncPlayback(partyId: String, timestampSec: Double, isPlaying: Bool) async throws {
        guard AppConfig.Features.enableGroupWatchPartiesV2 else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("watch_parties_v2").document(partyId)
            .updateData(["syncTimestampSec": timestampSec, "isPlaying": isPlaying])
        #endif
    }

    func addToQueue(partyId: String, videoId: String) async throws {
        guard AppConfig.Features.enableGroupWatchPartiesV2 else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("watch_parties_v2").document(partyId)
            .updateData(["queue": FieldValue.arrayUnion([videoId])])
        #endif
    }

    func sendReaction(partyId: String, uid: String, emoji: String, videoTimeSec: Double) async throws {
        guard AppConfig.Features.enableGroupWatchPartiesV2 else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("watch_party_reactions").document().setData([
            "partyId": partyId, "uid": uid, "emoji": emoji,
            "videoTimeSec": videoTimeSec, "timestamp": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func optimizeSync(partyId: String) async throws {
        guard AppConfig.Features.enableGroupWatchPartiesV2 else { return }
        struct Request: Encodable { let task: String; let partyId: String }
        struct Raw: Decodable { let optimal_buffer_ms: Int? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .liveStreamOptimizer, path: "/predict",
            body: Request(task: "optimize_party_sync", partyId: partyId)
        )
    }
}
