//
//  NotificationsInboxService.swift
//  MyChannel
//
//  Notifications inbox: real-time notification delivery,
//  read/unread management, grouping, preferences.
//  Uses Firestore + `mychannel-events` Cloud Run.
//

import Foundation
import FirebaseFirestore

struct NotificationItem: Codable, Identifiable {
    let id: String
    let userId: String
    let type: NotificationType
    let title: String
    let body: String
    let imageURL: String?
    let deepLink: String?
    let isRead: Bool
    let createdAt: Date
    let groupedCount: Int
    enum NotificationType: String, Codable { case newVideo, liveStart, comment, like, subscriber, mention, system, milestone }
}

@MainActor
final class NotificationsInboxService: ObservableObject {
    static let shared = NotificationsInboxService()
    private init() {}
    @Published private(set) var notifications: [NotificationItem] = []
    @Published private(set) var unreadCount: Int = 0
    private let db = Firestore.firestore()

    func fetchNotifications(userId: String, limit: Int = 30) async throws {
        let snapshot = try await db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        notifications = snapshot.documents.compactMap { doc in
            let d = doc.data()
            return NotificationItem(id: doc.documentID, userId: userId,
                type: .init(rawValue: d["type"] as? String ?? "system") ?? .system,
                title: d["title"] as? String ?? "", body: d["body"] as? String ?? "",
                imageURL: d["imageURL"] as? String, deepLink: d["deepLink"] as? String,
                isRead: d["isRead"] as? Bool ?? false, createdAt: Date(), groupedCount: d["groupedCount"] as? Int ?? 1)
        }
        unreadCount = notifications.filter { !$0.isRead }.count
    }

    func markRead(notificationId: String) async throws {
        try await db.collection("notifications").document(notificationId).updateData(["isRead": true])
        if let idx = notifications.firstIndex(where: { $0.id == notificationId }) {
            let old = notifications[idx]
            notifications[idx] = NotificationItem(id: old.id, userId: old.userId, type: old.type, title: old.title,
                body: old.body, imageURL: old.imageURL, deepLink: old.deepLink, isRead: true, createdAt: old.createdAt, groupedCount: old.groupedCount)
        }
        unreadCount = max(0, unreadCount - 1)
    }

    func markAllRead(userId: String) async throws {
        let batch = db.batch()
        for n in notifications where !n.isRead {
            batch.updateData(["isRead": true], forDocument: db.collection("notifications").document(n.id))
        }
        try await batch.commit()
        notifications = notifications.map { NotificationItem(id: $0.id, userId: $0.userId, type: $0.type, title: $0.title,
            body: $0.body, imageURL: $0.imageURL, deepLink: $0.deepLink, isRead: true, createdAt: $0.createdAt, groupedCount: $0.groupedCount) }
        unreadCount = 0
    }
}
