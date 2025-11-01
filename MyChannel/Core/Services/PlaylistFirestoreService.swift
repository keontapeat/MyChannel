//
//  PlaylistFirestoreService.swift
//  MyChannel
//
//  Firestore-backed playlists service for Google Cloud/Firebase.
//

import Foundation
import Combine
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class PlaylistFirestoreService: ObservableObject {
    static let shared = PlaylistFirestoreService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    @Published var isLoading: Bool = false

    // MARK: - CRUD
    func getPlaylists(for userId: String) async throws -> [Playlist] {
        #if canImport(FirebaseFirestore)
        isLoading = true; defer { isLoading = false }
        let snap = try await db.collection("playlists")
            .whereField("userId", isEqualTo: userId)
            .order(by: "updatedAt", descending: true)
            .getDocuments()
        let docs = snap.documents.compactMap { doc -> Playlist? in
            let d = doc.data()
            let title = d["title"] as? String ?? ""
            let description = d["description"] as? String ?? ""
            let thumbnailUrl = d["thumbnailUrl"] as? String
            let owner = d["userId"] as? String ?? ""
            let visibility = d["visibility"] as? String ?? "public"
            let tags = d["tags"] as? [String] ?? []
            let categoryRaw = d["category"] as? String ?? "general"
            let createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let updatedAt = (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
            return Playlist(
                id: doc.documentID,
                title: title,
                description: description,
                thumbnailURL: thumbnailUrl,
                creatorId: owner,
                videoIds: [], // membership stored in subcollection
                isPublic: visibility == "public",
                createdAt: createdAt,
                updatedAt: updatedAt,
                tags: tags,
                category: PlaylistCategory(rawValue: categoryRaw) ?? .general
            )
        }
        return docs
        #else
        return []
        #endif
    }

    func addVideoToPlaylist(videoId: String, playlistId: String) async throws {
        #if canImport(FirebaseFirestore)
        isLoading = true; defer { isLoading = false }
        let ref = db.collection("playlists").document(playlistId)
        // store membership in subcollection for scalability
        try await ref.collection("videos").document(videoId).setData([
            "position": Int(Date().timeIntervalSince1970),
            "addedAt": FieldValue.serverTimestamp()
        ])
        try await ref.updateData(["updatedAt": FieldValue.serverTimestamp()])
        #endif
    }

    func createPlaylist(userId: String, title: String, description: String? = nil, category: PlaylistCategory = .general, visibility: String = "public") async throws -> String {
        #if canImport(FirebaseFirestore)
        isLoading = true; defer { isLoading = false }
        let doc = try await db.collection("playlists").addDocument(data: [
            "userId": userId,
            "title": title,
            "description": description ?? "",
            "thumbnailUrl": NSNull(),
            "visibility": visibility,
            "tags": [],
            "category": category.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        return doc.documentID
        #else
        return ""
        #endif
    }

    // MARK: - Thumbnail Upload URL helper (client uploads to Storage directly; this updates doc)
    func setThumbnailURL(playlistId: String, url: String) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("playlists").document(playlistId).updateData([
            "thumbnailUrl": url,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func deletePlaylist(id: String) async throws {
        #if canImport(FirebaseFirestore)
        isLoading = true; defer { isLoading = false }
        let ref = db.collection("playlists").document(id)
        // Best-effort delete subcollection docs
        let vids = try? await ref.collection("videos").getDocuments()
        vids?.documents.forEach { doc in
            Task { try? await ref.collection("videos").document(doc.documentID).delete() }
        }
        try await ref.delete()
        #endif
    }

    func getPlaylistVideoIds(playlistId: String) async throws -> [String] {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("playlists").document(playlistId).collection("videos")
        let snap = try await ref.order(by: "position", descending: false).getDocuments()
        return snap.documents.map { $0.documentID }
        #else
        return []
        #endif
    }

    func updatePlaylist(id: String, title: String, description: String, category: PlaylistCategory, visibility: String, tags: [String]) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("playlists").document(id).updateData([
            "title": title,
            "description": description,
            "category": category.rawValue,
            "visibility": visibility,
            "tags": tags,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func removeVideo(playlistId: String, videoId: String) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("playlists").document(playlistId).collection("videos").document(videoId).delete()
        try await db.collection("playlists").document(playlistId).updateData(["updatedAt": FieldValue.serverTimestamp()])
        #endif
    }
}


