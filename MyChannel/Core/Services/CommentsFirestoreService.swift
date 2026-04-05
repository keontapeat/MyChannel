//
//  CommentsFirestoreService.swift
//  MyChannel
//
//  Firestore-backed comments for videos: CRUD + likes + listeners
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum CommentError: LocalizedError {
    case spamDetected
    case postFailed(String)

    var errorDescription: String? {
        switch self {
        case .spamDetected: return "Your comment was flagged as spam and could not be posted."
        case .postFailed(let msg): return "Failed to post comment: \(msg)"
        }
    }
}

@MainActor
final class CommentsFirestoreService: ObservableObject {
    static let shared = CommentsFirestoreService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    // Note: Using manual mapping below; no dependency on FirebaseFirestoreSwift

    func listen(videoId: String, onChange: @escaping ([RealTimeComment]) -> Void) -> Any? {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("videos").document(videoId).collection("comments")
        let listener = ref.order(by: "createdAt", descending: true).addSnapshotListener { snap, _ in
            guard let snap = snap else { return }
            let docs = snap.documents
            // Collect userIds to hydrate authors in batch
            var userIds: Set<String> = []
            let raw: [(String, [String: Any])] = docs.map { ($0.documentID, $0.data()) }
            raw.forEach { _, d in if let uid = d["userId"] as? String { userIds.insert(uid) } }
            fetchUsers(Array(userIds)) { usersMap in
                let mapped: [RealTimeComment] = raw.compactMap { (id, d) in
                    let uid = d["userId"] as? String ?? ""
                    let author = usersMap[uid] ?? .defaultUser
                    return RealTimeComment(
                        id: id,
                        author: author,
                        text: (d["text"] as? String) ?? "",
                        likeCount: (d["likeCount"] as? Int) ?? 0,
                        replyCount: (d["replyCount"] as? Int) ?? 0,
                        createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        parentId: d["parentId"] as? String,
                        isLive: false
                    )
                }
                onChange(mapped)
            }
        }
        return listener
        #else
        return nil
        #endif
    }

    func stop(listener: Any?) {
        #if canImport(FirebaseFirestore)
        (listener as? ListenerRegistration)?.remove()
        #endif
    }

    func post(videoId: String, userId: String, text: String, parentId: String? = nil) async throws {
        // 🤖 SPAM DETECTION: Check comment before posting
        struct SpamRequest: Encodable {
            let text: String
            let user_id: String
            let video_id: String
        }
        struct SpamResponse: Decodable {
            let is_spam: Bool?
            let confidence: Double?
            let reason: String?
        }
        if let spamResult = try? await CloudRunAgentRouter.post(
            CloudRunService.spamDetection,
            path: "/predict",
            body: SpamRequest(text: text, user_id: userId, video_id: videoId)
        ) as SpamResponse, spamResult.is_spam == true {
            let confidence = Int((spamResult.confidence ?? 1.0) * 100)
            print("🚫 [SpamDetection] Blocked comment (\(confidence)% confidence): \(spamResult.reason ?? "spam")")
            throw CommentError.spamDetected
        }

        #if canImport(FirebaseFirestore)
        let ref = db.collection("videos").document(videoId).collection("comments").document()
        try await ref.setData([
            "userId": userId,
            "text": text,
            "parentId": parentId as Any?,
            "likeCount": 0,
            "replyCount": 0,
            "createdAt": FieldValue.serverTimestamp()
        ].compactMapValues { $0 })
        #endif
    }

    func toggleLike(videoId: String, commentId: String, userId: String, add: Bool) async {
        #if canImport(FirebaseFirestore)
        let likesRef = db.collection("videos").document(videoId).collection("comments").document(commentId).collection("likes").document(userId)
        do {
            if add {
                try await likesRef.setData(["likedAt": FieldValue.serverTimestamp()])
            } else {
                try await likesRef.delete()
            }
        } catch {
            print("comment like error: \(error)")
        }
        #endif
    }
}

#if canImport(FirebaseFirestore)
private func fetchUsers(_ ids: [String], completion: @escaping ([String: User]) -> Void) {
    guard !ids.isEmpty else { completion([:]); return }
    let db = Firestore.firestore()
    db.collection("users").whereField(FieldPath.documentID(), in: Array(ids.prefix(10))).getDocuments { snap, _ in
        var map: [String: User] = [:]
        snap?.documents.forEach { doc in
            let d = doc.data()
            let user = User(
                id: doc.documentID,
                username: (d["username"] as? String) ?? "user",
                displayName: (d["displayName"] as? String) ?? "User",
                email: (d["email"] as? String) ?? "",
                profileImageURL: d["avatarUrl"] as? String,
                bannerImageURL: d["bannerImageUrl"] as? String,
                isVerified: (d["verified"] as? Bool) ?? false,
                isCreator: true
            )
            map[user.id] = user
        }
        completion(map)
    }
}
#endif


