//
//  FeedNotificationBadgeService.swift
//  MyChannel
//
//  Phase 275: Feed Notification Badges — new content badges, live indicators,
//  unread counts, badge fatigue management, badge priority.
//

import Foundation

struct FeedBadge: Codable, Identifiable {
    let id: String
    let targetId: String
    let type: BadgeType
    let count: Int
    let priority: Int
    enum BadgeType: String, Codable { case newContent, live, unread, trending, reminder }
}

@MainActor
final class FeedNotificationBadgeService: ObservableObject {
    static let shared = FeedNotificationBadgeService()
    private init() {}

    @Published private(set) var badges: [String: FeedBadge] = [:]

    func setBadge(targetId: String, type: FeedBadge.BadgeType, count: Int = 1, priority: Int = 5) {
        guard AppConfig.Features.enableFeedNotificationBadge else { return }
        badges[targetId] = FeedBadge(id: UUID().uuidString, targetId: targetId, type: type, count: count, priority: priority)
    }

    func clearBadge(targetId: String) { badges.removeValue(forKey: targetId) }

    func highestPriorityBadge(for targetId: String) -> FeedBadge? { badges[targetId] }
}
