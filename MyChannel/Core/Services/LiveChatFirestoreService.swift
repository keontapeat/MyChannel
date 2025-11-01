//
//  LiveChatFirestoreService.swift
//  MyChannel
//
//  Mirrors live chat to Firestore for replay/moderation history.
//

import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class LiveChatFirestoreService {
    static let shared = LiveChatFirestoreService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    struct ChatDoc: Codable {
        let id: String
        let userId: String
        let username: String
        let avatarUrl: String?
        let content: String
        let type: String
        let highlighted: Bool
        let pinned: Bool
        let moderated: Bool
        let superChatAmount: Double?
        let replyTo: String?
        let createdAt: Date
    }

    func mirrorMessage(streamId: String, message: ChatMessage) async {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("live").document(streamId).collection("messages").document(message.id)
        let doc = ChatDoc(
            id: message.id,
            userId: message.userId,
            username: message.username,
            avatarUrl: message.userAvatarURL,
            content: message.content,
            type: message.messageType.rawValue,
            highlighted: message.isHighlighted,
            pinned: message.isPinned,
            moderated: message.isModerated,
            superChatAmount: message.superChatAmount,
            replyTo: message.replyToMessageId,
            createdAt: message.timestamp
        )
        do {
            try await ref.setData(from: doc, merge: true)
        } catch {
            // Best-effort; omit errors to avoid user disruption
        }
        #endif
    }

    func fetchRecent(streamId: String, limit: Int = 50) async -> [ChatMessage] {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("live").document(streamId).collection("messages")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            let items: [ChatMessage] = snap.documents.compactMap { doc in
                let d = doc.data()
                return ChatMessage(
                    id: doc.documentID,
                    streamId: streamId,
                    userId: (d["userId"] as? String) ?? "",
                    username: (d["username"] as? String) ?? "User",
                    userAvatarURL: d["avatarUrl"] as? String,
                    content: (d["content"] as? String) ?? "",
                    messageType: MessageType(rawValue: (d["type"] as? String) ?? "regular") ?? .regular,
                    timestamp: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    isHighlighted: (d["highlighted"] as? Bool) ?? false,
                    isPinned: (d["pinned"] as? Bool) ?? false,
                    isModerated: (d["moderated"] as? Bool) ?? false,
                    badges: [],
                    emotes: [],
                    superChatAmount: d["superChatAmount"] as? Double,
                    replyToMessageId: d["replyTo"] as? String
                )
            }.reversed()
            return Array(items)
        } catch {
            return []
        }
        #else
        return []
        #endif
    }
}




