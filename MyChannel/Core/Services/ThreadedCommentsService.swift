//
//  ThreadedCommentsService.swift
//  MyChannel
//
//  Phase 16: Threaded replies, reactions, pinned comments, creator hearts, @mentions.
//  Builds on top of CommentsFirestoreService with nested reply support.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct CommentReaction: Codable, Hashable {
    let emoji: String       // "❤️", "😂", "😮", "😢", "🔥"
    var count: Int
    var userReacted: Bool

    init(emoji: String, count: Int = 0, userReacted: Bool = false) {
        self.emoji = emoji; self.count = count; self.userReacted = userReacted
    }
}

struct ThreadedComment: Identifiable, Codable {
    let id: String
    let videoId: String
    let userId: String
    let userDisplayName: String
    let userAvatarURL: String?
    let text: String
    let parentId: String?     // nil = top-level
    let likeCount: Int
    let replyCount: Int
    let isPinned: Bool
    let isCreatorHearted: Bool
    let reactions: [CommentReaction]
    let mentions: [String]    // @usernames
    let createdAt: Date

    var isReply: Bool { parentId != nil }

    init(id: String = UUID().uuidString, videoId: String, userId: String,
         userDisplayName: String, userAvatarURL: String? = nil, text: String,
         parentId: String? = nil, likeCount: Int = 0, replyCount: Int = 0,
         isPinned: Bool = false, isCreatorHearted: Bool = false,
         reactions: [CommentReaction] = [], mentions: [String] = [],
         createdAt: Date = Date()) {
        self.id = id; self.videoId = videoId; self.userId = userId
        self.userDisplayName = userDisplayName; self.userAvatarURL = userAvatarURL
        self.text = text; self.parentId = parentId; self.likeCount = likeCount
        self.replyCount = replyCount; self.isPinned = isPinned
        self.isCreatorHearted = isCreatorHearted; self.reactions = reactions
        self.mentions = mentions; self.createdAt = createdAt
    }
}

// MARK: - Service

@MainActor
final class ThreadedCommentsService: ObservableObject {
    static let shared = ThreadedCommentsService()
    private init() {}

    @Published var topLevelComments: [ThreadedComment] = []
    @Published var replies: [String: [ThreadedComment]] = [:]  // parentId -> replies
    @Published var isLoading: Bool = false

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    static let defaultReactions = ["❤️", "😂", "😮", "😢", "🔥"]

    // MARK: - Fetch top-level comments

    func fetchComments(videoId: String, sortBy: CommentSort = .top, limit: Int = 30) async {
        isLoading = true
        defer { isLoading = false }

        #if canImport(FirebaseFirestore)
        do {
            let field = sortBy == .top ? "likeCount" : "createdAt"
            let snap = try await db.collection("videos").document(videoId).collection("comments")
                .whereField("parentId", isEqualTo: NSNull())
                .order(by: field, descending: true)
                .limit(to: limit)
                .getDocuments()

            topLevelComments = snap.documents.compactMap { parseComment($0) }
                .sorted { c1, c2 in
                    if c1.isPinned != c2.isPinned { return c1.isPinned }
                    return sortBy == .top ? c1.likeCount > c2.likeCount : c1.createdAt > c2.createdAt
                }
        } catch {
            print("⚠️ [ThreadedComments] fetch error: \(error)")
        }
        #endif
    }

    // MARK: - Fetch replies for a comment

    func fetchReplies(videoId: String, parentId: String, limit: Int = 20) async {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("videos").document(videoId).collection("comments")
                .whereField("parentId", isEqualTo: parentId)
                .order(by: "createdAt", descending: false)
                .limit(to: limit)
                .getDocuments()

            replies[parentId] = snap.documents.compactMap { parseComment($0) }
        } catch {
            print("⚠️ [ThreadedComments] replies error: \(error)")
        }
        #endif
    }

    // MARK: - Post comment (with spam check inherited from CommentsFirestoreService)

    func postComment(videoId: String, userId: String, displayName: String, avatarURL: String?,
                     text: String, parentId: String? = nil) async throws {
        // Spam check via existing service
        try await CommentsFirestoreService.shared.post(
            videoId: videoId, userId: userId, text: text, parentId: parentId
        )

        // Extract @mentions
        let mentions = extractMentions(from: text)

        // Also store extended fields
        #if canImport(FirebaseFirestore)
        // Get the last doc we just wrote
        let snap = try await db.collection("videos").document(videoId).collection("comments")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()

        if let doc = snap.documents.first {
            try await doc.reference.updateData([
                "userDisplayName": displayName,
                "userAvatarURL": avatarURL as Any,
                "parentId": parentId as Any,
                "isPinned": false,
                "isCreatorHearted": false,
                "reactions": [:] as [String: Any],
                "mentions": mentions
            ])
        }

        // Increment reply count on parent
        if let pid = parentId {
            try? await db.collection("videos").document(videoId).collection("comments")
                .document(pid).updateData(["replyCount": FieldValue.increment(Int64(1))])
        }
        #endif

        // Send @mention notifications
        for username in mentions {
            NotificationCenter.default.post(name: .init("mentionNotification"),
                                            object: nil, userInfo: ["username": username, "videoId": videoId])
        }
    }

    // MARK: - React to comment

    func toggleReaction(videoId: String, commentId: String, emoji: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("videos").document(videoId).collection("comments").document(commentId)
        let reactionRef = ref.collection("reactions").document("\(userId)_\(emoji)")

        do {
            let existing = try await reactionRef.getDocument()
            if existing.exists {
                try await reactionRef.delete()
                try await ref.updateData(["reactions.\(emoji)": FieldValue.increment(Int64(-1))])
            } else {
                try await reactionRef.setData(["userId": userId, "emoji": emoji, "createdAt": FieldValue.serverTimestamp()])
                try await ref.updateData(["reactions.\(emoji)": FieldValue.increment(Int64(1))])
            }
        } catch {
            print("⚠️ [ThreadedComments] reaction error: \(error)")
        }
        #endif
    }

    // MARK: - Pin comment

    func pinComment(videoId: String, commentId: String, pinned: Bool) async {
        #if canImport(FirebaseFirestore)
        try? await db.collection("videos").document(videoId).collection("comments")
            .document(commentId).updateData(["isPinned": pinned])
        #endif
    }

    // MARK: - Creator heart

    func heartComment(videoId: String, commentId: String, hearted: Bool) async {
        #if canImport(FirebaseFirestore)
        try? await db.collection("videos").document(videoId).collection("comments")
            .document(commentId).updateData(["isCreatorHearted": hearted])
        #endif
    }

    // MARK: - Helpers

    private func extractMentions(from text: String) -> [String] {
        let pattern = #"@(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            .map { nsText.substring(with: $0.range(at: 1)) }
    }

    #if canImport(FirebaseFirestore)
    private func parseComment(_ doc: QueryDocumentSnapshot) -> ThreadedComment? {
        let d = doc.data()
        guard let userId = d["userId"] as? String,
              let text = d["text"] as? String else { return nil }

        let rawReactions = d["reactions"] as? [String: Int] ?? [:]
        let reactions = rawReactions.map { CommentReaction(emoji: $0.key, count: $0.value) }

        return ThreadedComment(
            id: doc.documentID,
            videoId: "",
            userId: userId,
            userDisplayName: d["userDisplayName"] as? String ?? "User",
            userAvatarURL: d["userAvatarURL"] as? String,
            text: text,
            parentId: d["parentId"] as? String,
            likeCount: d["likeCount"] as? Int ?? 0,
            replyCount: d["replyCount"] as? Int ?? 0,
            isPinned: d["isPinned"] as? Bool ?? false,
            isCreatorHearted: d["isCreatorHearted"] as? Bool ?? false,
            reactions: reactions,
            mentions: d["mentions"] as? [String] ?? [],
            createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
    #endif

    enum CommentSort { case top, newest }
}
