//
//  CCMobileFirstService.swift
//  MyChannel
//
//  Phase 896: Command Center Mobile-First Redesign
//  One-handed operation, swipe navigation, compact cards, thumb-zone placement
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class CCMobileFirstService: ObservableObject {
    static let shared = CCMobileFirstService()

    // MARK: - Domain Models

    struct MobileLayout: Codable {
        let tabOrder: [String]
        let compactMode: Bool
        let swipeNavigationEnabled: Bool
        let hapticFeedbackEnabled: Bool
        let darkModeOptimized: Bool
        let summaryWidgetCount: Int
        let thumbZoneActions: [String]
    }

    struct CompactMetricCard: Identifiable, Codable {
        let id: String
        let title: String
        let value: String
        let trend: String
        let severity: String
        let tapAction: String
    }

    struct SwipeDestination: Identifiable, Codable {
        let id: String
        let tabName: String
        let direction: String
        let icon: String
    }

    struct GlanceableSummary: Identifiable, Codable {
        let id: String
        let category: String
        let headline: String
        let value: String
        let status: String
        let lastUpdated: Date
    }

    // MARK: - Published State

    @Published private(set) var layout: MobileLayout?
    @Published private(set) var compactCards: [CompactMetricCard] = []
    @Published private(set) var swipeDestinations: [SwipeDestination] = []
    @Published private(set) var glanceableSummaries: [GlanceableSummary] = []
    @Published private(set) var isCompactMode = true
    @Published private(set) var currentTab: String = "briefing"

    private var db = Firestore.firestore()

    private init() {
        Task { await loadLayout(); await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://cc-mobile-first-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableCCMobileFirst else { return nil }
        guard let url = URL(string: "\(cloudRunBase)/\(endpoint)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        do {
            let (data, _) = try await URLSession.configured.data(for: request)
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch { return nil }
    }

    // MARK: - Load Layout

    func loadLayout() async {
        let snap = try? await db.collection("ccMobileLayout").document("default").getDocument()
        if let d = snap?.data() {
            layout = MobileLayout(
                tabOrder: d["tabOrder"] as? [String] ?? ["briefing", "users", "fraud", "content", "reports", "livestreams", "ai", "revenue", "system", "executive"],
                compactMode: d["compactMode"] as? Bool ?? true,
                swipeNavigationEnabled: d["swipeNavigationEnabled"] as? Bool ?? true,
                hapticFeedbackEnabled: d["hapticFeedbackEnabled"] as? Bool ?? true,
                darkModeOptimized: d["darkModeOptimized"] as? Bool ?? true,
                summaryWidgetCount: d["summaryWidgetCount"] as? Int ?? 5,
                thumbZoneActions: d["thumbZoneActions"] as? [String] ?? ["approve", "reject", "escalate", "dismiss"]
            )
            isCompactMode = layout?.compactMode ?? true
        }
    }

    // MARK: - Refresh

    func refresh() async {
        guard AppConfig.Features.enableCCMobileFirst else { return }

        if let result = await callCloudRun(endpoint: "summary") {
            if let cards = result["compactCards"] as? [[String: Any]] {
                compactCards = cards.compactMap { d in
                    CompactMetricCard(
                        id: UUID().uuidString,
                        title: d["title"] as? String ?? "",
                        value: d["value"] as? String ?? "",
                        trend: d["trend"] as? String ?? "stable",
                        severity: d["severity"] as? String ?? "info",
                        tapAction: d["tapAction"] as? String ?? ""
                    )
                }
            }
            if let summaries = result["glanceableSummaries"] as? [[String: Any]] {
                glanceableSummaries = summaries.compactMap { d in
                    GlanceableSummary(
                        id: UUID().uuidString,
                        category: d["category"] as? String ?? "",
                        headline: d["headline"] as? String ?? "",
                        value: d["value"] as? String ?? "",
                        status: d["status"] as? String ?? "ok",
                        lastUpdated: (d["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            }
        }

        // Build swipe destinations from tab order
        let tabs = layout?.tabOrder ?? ["briefing", "users", "fraud", "content", "reports", "livestreams", "ai", "revenue", "system", "executive"]
        swipeDestinations = tabs.enumerated().map { index, tab in
            SwipeDestination(id: tab, tabName: tab, direction: index < tabs.count / 2 ? "left" : "right", icon: tab)
        }
    }

    // MARK: - Actions

    func switchTab(_ tab: String) {
        currentTab = tab
    }

    func toggleCompactMode() {
        isCompactMode.toggle()
        Task {
            try? await db.collection("ccMobileLayout").document("default").updateData(["compactMode": isCompactMode])
        }
    }

    func saveLayoutPreferences(tabOrder: [String], hapticEnabled: Bool, darkMode: Bool) async {
        try? await db.collection("ccMobileLayout").document("default").setData([
            "tabOrder": tabOrder,
            "compactMode": isCompactMode,
            "swipeNavigationEnabled": true,
            "hapticFeedbackEnabled": hapticEnabled,
            "darkModeOptimized": darkMode,
            "summaryWidgetCount": 5,
            "thumbZoneActions": ["approve", "reject", "escalate", "dismiss"]
        ], merge: true)
        await loadLayout()
    }
}
