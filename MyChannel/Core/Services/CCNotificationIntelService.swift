//
//  CCNotificationIntelService.swift
//  MyChannel
//
//  Phase 898: Command Center Notification Intelligence
//  Smart alert routing, priority inbox, quiet hours, alert fatigue detection
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class CCNotificationIntelService: ObservableObject {
    static let shared = CCNotificationIntelService()

    // MARK: - Domain Models

    struct CCNotification: Identifiable, Codable {
        let id: String
        let title: String
        let body: String
        let severity: NotificationSeverity
        let department: String
        let category: String
        let isRead: Bool
        let isActionable: Bool
        let actionLabel: String?
        let actionDestination: String?
        let createdAt: Date
        let expiresAt: Date?
        let relatedEntityId: String?
    }

    enum NotificationSeverity: String, Codable {
        case critical = "CRITICAL"
        case high = "HIGH"
        case medium = "MEDIUM"
        case low = "LOW"
        case info = "INFO"
    }

    struct QuietHoursConfig: Codable {
        let enabled: Bool
        let startHour: Int
        let endHour: Int
        let timezone: String
        let criticalOverride: Bool
    }

    struct AlertFatigueMetrics: Codable {
        let notificationsLast24h: Int
        let avgPerHour: Double
        let dismissRate: Double
        let actionRate: Double
        let fatigueScore: Double
        let recommendedReduction: Int
    }

    struct EscalationChain: Identifiable, Codable {
        let id: String
        let notificationId: String
        let currentLevel: Int
        let maxLevel: Int
        let nextEscalationAt: Date
        let notifiedRoles: [String]
    }

    // MARK: - Published State

    @Published private(set) var priorityInbox: [CCNotification] = []
    @Published private(set) var unreadCritical: Int = 0
    @Published private(set) var unreadHigh: Int = 0
    @Published private(set) var unreadTotal: Int = 0
    @Published private(set) var quietHours: QuietHoursConfig?
    @Published private(set) var fatigueMetrics: AlertFatigueMetrics?
    @Published private(set) var effectivenessScore: Double = 100
    @Published private(set) var activeEscalations: [EscalationChain] = []

    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private init() {
        Task { await loadQuietHours(); await refresh(); startListening() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://cc-notification-intel-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableCCNotificationIntel else { return nil }
        guard let url = URL(string: "\(cloudRunBase)/\(endpoint)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch { return nil }
    }

    // MARK: - Load & Listen

    func loadQuietHours() async {
        let snap = try? await db.collection("ccQuietHours").document("default").getDocument()
        if let d = snap?.data() {
            quietHours = QuietHoursConfig(
                enabled: d["enabled"] as? Bool ?? false,
                startHour: d["startHour"] as? Int ?? 22,
                endHour: d["endHour"] as? Int ?? 7,
                timezone: d["timezone"] as? String ?? "America/New_York",
                criticalOverride: d["criticalOverride"] as? Bool ?? true
            )
        }
    }

    func startListening() {
        listener = db.collection("ccNotifications")
            .whereField("isRead", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let notifs = snap?.documents.compactMap { self.parseNotification($0.data(), id: $0.documentID) } ?? []
                Task { @MainActor in
                    self.priorityInbox = notifs.sorted { self.severityOrder($0.severity) < self.severityOrder($1.severity) }
                    self.unreadCritical = notifs.filter { $0.severity == .critical }.count
                    self.unreadHigh = notifs.filter { $0.severity == .high }.count
                    self.unreadTotal = notifs.count
                }
            }
    }

    // MARK: - Refresh

    func refresh() async {
        guard AppConfig.Features.enableCCNotificationIntel else { return }

        if let result = await callCloudRun(endpoint: "metrics") {
            fatigueMetrics = AlertFatigueMetrics(
                notificationsLast24h: result["notificationsLast24h"] as? Int ?? 0,
                avgPerHour: result["avgPerHour"] as? Double ?? 0,
                dismissRate: result["dismissRate"] as? Double ?? 0,
                actionRate: result["actionRate"] as? Double ?? 0,
                fatigueScore: result["fatigueScore"] as? Double ?? 0,
                recommendedReduction: result["recommendedReduction"] as? Int ?? 0
            )
            effectivenessScore = result["effectivenessScore"] as? Double ?? 100
        }

        // Load active escalations
        let escSnap = try? await db.collection("ccEscalations")
            .whereField("currentLevel", isLessThan: 5)
            .limit(to: 10)
            .getDocuments()
        activeEscalations = escSnap?.documents.compactMap { doc in
            let d = doc.data()
            return EscalationChain(
                id: doc.documentID,
                notificationId: d["notificationId"] as? String ?? "",
                currentLevel: d["currentLevel"] as? Int ?? 0,
                maxLevel: d["maxLevel"] as? Int ?? 3,
                nextEscalationAt: (d["nextEscalationAt"] as? Timestamp)?.dateValue() ?? Date(),
                notifiedRoles: d["notifiedRoles"] as? [String] ?? []
            )
        } ?? []
    }

    // MARK: - Actions

    func markRead(_ notificationId: String) async {
        try? await db.collection("ccNotifications").document(notificationId).updateData(["isRead": true])
    }

    func markAllRead() async {
        let batch = db.batch()
        for notif in priorityInbox {
            batch.updateData(["isRead": true], forDocument: db.collection("ccNotifications").document(notif.id))
        }
        try? await batch.commit()
    }

    func updateQuietHours(enabled: Bool, start: Int, end: Int, criticalOverride: Bool) async {
        try? await db.collection("ccQuietHours").document("default").setData([
            "enabled": enabled, "startHour": start, "endHour": end,
            "timezone": TimeZone.current.identifier, "criticalOverride": criticalOverride
        ])
        quietHours = QuietHoursConfig(enabled: enabled, startHour: start, endHour: end, timezone: TimeZone.current.identifier, criticalOverride: criticalOverride)
    }

    func routeNotification(_ notification: CCNotification) async {
        // Check quiet hours
        if let qh = quietHours, qh.enabled {
            let hour = Calendar.current.component(.hour, from: Date())
            let inQuietHours = hour >= qh.startHour || hour < qh.endHour
            if inQuietHours && notification.severity != .critical && !qh.criticalOverride { return }
        }
        _ = await callCloudRun(endpoint: "route", body: ["notificationId": notification.id, "severity": notification.severity.rawValue])
    }

    // MARK: - Helpers

    private func severityOrder(_ severity: NotificationSeverity) -> Int {
        switch severity {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        case .info: return 4
        }
    }

    private func parseNotification(_ d: [String: Any], id: String) -> CCNotification? {
        guard let severity = NotificationSeverity(rawValue: d["severity"] as? String ?? "") else { return nil }
        return CCNotification(
            id: id,
            title: d["title"] as? String ?? "",
            body: d["body"] as? String ?? "",
            severity: severity,
            department: d["department"] as? String ?? "",
            category: d["category"] as? String ?? "",
            isRead: d["isRead"] as? Bool ?? false,
            isActionable: d["isActionable"] as? Bool ?? false,
            actionLabel: d["actionLabel"] as? String,
            actionDestination: d["actionDestination"] as? String,
            createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            expiresAt: (d["expiresAt"] as? Timestamp)?.dateValue(),
            relatedEntityId: d["relatedEntityId"] as? String
        )
    }
}
