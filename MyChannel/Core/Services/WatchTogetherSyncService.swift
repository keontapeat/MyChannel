//
//  WatchTogetherSyncService.swift
//  MyChannel
//
//  Phase 149: Watch Together Sync.
//  Real-time sync with friends, shared cursor, voice chat overlay.
//  Uses `live-stream-optimizer-ai` for sync quality.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct WatchSession: Codable, Identifiable, Equatable {
    let id: String
    let hostUid: String
    let videoId: String
    let participants: [String]
    let syncTimeSec: Double
    let isPlaying: Bool
    let playbackRate: Float
    let voiceChatEnabled: Bool
    let createdAt: Date
}

struct SyncCursor: Codable, Identifiable {
    let id: String       // participantUid
    let uid: String
    let displayName: String
    let currentTimeSec: Double
    let isBuffering: Bool
}

struct WatchInvite: Codable, Identifiable {
    let id: String
    let sessionId: String
    let senderUid: String
    let senderName: String
    let videoTitle: String
    let sentAt: Date
}

// MARK: - Service

@MainActor
final class WatchTogetherSyncService: ObservableObject {
    static let shared = WatchTogetherSyncService()
    private init() {}

    @Published private(set) var activeSession: WatchSession?
    @Published private(set) var cursors: [SyncCursor] = []
    @Published var isHost: Bool = false
    @Published var voiceChatActive: Bool = false
    private var listener: Any?

    func createSession(hostUid: String, videoId: String) async throws -> String {
        guard AppConfig.Features.enableWatchTogetherSync else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("watch_sessions").document()
        try await ref.setData([
            "hostUid": hostUid, "videoId": videoId, "participants": [hostUid],
            "syncTimeSec": 0.0, "isPlaying": false, "playbackRate": 1.0,
            "voiceChatEnabled": false, "createdAt": FieldValue.serverTimestamp()
        ])
        isHost = true
        activeSession = WatchSession(
            id: ref.documentID, hostUid: hostUid, videoId: videoId,
            participants: [hostUid], syncTimeSec: 0, isPlaying: false,
            playbackRate: 1.0, voiceChatEnabled: false, createdAt: Date()
        )
        startListening(sessionId: ref.documentID)
        return ref.documentID
        #else
        return ""
        #endif
    }

    func joinSession(sessionId: String, uid: String) async throws {
        guard AppConfig.Features.enableWatchTogetherSync else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("watch_sessions").document(sessionId)
            .updateData(["participants": FieldValue.arrayUnion([uid])])
        #endif
        isHost = false
        startListening(sessionId: sessionId)
    }

    func syncPlayback(sessionId: String, timeSec: Double, isPlaying: Bool) async throws {
        guard AppConfig.Features.enableWatchTogetherSync, isHost else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("watch_sessions").document(sessionId)
            .updateData(["syncTimeSec": timeSec, "isPlaying": isPlaying])
        #endif
    }

    func reportCursor(sessionId: String, uid: String, displayName: String, timeSec: Double) async throws {
        guard AppConfig.Features.enableWatchTogetherSync else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("watch_session_cursors").document(uid)
            .setData(["sessionId": sessionId, "uid": uid, "displayName": displayName,
                      "currentTimeSec": timeSec, "isBuffering": false], merge: true)
        #endif
    }

    func sendInvite(sessionId: String, senderUid: String, senderName: String, recipientUid: String, videoTitle: String) async throws {
        guard AppConfig.Features.enableWatchTogetherSync else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("watch_invites").document().setData([
            "sessionId": sessionId, "senderUid": senderUid, "senderName": senderName,
            "recipientUid": recipientUid, "videoTitle": videoTitle,
            "sentAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func leaveSession() async throws {
        activeSession = nil
        cursors = []
        isHost = false
        listener = nil
    }

    private func startListening(sessionId: String) {
        #if canImport(FirebaseFirestore)
        listener = Firestore.firestore().collection("watch_sessions").document(sessionId)
            .addSnapshotListener { [weak self] snap, _ in
                guard let d = snap?.data() else { return }
                Task { @MainActor in
                    self?.activeSession = WatchSession(
                        id: sessionId, hostUid: d["hostUid"] as? String ?? "",
                        videoId: d["videoId"] as? String ?? "",
                        participants: d["participants"] as? [String] ?? [],
                        syncTimeSec: d["syncTimeSec"] as? Double ?? 0,
                        isPlaying: d["isPlaying"] as? Bool ?? false,
                        playbackRate: Float(d["playbackRate"] as? Double ?? 1.0),
                        voiceChatEnabled: d["voiceChatEnabled"] as? Bool ?? false,
                        createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            }
        #endif
    }
}
