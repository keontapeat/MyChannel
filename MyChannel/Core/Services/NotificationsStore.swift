//
//  NotificationsStore.swift
//  MyChannel
//
//  Single source of truth for all in-app notifications.
//  Bridges Firestore inbox, ML agent events, and the bell badge.
//

import SwiftUI
import Combine

// MARK: - Notification Priority

enum NotificationPriority: Int, Comparable, Codable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    static func < (lhs: NotificationPriority, rhs: NotificationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - NotificationSource

enum NotificationSource: String, Codable {
    case user            // like, comment, follow, upload, live — always shown
    case viralAgent      // creator's own content trending — shown to creator only
    case recommendAgent  // new videos from followed creators — shown to viewer
    case liveAgent       // a followed creator went live — shown to follower
    // NOTE: churnAgent, fraudAgent, safetyAgent, analyticsAgent, growthAgent,
    // revenueAgent, systemAgent are INTERNAL ONLY and must never be pushed
    // to regular users via NotificationsStore.
}

// MARK: - StoreNotificationItem

struct StoreNotificationItem: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var message: String
    var timestamp: Date
    var isRead: Bool = false
    var type: NotificationItem.NotificationType
    var source: NotificationSource = .user
    var priority: NotificationPriority = .normal
    var avatarURL: String? = nil
    var thumbnailURL: String? = nil
    var deepLinkPath: String? = nil
    /// How many events have been collapsed into this row (1 = ungrouped)
    var groupCount: Int = 1
    /// True once groupCount > 1
    var isGrouped: Bool { groupCount > 1 }

    static func == (lhs: StoreNotificationItem, rhs: StoreNotificationItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - NotificationsStore

@MainActor
final class NotificationsStore: ObservableObject {
    static let shared = NotificationsStore()

    // MARK: Published

    @Published private(set) var items: [StoreNotificationItem] = []
    @Published private(set) var unreadCount: Int = 0

    // MARK: Private

    private let maxItems = 200
    private var seenIds = Set<String>()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadSampleData()
        bridgeFirestoreInbox()
    }

    // MARK: - Public API

    /// Push a notification. Admin/internal sources are silently dropped here
    /// so no code path can accidentally show internal events to users.
    func push(_ item: StoreNotificationItem) {
        // Hard gate: only user-facing sources allowed
        guard isUserFacing(item.source) else { return }
        // Dedup by id
        guard !seenIds.contains(item.id) else { return }
        seenIds.insert(item.id)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            // High/critical go to top; normal appended
            if item.priority >= .high {
                items.insert(item, at: 0)
            } else {
                items.append(item)
            }
            // Cap list
            if items.count > maxItems {
                items = Array(items.prefix(maxItems))
            }
            recalcUnread()
        }

        // Show in-app toast for high-priority social events only
        if item.priority >= .high {
            NotificationManager.shared.showInAppNotification(InAppNotification(
                type: .info,
                title: item.title,
                message: item.message,
                duration: 3.0,
                actionTitle: item.deepLinkPath != nil ? "View" : nil,
                onAction: nil
            ))
        }
    }

    /// Push a raw social event from Firestore and apply smart grouping.
    /// If the same type from the same sender already exists unread within
    /// 5 minutes, collapse it into a grouped item instead of a new row.
    func pushSocialEvent(
        id: String,
        type: NotificationItem.NotificationType,
        senderName: String,
        targetTitle: String,
        timestamp: Date,
        avatarURL: String? = nil,
        thumbnailURL: String? = nil,
        deepLinkPath: String? = nil
    ) {
        // Check for recent same-type ungrouped item to collapse into
        let window: TimeInterval = 300  // 5 min grouping window
        if let idx = items.firstIndex(where: {
            !$0.isRead &&
            $0.type == type &&
            !$0.isGrouped &&
            timestamp.timeIntervalSince($0.timestamp) < window
        }) {
            // Collapse into grouped item
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                items[idx].groupCount += 1
                items[idx].title = groupedTitle(type: type, count: items[idx].groupCount, targetTitle: targetTitle)
                items[idx].timestamp = timestamp
                items[idx].isRead = false
            }
            recalcUnread()
            return
        }

        let item = StoreNotificationItem(
            id: id,
            title: singleTitle(type: type, senderName: senderName, targetTitle: targetTitle),
            message: singleMessage(type: type, senderName: senderName, targetTitle: targetTitle),
            timestamp: timestamp,
            isRead: false,
            type: type,
            source: .user,
            priority: type == .live ? .high : .normal,
            avatarURL: avatarURL,
            thumbnailURL: thumbnailURL,
            deepLinkPath: deepLinkPath
        )
        push(item)
    }

    func markRead(_ id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isRead = true
        recalcUnread()
    }

    func markAllRead() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            for idx in items.indices { items[idx].isRead = true }
            unreadCount = 0
        }
    }

    func delete(_ id: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            items.removeAll { $0.id == id }
            seenIds.remove(id)
            recalcUnread()
        }
    }

    // MARK: - Firestore Bridge
    // Converts raw Firestore inbox documents into user-facing social events.
    // Only processes known social types — silently drops anything else.

    private func bridgeFirestoreInbox() {
        NotificationsInboxService.shared.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] inboxItems in
                guard let self else { return }
                for inbox in inboxItems {
                    let type = notifType(from: inbox.type)
                    // Only bridge known social event types
                    guard socialTypes.contains(type) else { continue }
                    let item = StoreNotificationItem(
                        id: inbox.id,
                        title: inbox.title,
                        message: inbox.body,
                        timestamp: inbox.createdAt,
                        isRead: inbox.read,
                        type: type,
                        source: .user,
                        priority: type == .live ? .high : .normal
                    )
                    self.push(item)
                }
            }
            .store(in: &cancellables)
    }

    private let socialTypes: Set<NotificationItem.NotificationType> = [.like, .comment, .follow, .upload, .live]

    // MARK: - Helpers

    private func isUserFacing(_ source: NotificationSource) -> Bool {
        switch source {
        case .user, .viralAgent, .recommendAgent, .liveAgent: return true
        }
    }

    private func recalcUnread() {
        unreadCount = items.filter { !$0.isRead }.count
    }

    private func groupedTitle(type: NotificationItem.NotificationType, count: Int, targetTitle: String) -> String {
        switch type {
        case .like:    return "\(count) people liked \"\(targetTitle)\""
        case .comment: return "\(count) new comments on \"\(targetTitle)\""
        case .follow:  return "\(count) new followers"
        default:       return "\(count) new notifications"
        }
    }

    private func singleTitle(type: NotificationItem.NotificationType, senderName: String, targetTitle: String) -> String {
        switch type {
        case .like:    return "\(senderName) liked your video"
        case .comment: return "\(senderName) commented on your video"
        case .follow:  return "\(senderName) started following you"
        case .upload:  return "\(senderName) posted a new video"
        case .live:    return "\(senderName) is live now"
        case .system:  return senderName
        }
    }

    private func singleMessage(type: NotificationItem.NotificationType, senderName: String, targetTitle: String) -> String {
        switch type {
        case .like:    return targetTitle
        case .comment: return targetTitle
        case .follow:  return "Tap to view their channel"
        case .upload:  return targetTitle
        case .live:    return "\(senderName) just started streaming"
        case .system:  return targetTitle
        }
    }

    // MARK: - Sample / Initial Data (social events only, no admin/system content)

    private func loadSampleData() {
        let samples: [StoreNotificationItem] = [
            StoreNotificationItem(
                title: "TechCreator liked your video",
                message: "Building the Future of SwiftUI",
                timestamp: Date().addingTimeInterval(-900),
                isRead: false,
                type: .like,
                source: .user,
                priority: .normal
            ),
            StoreNotificationItem(
                title: "CreativeArtist commented on your video",
                message: "'Amazing tutorial! This really helped me out'",
                timestamp: Date().addingTimeInterval(-3600),
                isRead: false,
                type: .comment,
                source: .user,
                priority: .normal
            ),
            StoreNotificationItem(
                title: "GamingPro started following you",
                message: "Tap to view their channel",
                timestamp: Date().addingTimeInterval(-7200),
                isRead: false,
                type: .follow,
                source: .user,
                priority: .normal
            ),
            StoreNotificationItem(
                title: "MusicMaker is live now",
                message: "MusicMaker just started streaming",
                timestamp: Date().addingTimeInterval(-14400),
                isRead: true,
                type: .live,
                source: .liveAgent,
                priority: .high
            ),
            StoreNotificationItem(
                title: "DesignPro posted a new video",
                message: "UI Design Masterclass 2026",
                timestamp: Date().addingTimeInterval(-86400),
                isRead: true,
                type: .upload,
                source: .user,
                priority: .normal
            ),
        ]
        for s in samples {
            seenIds.insert(s.id)
        }
        items = samples
        recalcUnread()
    }
}

// MARK: - Type Conversion Helpers (file-scope)

private func notifType(from string: String) -> NotificationItem.NotificationType {
    NotificationItem.NotificationType(rawValue: string) ?? .system
}
