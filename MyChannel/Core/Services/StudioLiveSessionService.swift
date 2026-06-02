//
//  StudioLiveSessionService.swift
//  MyChannel
//
//  Firestore-backed live-session lifecycle for the Creator Studio "Live" tab.
//  Persists a document in `live_streams/{id}` so a creator's go-live state,
//  title, stream key, and past broadcasts survive app restarts and are visible
//  to viewers. Matches the existing `live_streams` security rule (owner-only
//  write via the streamerId field).
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class StudioLiveSessionService: ObservableObject {
    static let shared = StudioLiveSessionService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    @Published var isLoading = false

    struct StudioLiveSession: Identifiable, Equatable {
        let id: String
        var title: String
        var description: String
        var streamerId: String
        var status: String        // "live" | "ended"
        var viewerCount: Int
        var startedAt: Date
        var endedAt: Date?
    }

    /// Create a live session doc and return its id. Persists to `live_streams`.
    func startSession(streamerId: String, title: String, description: String) async throws -> String {
        #if canImport(FirebaseFirestore)
        guard !streamerId.isEmpty else {
            throw NSError(domain: "Live", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in required to go live"])
        }
        isLoading = true; defer { isLoading = false }
        let ref = db.collection("live_streams").document()
        try await ref.setData([
            "title": title,
            "description": description,
            "streamerId": streamerId,
            "status": "live",
            "viewerCount": 0,
            "isLive": true,
            "startedAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return UUID().uuidString
        #endif
    }

    /// Mark a session ended.
    func endSession(streamId: String) async throws {
        #if canImport(FirebaseFirestore)
        guard !streamId.isEmpty else { return }
        try await db.collection("live_streams").document(streamId).updateData([
            "status": "ended",
            "isLive": false,
            "endedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    /// Past broadcasts for this creator, newest first.
    func fetchPastSessions(streamerId: String, limit: Int = 20) async throws -> [StudioLiveSession] {
        #if canImport(FirebaseFirestore)
        guard !streamerId.isEmpty else { return [] }
        isLoading = true; defer { isLoading = false }
        let snap = try await db.collection("live_streams")
            .whereField("streamerId", isEqualTo: streamerId)
            .order(by: "startedAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snap.documents.map { doc in
            let d = doc.data()
            return StudioLiveSession(
                id: doc.documentID,
                title: d["title"] as? String ?? "Untitled stream",
                description: d["description"] as? String ?? "",
                streamerId: d["streamerId"] as? String ?? streamerId,
                status: d["status"] as? String ?? "ended",
                viewerCount: d["viewerCount"] as? Int ?? 0,
                startedAt: (d["startedAt"] as? Timestamp)?.dateValue() ?? Date(),
                endedAt: (d["endedAt"] as? Timestamp)?.dateValue()
            )
        }
        #else
        return []
        #endif
    }
}
