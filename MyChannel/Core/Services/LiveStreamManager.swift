//
//  LiveStreamManager.swift
//  MyChannel
//
//  Manages live stream lifecycle via Firestore.
//  Writes/reads live_streams collection with real-time listeners.
//

import Foundation
import SwiftUI
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Firestore Live Stream Document
struct FirestoreLiveStream: Identifiable, Equatable {
    let id: String
    let creatorId: String
    let creatorName: String
    let creatorAvatar: String
    let creatorIsVerified: Bool
    let title: String
    let category: String
    let isPublic: Bool
    let enableChat: Bool
    let saveReplay: Bool
    var status: String // "live", "ended"
    var viewerCount: Int
    let startedAt: Date
    var endedAt: Date?

    static func == (lhs: FirestoreLiveStream, rhs: FirestoreLiveStream) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.viewerCount == rhs.viewerCount
    }
}

// MARK: - LiveStreamManager
@MainActor
final class LiveStreamManager: ObservableObject {
    static let shared = LiveStreamManager()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
    #endif

    @Published var activeStreams: [FirestoreLiveStream] = []
    @Published var myCurrentStream: FirestoreLiveStream? = nil

    // MARK: - Go Live
    func goLive(
        title: String,
        category: String,
        isPublic: Bool,
        enableChat: Bool,
        saveReplay: Bool
    ) async throws -> FirestoreLiveStream {
        guard let user = AppState.shared.currentUser ?? AuthenticationManager.shared.currentUser else {
            throw LiveStreamManagerError.notAuthenticated
        }

        let streamId = UUID().uuidString

        let stream = FirestoreLiveStream(
            id: streamId,
            creatorId: user.id,
            creatorName: user.displayName,
            creatorAvatar: user.profileImageURL ?? "",
            creatorIsVerified: user.isVerified,
            title: title.isEmpty ? "Untitled Live" : title,
            category: category,
            isPublic: isPublic,
            enableChat: enableChat,
            saveReplay: saveReplay,
            status: "live",
            viewerCount: 0,
            startedAt: Date(),
            endedAt: nil
        )

        #if canImport(FirebaseFirestore)
        let data: [String: Any] = [
            "creatorId": stream.creatorId,
            "creatorName": stream.creatorName,
            "creatorAvatar": stream.creatorAvatar,
            "creatorIsVerified": stream.creatorIsVerified,
            "title": stream.title,
            "category": stream.category,
            "isPublic": stream.isPublic,
            "enableChat": stream.enableChat,
            "saveReplay": stream.saveReplay,
            "status": "live",
            "viewerCount": 0,
            "startedAt": FieldValue.serverTimestamp(),
        ]
        try await db.collection("live_streams").document(streamId).setData(data)
        #endif

        myCurrentStream = stream
        print("🔴 [LiveStreamManager] Went live: \(stream.title) (\(streamId))")
        return stream
    }

    // MARK: - End Stream
    func endStream() async {
        guard let stream = myCurrentStream else { return }

        #if canImport(FirebaseFirestore)
        try? await db.collection("live_streams").document(stream.id).updateData([
            "status": "ended",
            "endedAt": FieldValue.serverTimestamp()
        ])
        #endif

        myCurrentStream = nil
        print("⬛ [LiveStreamManager] Ended stream: \(stream.id)")
    }

    // MARK: - Increment Viewer Count
    func joinAsViewer(streamId: String) async {
        #if canImport(FirebaseFirestore)
        try? await db.collection("live_streams").document(streamId).updateData([
            "viewerCount": FieldValue.increment(Int64(1))
        ])
        #endif
    }

    func leaveAsViewer(streamId: String) async {
        #if canImport(FirebaseFirestore)
        try? await db.collection("live_streams").document(streamId).updateData([
            "viewerCount": FieldValue.increment(Int64(-1))
        ])
        #endif
    }

    // MARK: - Real-time Listener for Active Streams
    func startListening() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = db.collection("live_streams")
            .whereField("status", isEqualTo: "live")
            .order(by: "startedAt", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self.activeStreams = docs.compactMap { Self.parse(doc: $0) }
                }
            }
        print("📡 [LiveStreamManager] Listening for active live streams")
        #else
        // No Firebase – use sample data for previews
        activeStreams = Self.sampleStreams
        #endif
    }

    func stopListening() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        #endif
    }

    // MARK: - Fetch Single Stream
    func fetchStream(id: String) async -> FirestoreLiveStream? {
        #if canImport(FirebaseFirestore)
        guard let doc = try? await db.collection("live_streams").document(id).getDocument(),
              doc.exists else { return nil }
        return Self.parse(doc: doc)
        #else
        return Self.sampleStreams.first
        #endif
    }

    // MARK: - Send Chat Message
    func sendChatMessage(streamId: String, content: String) async {
        guard let user = AppState.shared.currentUser ?? AuthenticationManager.shared.currentUser else { return }
        let msgId = UUID().uuidString

        #if canImport(FirebaseFirestore)
        let data: [String: Any] = [
            "userId": user.id,
            "username": user.displayName,
            "avatarUrl": user.profileImageURL ?? "",
            "content": content,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try? await db.collection("live_streams").document(streamId).collection("chat").document(msgId).setData(data)
        #endif
    }

    // MARK: - Parse Firestore Doc
    #if canImport(FirebaseFirestore)
    private static func parse(doc: DocumentSnapshot) -> FirestoreLiveStream? {
        guard let d = doc.data() else { return nil }
        return FirestoreLiveStream(
            id: doc.documentID,
            creatorId: d["creatorId"] as? String ?? "",
            creatorName: d["creatorName"] as? String ?? "Creator",
            creatorAvatar: d["creatorAvatar"] as? String ?? "",
            creatorIsVerified: d["creatorIsVerified"] as? Bool ?? false,
            title: d["title"] as? String ?? "Live Stream",
            category: d["category"] as? String ?? "General",
            isPublic: d["isPublic"] as? Bool ?? true,
            enableChat: d["enableChat"] as? Bool ?? true,
            saveReplay: d["saveReplay"] as? Bool ?? true,
            status: d["status"] as? String ?? "live",
            viewerCount: d["viewerCount"] as? Int ?? 0,
            startedAt: (d["startedAt"] as? Timestamp)?.dateValue() ?? Date(),
            endedAt: (d["endedAt"] as? Timestamp)?.dateValue()
        )
    }
    #endif

    // MARK: - Sample Data (previews / no Firebase)
    static let sampleStreams: [FirestoreLiveStream] = [
        FirestoreLiveStream(
            id: "sample_1", creatorId: "u1", creatorName: "Shot By Keonta",
            creatorAvatar: "", creatorIsVerified: true,
            title: "Live Coding Session – SwiftUI App",
            category: "Education", isPublic: true, enableChat: true, saveReplay: true,
            status: "live", viewerCount: 1245, startedAt: Date().addingTimeInterval(-7200)
        ),
        FirestoreLiveStream(
            id: "sample_2", creatorId: "u2", creatorName: "Baby Ju",
            creatorAvatar: "", creatorIsVerified: true,
            title: "Studio Session – New Track Preview",
            category: "Music", isPublic: true, enableChat: true, saveReplay: true,
            status: "live", viewerCount: 856, startedAt: Date().addingTimeInterval(-2700)
        ),
        FirestoreLiveStream(
            id: "sample_3", creatorId: "u3", creatorName: "Scatz",
            creatorAvatar: "", creatorIsVerified: true,
            title: "Gaming Tournament Finals",
            category: "Gaming", isPublic: true, enableChat: true, saveReplay: true,
            status: "live", viewerCount: 3421, startedAt: Date().addingTimeInterval(-3600)
        ),
    ]
}

// MARK: - Errors
enum LiveStreamManagerError: LocalizedError {
    case notAuthenticated
    case streamNotFound
    case alreadyLive

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in to go live."
        case .streamNotFound: return "Live stream not found."
        case .alreadyLive: return "You already have an active live stream."
        }
    }
}
