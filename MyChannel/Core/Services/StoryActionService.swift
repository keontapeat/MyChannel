import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class StoryActionService: ObservableObject {
    static let shared = StoryActionService()

    @Published private(set) var likedStoryIds: Set<String> = []

    private init() {}

    func loadLikeState(userId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("liked_stories")
                .getDocuments()
            likedStoryIds = Set(snapshot.documents.map { $0.documentID })
        } catch {
            print("🚨 [StoryActionService] Failed to load liked stories: \(error.localizedDescription)")
        }
        #endif
    }

    func isLiked(storyId: String) -> Bool {
        likedStoryIds.contains(storyId)
    }

    func toggleLike(storyId: String, creatorId: String, userId: String) async -> Bool {
        let willLike = !likedStoryIds.contains(storyId)
        if willLike {
            likedStoryIds.insert(storyId)
        } else {
            likedStoryIds.remove(storyId)
        }

        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let userLikeRef = db.collection("users").document(userId).collection("liked_stories").document(storyId)
        let storyLikeRef = db.collection("stories").document(storyId).collection("likes").document(userId)
        let storyRef = db.collection("stories").document(storyId)

        do {
            if willLike {
                let data: [String: Any] = [
                    "storyId": storyId,
                    "creatorId": creatorId,
                    "userId": userId,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                try await userLikeRef.setData(data, merge: true)
                try await storyLikeRef.setData(data, merge: true)
                try await storyRef.setData(["likeCount": FieldValue.increment(Int64(1))], merge: true)
                await StoriesIntegrationService.shared.trackStoryEngagement(storyId: storyId, action: "like", userId: userId)
            } else {
                try await userLikeRef.delete()
                try await storyLikeRef.delete()
                try await storyRef.setData(["likeCount": FieldValue.increment(Int64(-1))], merge: true)
                await StoriesIntegrationService.shared.trackStoryEngagement(storyId: storyId, action: "unlike", userId: userId)
            }
        } catch {
            if willLike {
                likedStoryIds.remove(storyId)
            } else {
                likedStoryIds.insert(storyId)
            }
            print("🚨 [StoryActionService] Failed to toggle story like: \(error.localizedDescription)")
        }
        #endif

        return likedStoryIds.contains(storyId)
    }

    func sendReply(storyId: String, creatorId: String, userId: String, text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let replyData: [String: Any] = [
            "storyId": storyId,
            "creatorId": creatorId,
            "senderId": userId,
            "text": trimmed,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "sent"
        ]
        try await db.collection("story_replies").addDocument(data: replyData)
        try await db.collection("stories").document(storyId).setData([
            "replyCount": FieldValue.increment(Int64(1)),
            "commentCount": FieldValue.increment(Int64(1))
        ], merge: true)
        await StoriesIntegrationService.shared.trackStoryEngagement(storyId: storyId, action: "comment", userId: userId)
        #endif
    }

    func trackShare(storyId: String, creatorId: String, userId: String, completed: Bool) async {
        guard completed else { return }

        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "storyId": storyId,
            "creatorId": creatorId,
            "userId": userId,
            "createdAt": FieldValue.serverTimestamp()
        ]
        do {
            try await db.collection("story_shares").addDocument(data: data)
            try await db.collection("stories").document(storyId).setData([
                "shareCount": FieldValue.increment(Int64(1))
            ], merge: true)
            await StoriesIntegrationService.shared.trackStoryEngagement(storyId: storyId, action: "share", userId: userId)
        } catch {
            print("🚨 [StoryActionService] Failed to track story share: \(error.localizedDescription)")
        }
        #endif
    }
}
