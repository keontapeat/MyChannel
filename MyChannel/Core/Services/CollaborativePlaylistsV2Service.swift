//
//  CollaborativePlaylistsV2Service.swift
//  MyChannel
//
//  Phase 122: Collaborative Playlists v2.
//  Multi-editor playlists, voting/ranking, auto-suggestions from session graph.
//  Uses `recommendations` Cloud Run for smart suggestions.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct CollabPlaylist: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let ownerUid: String
    let editorUids: [String]
    let videoIds: [String]
    let visibility: String
    let votingEnabled: Bool
    let coverURL: URL?
    let createdAt: Date
}

struct PlaylistVote: Codable, Identifiable {
    let id: String
    let playlistId: String
    let videoId: String
    let voterUid: String
    let direction: VoteDirection
    let createdAt: Date
}

enum VoteDirection: String, Codable { case up, down }

struct PlaylistCollaborationSuggestion: Codable, Identifiable {
    let id: String
    let videoId: String
    let title: String
    let score: Double
    let reason: String
}

// MARK: - Service

@MainActor
final class CollaborativePlaylistsV2Service: ObservableObject {
    static let shared = CollaborativePlaylistsV2Service()
    private init() {}

    @Published private(set) var playlists: [CollabPlaylist] = []
    @Published private(set) var suggestions: [PlaylistCollaborationSuggestion] = []

    func loadPlaylists(uid: String) async throws {
        guard AppConfig.Features.enableCollaborativePlaylistsV2 else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("collab_playlists")
            .whereField("editorUids", arrayContains: uid)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        playlists = snap.documents.compactMap { doc in
            let d = doc.data()
            return CollabPlaylist(
                id: doc.documentID, title: d["title"] as? String ?? "",
                description: d["description"] as? String ?? "",
                ownerUid: d["ownerUid"] as? String ?? "",
                editorUids: d["editorUids"] as? [String] ?? [],
                videoIds: d["videoIds"] as? [String] ?? [],
                visibility: d["visibility"] as? String ?? "public",
                votingEnabled: d["votingEnabled"] as? Bool ?? false,
                coverURL: (d["coverURL"] as? String).flatMap(URL.init(string:)),
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func createPlaylist(title: String, ownerUid: String, votingEnabled: Bool) async throws -> String {
        guard AppConfig.Features.enableCollaborativePlaylistsV2 else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("collab_playlists").document()
        try await ref.setData([
            "title": title, "ownerUid": ownerUid, "editorUids": [ownerUid],
            "videoIds": [], "visibility": "public", "votingEnabled": votingEnabled,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func addEditor(playlistId: String, uid: String) async throws {
        guard AppConfig.Features.enableCollaborativePlaylistsV2 else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("collab_playlists").document(playlistId)
            .updateData(["editorUids": FieldValue.arrayUnion([uid])])
        #endif
    }

    func vote(playlistId: String, videoId: String, voterUid: String, direction: VoteDirection) async throws {
        guard AppConfig.Features.enableCollaborativePlaylistsV2 else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("playlist_votes").document().setData([
            "playlistId": playlistId, "videoId": videoId, "voterUid": voterUid,
            "direction": direction.rawValue, "createdAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func fetchSuggestions(playlistId: String) async throws {
        guard AppConfig.Features.enableCollaborativePlaylistsV2 else { return }
        struct Request: Encodable { let task: String; let playlistId: String }
        struct RawSug: Decodable { let video_id: String; let title: String; let score: Double; let reason: String }
        struct Raw: Decodable { let suggestions: [RawSug]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .recommendations, path: "/predict",
            body: Request(task: "playlist_suggestions", playlistId: playlistId)
        )
        suggestions = (r.suggestions ?? []).map {
            PlaylistCollaborationSuggestion(id: $0.video_id, videoId: $0.video_id, title: $0.title, score: $0.score, reason: $0.reason)
        }
    }
}
