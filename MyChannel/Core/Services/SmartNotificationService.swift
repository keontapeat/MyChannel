//
//  SmartNotificationService.swift
//  MyChannel
//
//  Smart notification delivery: optimal send time, frequency limits,
//  personalization, channel preferences. Uses `mychannel-events` Cloud Run.
//

import Foundation

struct SmartNotification: Codable, Identifiable {
    let id: String
    let userId: String
    let type: String
    let title: String
    let body: String
    let deepLink: String?
    let scheduledFor: Date?
    let priority: Int
    let sentAt: Date?
    let openedAt: Date?
}

struct NotificationPreference: Codable {
    let userId: String
    let quietHoursStart: Int
    let quietHoursEnd: Int
    let maxPerDay: Int
    let enabledTypes: [String]
    let timezone: String
}

@MainActor
final class SmartNotificationService: ObservableObject {
    static let shared = SmartNotificationService()
    private init() {}
    @Published private(set) var scheduled: [SmartNotification] = []
    @Published private(set) var preferences: NotificationPreference?

    func scheduleNotification(userId: String, type: String, title: String, body: String, deepLink: String?, priority: Int = 5) async throws -> SmartNotification {
        struct Req: Encodable { let task: String; let userId: String; let type: String; let title: String; let body: String; let deepLink: String?; let priority: Int }
        struct Raw: Decodable { let id: String; let scheduled: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelEvents, path: "/predict",
            body: Req(task: "schedule_notification", userId: userId, type: type, title: title, body: body, deepLink: deepLink, priority: priority))
        let notif = SmartNotification(id: r.id, userId: userId, type: type, title: title, body: body, deepLink: deepLink,
            scheduledFor: r.scheduled.flatMap { ISO8601DateFormatter().date(from: $0) }, priority: priority, sentAt: nil, openedAt: nil)
        scheduled.append(notif); return notif
    }

    func fetchPreferences(userId: String) async throws {
        struct Req: Encodable { let task: String; let userId: String }
        struct Raw: Decodable { let quiet_start: Int?; let quiet_end: Int?; let max_daily: Int?; let types: [String]?; let tz: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelEvents, path: "/predict",
            body: Req(task: "fetch_notification_prefs", userId: userId))
        preferences = NotificationPreference(userId: userId, quietHoursStart: r.quiet_start ?? 22, quietHoursEnd: r.quiet_end ?? 8,
            maxPerDay: r.max_daily ?? 10, enabledTypes: r.types ?? ["newVideo", "liveStart", "subscriber"], timezone: r.tz ?? "America/New_York")
    }

    func updatePreferences(userId: String, quietStart: Int, quietEnd: Int, maxDaily: Int, types: [String]) async throws {
        struct Req: Encodable { let task: String; let userId: String; let quiet_start: Int; let quiet_end: Int; let max_daily: Int; let types: [String] }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.myChannelEvents, path: "/predict",
            body: Req(task: "update_notification_prefs", userId: userId, quiet_start: quietStart, quiet_end: quietEnd, max_daily: maxDaily, types: types))
        preferences = NotificationPreference(userId: userId, quietHoursStart: quietStart, quietHoursEnd: quietEnd,
            maxPerDay: maxDaily, enabledTypes: types, timezone: preferences?.timezone ?? "America/New_York")
    }
}
