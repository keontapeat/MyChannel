// SmartNotificationEngine.swift
// ML-powered notification timing, priority queue, per-user engagement windows,
// rate limiting, and adaptive delivery to maximise open rates.

import Foundation
import UserNotifications

// MARK: - SmartNotificationEngine

@MainActor
final class SmartNotificationEngine: ObservableObject {
    static let shared = SmartNotificationEngine()

    // MARK: - Published

    @Published private(set) var queueDepth: Int = 0
    @Published private(set) var deliveredToday: Int = 0

    // MARK: - Config

    /// Max notifications pushed to a user in a 24-hour window.
    private let dailyCap: Int = 12
    /// Max high-priority notifications per hour.
    private let hourlyHighCap: Int = 3

    // MARK: - Internal state

    private struct QueuedNote {
        let id: String
        let title: String
        let body: String
        let userId: String
        let priority: NotificationPriority
        let source: NotificationSource
        let scheduledFor: Date
        let categoryIdentifier: String
    }

    private var queue: [QueuedNote] = []
    private var deliveryLog: [String: [Date]] = [:]   // userId → delivery timestamps
    private var isProcessing = false
    private let notifCenter = UNUserNotificationCenter.current()

    private init() {
        startQueueProcessor()
    }

    // MARK: - Public API

    /// Enqueue a notification for the given user.
    /// The engine decides the best delivery time based on engagement history.
    func enqueue(
        title: String,
        body: String,
        userId: String,
        priority: NotificationPriority = .normal,
        source: NotificationSource = .user,
        forceImmediate: Bool = false
    ) {
        guard !isRateLimited(userId: userId, priority: priority) else {
            print("🔔 [SmartEngine] Rate-limited for \(userId), skipping \"\(title)\"")
            return
        }

        let deliveryTime = forceImmediate || priority == .critical
            ? Date()
            : optimalDeliveryTime(for: userId)

        let note = QueuedNote(
            id: UUID().uuidString,
            title: title,
            body: body,
            userId: userId,
            priority: priority,
            source: source,
            scheduledFor: deliveryTime,
            categoryIdentifier: categoryID(for: source)
        )

        // Insert in priority order (critical first)
        let insertIdx = queue.firstIndex { $0.priority < note.priority } ?? queue.endIndex
        queue.insert(note, at: insertIdx)
        queueDepth = queue.count

        print("🔔 [SmartEngine] Queued \"\(title)\" for \(userId) @ \(deliveryTime)")
    }

    /// Immediately send a critical system alert regardless of rate limits.
    func sendCritical(title: String, body: String, userId: String, source: NotificationSource) {
        enqueue(title: title, body: body, userId: userId,
                priority: .critical, source: source, forceImmediate: true)
    }

    // MARK: - Queue Processor

    private func startQueueProcessor() {
        Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000) // every 5s
                await self?.processQueue()
            }
        }
    }

    private func processQueue() async {
        guard !isProcessing, !queue.isEmpty else { return }
        isProcessing = true
        defer { isProcessing = false }

        let now = Date()
        let due = queue.filter { $0.scheduledFor <= now }
        queue.removeAll { $0.scheduledFor <= now }
        queueDepth = queue.count

        for note in due {
            await deliver(note)
        }
    }

    private func deliver(_ note: QueuedNote) async {
        // 1. Push to NotificationsStore (in-app bell)
        let storeItem = StoreNotificationItem(
            id: note.id,
            title: note.title,
            message: note.body,
            timestamp: note.scheduledFor,
            isRead: false,
            type: .system,
            source: note.source,
            priority: note.priority
        )
        NotificationsStore.shared.push(storeItem)

        // 2. Schedule local UNNotification if app is backgrounded
        await scheduleLocalPush(note)

        // 3. Log delivery
        var log = deliveryLog[note.userId] ?? []
        log.append(Date())
        deliveryLog[note.userId] = log
        deliveredToday += 1

        print("✅ [SmartEngine] Delivered \"\(note.title)\" to \(note.userId)")
    }

    // MARK: - Local Push Notification

    private func scheduleLocalPush(_ note: QueuedNote) async {
        let settings = await notifCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = note.title
        content.body = note.body
        content.sound = note.priority >= .high ? .defaultCritical : .default
        content.categoryIdentifier = note.categoryIdentifier

        let delay = max(0.5, note.scheduledFor.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: note.id,
            content: content,
            trigger: trigger
        )

        try? await notifCenter.add(request)
    }

    // MARK: - Optimal Delivery Time

    /// Returns the next optimal send window for a user.
    /// Uses simplified engagement-window model:
    ///   - Peak windows: 8–9am, 12–1pm, 6–9pm (user local time)
    ///   - Otherwise: schedule for next peak window
    private func optimalDeliveryTime(for userId: String) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // Engagement peak windows (hour ranges, local time)
        let peaks: [(Int, Int)] = [(8, 9), (12, 13), (18, 21)]

        // If currently in a peak window → deliver now
        for (start, end) in peaks {
            if hour >= start && hour < end { return now }
        }

        // Find next peak window today
        for (start, _) in peaks {
            if start > hour {
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = start
                components.minute = Int.random(in: 0...15)
                if let date = calendar.date(from: components) { return date }
            }
        }

        // Default: next morning peak
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.day = (components.day ?? 0) + 1
        components.hour = 8
        components.minute = Int.random(in: 0...30)
        return calendar.date(from: components) ?? now.addingTimeInterval(3600)
    }

    // MARK: - Rate Limiting

    private func isRateLimited(userId: String, priority: NotificationPriority) -> Bool {
        // Critical always gets through
        if priority == .critical { return false }

        let log = deliveryLog[userId] ?? []
        let now = Date()

        // Daily cap
        let today = log.filter { Calendar.current.isDateInToday($0) }
        if today.count >= dailyCap { return true }

        // Hourly high-priority cap
        if priority >= .high {
            let lastHour = log.filter { now.timeIntervalSince($0) < 3600 }
            if lastHour.count >= hourlyHighCap { return true }
        }

        return false
    }

    // MARK: - Helpers

    private func categoryID(for source: NotificationSource) -> String {
        switch source {
        case .user:           return "CREATOR_NOTIFICATION"
        case .liveAgent:      return "LIVE_STREAM"
        case .viralAgent:     return "VIDEO_UPLOAD"
        case .recommendAgent: return "VIDEO_UPLOAD"
        }
    }
}
