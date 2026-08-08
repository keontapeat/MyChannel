//
//  StorySeenTracker.swift
//  MyChannel
//
//  Tracks which stories a user has seen, expiry management,
//  and seen/unseen counts. Uses Firestore for persistence.
//

import Foundation
import FirebaseFirestore

struct StorySeenRecord: Codable, Identifiable {
    let id: String
    let userId: String
    let storyId: String
    let creatorId: String
    let seenAt: Date
}

@MainActor
final class StorySeenTracker: ObservableObject {
    static let shared = StorySeenTracker()
    private init() {}
    @Published private(set) var seenStoryIds: Set<String> = []
    private let db = Firestore.firestore()

    func markSeen(userId: String, storyId: String, creatorId: String) {
        seenStoryIds.insert(storyId)
        let data: [String: Any] = [
            "userId": userId,
            "storyId": storyId,
            "creatorId": creatorId,
            "seenAt": FieldValue.serverTimestamp()
        ]
        Task {
            do {
                try await db.collection("story_seen").document("\(userId)_\(storyId)").setData(data)
            } catch {
                #if DEBUG
                print("⚠️ [StorySeenTracker] markSeen skipped: \(error.localizedDescription)")
                #endif
            }
        }
    }

    func fetchSeen(userId: String) async throws {
        let snapshot = try await db.collection("story_seen").whereField("userId", isEqualTo: userId).getDocuments()
        seenStoryIds = Set(snapshot.documents.compactMap { $0.data()["storyId"] as? String })
    }

    func isSeen(storyId: String) -> Bool { seenStoryIds.contains(storyId) }

    func unseenCount(from stories: [String]) -> Int { stories.filter { !seenStoryIds.contains($0) }.count }

    func clearExpired(userId: String, olderThan hours: Int = 24) async throws {
        guard !userId.isEmpty else { return }
        let cutoff = Date().addingTimeInterval(-Double(hours * 3600))
        // Scope the query to the caller's own docs. Firestore Security Rules
        // reject a `story_seen` query that isn't constrained to the signed-in
        // user's `userId`, so we filter on userId server-side and evaluate the
        // `seenAt` expiry client-side (avoids a userId+seenAt composite index).
        let snapshot = try await db.collection("story_seen")
            .whereField("userId", isEqualTo: userId)
            .limit(to: 500)
            .getDocuments()
        for doc in snapshot.documents {
            let seenAt = (doc.data()["seenAt"] as? Timestamp)?.dateValue()
            guard let seenAt, seenAt < cutoff else { continue }
            if let storyId = doc.data()["storyId"] as? String { seenStoryIds.remove(storyId) }
            try await doc.reference.delete()
        }
    }
}
