//
//  CCMultiWindowService.swift
//  MyChannel
//
//  Phase 899: Command Center Multi-Window & Split View
//  iPad split view, drag-and-drop, side-by-side comparison, floating widgets, PiP
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class CCMultiWindowService: ObservableObject {
    static let shared = CCMultiWindowService()

    // MARK: - Domain Models

    struct SplitViewConfig: Codable {
        let leftTab: String
        let rightTab: String
        let splitRatio: Double
        let syncScrolling: Bool
    }

    struct FloatingWidget: Identifiable, Codable {
        let id: String
        let widgetType: String
        let title: String
        let size: WidgetSize
        let position: WidgetPosition
        let refreshInterval: TimeInterval
        let isVisible: Bool
    }

    enum WidgetSize: String, Codable {
        case small = "SMALL"
        case medium = "MEDIUM"
        case large = "LARGE"
    }

    struct WidgetPosition: Codable {
        let x: Double
        let y: Double
    }

    struct ComparisonView: Identifiable, Codable {
        let id: String
        let leftMetric: String
        let rightMetric: String
        let leftLabel: String
        let rightLabel: String
        let leftValue: Double
        let rightValue: Double
        let delta: Double
        let deltaLabel: String
    }

    struct DragDropAction: Identifiable, Codable {
        let id: String
        let sourceTab: String
        let targetTab: String
        let actionName: String
        let description: String
    }

    // MARK: - Published State

    @Published private(set) var splitViewConfig: SplitViewConfig?
    @Published private(set) var floatingWidgets: [FloatingWidget] = []
    @Published private(set) var comparisonViews: [ComparisonView] = []
    @Published private(set) var dragDropActions: [DragDropAction] = []
    @Published private(set) var isSplitViewActive = false
    @Published private(set) var pipStreamId: String?
    @Published private(set) var isPipActive = false

    private var db = Firestore.firestore()

    private init() {
        Task { await loadConfig(); await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://cc-multi-window-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableCCMultiWindow else { return nil }
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

    // MARK: - Load Config

    func loadConfig() async {
        let snap = try? await db.collection("ccMultiWindowConfig").document("default").getDocument()
        if let d = snap?.data() {
            splitViewConfig = SplitViewConfig(
                leftTab: d["leftTab"] as? String ?? "briefing",
                rightTab: d["rightTab"] as? String ?? "revenue",
                splitRatio: d["splitRatio"] as? Double ?? 0.5,
                syncScrolling: d["syncScrolling"] as? Bool ?? false
            )
        }

        // Load floating widgets
        let widgetSnap = try? await db.collection("ccFloatingWidgets").whereField("isVisible", isEqualTo: true).getDocuments()
        floatingWidgets = widgetSnap?.documents.compactMap { doc in
            let d = doc.data()
            guard let size = WidgetSize(rawValue: d["size"] as? String ?? "MEDIUM") else { return nil }
            let pos = d["position"] as? [String: Any]
            return FloatingWidget(
                id: doc.documentID,
                widgetType: d["widgetType"] as? String ?? "metric",
                title: d["title"] as? String ?? "",
                size: size,
                position: WidgetPosition(x: pos?["x"] as? Double ?? 0, y: pos?["y"] as? Double ?? 0),
                refreshInterval: d["refreshInterval"] as? TimeInterval ?? 60,
                isVisible: true
            )
        } ?? []

        // Define drag-drop actions
        dragDropActions = [
            DragDropAction(id: "fraud_to_strike", sourceTab: "fraud", targetTab: "users", actionName: "Apply Strike", description: "Drag fraud alert to apply strike to user"),
            DragDropAction(id: "content_to_moderation", sourceTab: "content", targetTab: "fraud", actionName: "Flag for Review", description: "Drag content item to moderation queue"),
            DragDropAction(id: "alert_to_workflow", sourceTab: "briefing", targetTab: "executive", actionName: "Create Workflow", description: "Drag alert to create workflow item")
        ].map { DragDropAction(id: $0.id, sourceTab: $0.sourceTab, targetTab: $0.targetTab, actionName: $0.actionName, description: $0.description) }
    }

    // MARK: - Refresh

    func refresh() async {
        guard AppConfig.Features.enableCCMultiWindow else { return }

        if let result = await callCloudRun(endpoint: "comparison") {
            if let comparisons = result["comparisons"] as? [[String: Any]] {
                comparisonViews = comparisons.compactMap { d in
                    let left = d["leftValue"] as? Double ?? 0
                    let right = d["rightValue"] as? Double ?? 0
                    return ComparisonView(
                        id: UUID().uuidString,
                        leftMetric: d["leftMetric"] as? String ?? "",
                        rightMetric: d["rightMetric"] as? String ?? "",
                        leftLabel: d["leftLabel"] as? String ?? "Today",
                        rightLabel: d["rightLabel"] as? String ?? "Yesterday",
                        leftValue: left,
                        rightValue: right,
                        delta: right != 0 ? ((left - right) / right) * 100 : 0,
                        deltaLabel: d["deltaLabel"] as? String ?? "vs yesterday"
                    )
                }
            }
        }
    }

    // MARK: - Actions

    func activateSplitView(leftTab: String, rightTab: String, ratio: Double = 0.5) {
        splitViewConfig = SplitViewConfig(leftTab: leftTab, rightTab: rightTab, splitRatio: ratio, syncScrolling: false)
        isSplitViewActive = true
        Task {
            try? await db.collection("ccMultiWindowConfig").document("default").setData([
                "leftTab": leftTab, "rightTab": rightTab,
                "splitRatio": ratio, "syncScrolling": false
            ])
        }
    }

    func deactivateSplitView() {
        isSplitViewActive = false
        splitViewConfig = nil
    }

    func addFloatingWidget(type: String, title: String, size: WidgetSize) async {
        let id = UUID().uuidString
        let widget = FloatingWidget(id: id, widgetType: type, title: title, size: size, position: WidgetPosition(x: 20, y: 100), refreshInterval: 60, isVisible: true)
        floatingWidgets.append(widget)
        try? await db.collection("ccFloatingWidgets").document(id).setData([
            "widgetType": type, "title": title, "size": size.rawValue,
            "position": ["x": 20, "y": 100], "refreshInterval": 60, "isVisible": true
        ])
    }

    func removeFloatingWidget(_ id: String) {
        floatingWidgets.removeAll { $0.id == id }
        Task { try? await db.collection("ccFloatingWidgets").document(id).updateData(["isVisible": false]) }
    }

    func startPipStream(_ streamId: String) {
        pipStreamId = streamId
        isPipActive = true
    }

    func stopPipStream() {
        isPipActive = false
        pipStreamId = nil
    }
}
