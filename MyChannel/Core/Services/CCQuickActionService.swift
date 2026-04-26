//
//  CCQuickActionService.swift
//  MyChannel
//
//  Phase 897: Command Center Quick Action Engine
//  One-tap moderation, bulk workflows, emergency controls, feature flag shortcuts
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class CCQuickActionService: ObservableObject {
    static let shared = CCQuickActionService()

    // MARK: - Domain Models

    struct QuickAction: Identifiable, Codable {
        let id: String
        let name: String
        let category: ActionCategory
        let icon: String
        let requiresConfirmation: Bool
        let shortcut: String?
        let department: String
        let impactLevel: String
    }

    enum ActionCategory: String, Codable, CaseIterable {
        case moderation = "MODERATION"
        case emergency = "EMERGENCY"
        case userManagement = "USER_MANAGEMENT"
        case featureFlags = "FEATURE_FLAGS"
        case notification = "NOTIFICATION"
        case deployment = "DEPLOYMENT"
    }

    struct BulkOperation: Identifiable, Codable {
        let id: String
        let operation: String
        let targetType: String
        let targetIds: [String]
        let status: String
        let completedCount: Int
        let totalCount: Int
        let startedAt: Date
        let completedAt: Date?
        let errors: [String]
    }

    struct EmergencyControl: Identifiable, Codable {
        let id: String
        let control: String
        let description: String
        let isActive: Bool
        let activatedAt: Date?
        let activatedBy: String?
        let impact: String
    }

    // MARK: - Published State

    @Published private(set) var availableActions: [QuickAction] = []
    @Published private(set) var activeBulkOps: [BulkOperation] = []
    @Published private(set) var emergencyControls: [EmergencyControl] = []
    @Published private(set) var recentActions: [String] = []
    @Published private(set) var isMaintenanceMode = false
    @Published private(set) var killSwitchActive = false

    private var db = Firestore.firestore()

    private init() {
        Task { await loadActions(); await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://cc-quick-actions-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableCCQuickActions else { return nil }
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

    // MARK: - Load Actions

    func loadActions() async {
        let snap = try? await db.collection("ccQuickActions").getDocuments()
        availableActions = snap?.documents.compactMap { doc in
            let d = doc.data()
            guard let category = ActionCategory(rawValue: d["category"] as? String ?? "") else { return nil }
            return QuickAction(
                id: doc.documentID,
                name: d["name"] as? String ?? "",
                category: category,
                icon: d["icon"] as? String ?? "bolt",
                requiresConfirmation: d["requiresConfirmation"] as? Bool ?? true,
                shortcut: d["shortcut"] as? String,
                department: d["department"] as? String ?? "Operations",
                impactLevel: d["impactLevel"] as? String ?? "medium"
            )
        } ?? []

        // Ensure emergency controls exist
        if availableActions.filter({ $0.category == .emergency }).isEmpty {
            availableActions.append(contentsOf: [
                QuickAction(id: "kill_switch", name: "Kill Switch", category: .emergency, icon: "exclamationmark.triangle", requiresConfirmation: true, shortcut: nil, department: "Engineering", impactLevel: "critical"),
                QuickAction(id: "maintenance_mode", name: "Maintenance Mode", category: .emergency, icon: "wrench.and.screwdriver", requiresConfirmation: true, shortcut: nil, department: "Engineering", impactLevel: "high"),
                QuickAction(id: "global_notification", name: "Global Notification", category: .notification, icon: "bell.badge", requiresConfirmation: true, shortcut: nil, department: "Communications", impactLevel: "high")
            ])
        }
    }

    // MARK: - Refresh

    func refresh() async {
        guard AppConfig.Features.enableCCQuickActions else { return }

        // Load emergency control states
        let ctrlSnap = try? await db.collection("emergencyControls").getDocuments()
        emergencyControls = ctrlSnap?.documents.compactMap { doc in
            let d = doc.data()
            return EmergencyControl(
                id: doc.documentID,
                control: d["control"] as? String ?? "",
                description: d["description"] as? String ?? "",
                isActive: d["isActive"] as? Bool ?? false,
                activatedAt: (d["activatedAt"] as? Timestamp)?.dateValue(),
                activatedBy: d["activatedBy"] as? String,
                impact: d["impact"] as? String ?? ""
            )
        } ?? []

        isMaintenanceMode = emergencyControls.contains { $0.control == "maintenance_mode" && $0.isActive }
        killSwitchActive = emergencyControls.contains { $0.control == "kill_switch" && $0.isActive }

        // Load active bulk operations
        let bulkSnap = try? await db.collection("bulkOperations")
            .whereField("status", isNotEqualTo: "COMPLETED")
            .limit(to: 10)
            .getDocuments()
        activeBulkOps = bulkSnap?.documents.compactMap { doc in
            let d = doc.data()
            return BulkOperation(
                id: doc.documentID,
                operation: d["operation"] as? String ?? "",
                targetType: d["targetType"] as? String ?? "",
                targetIds: d["targetIds"] as? [String] ?? [],
                status: d["status"] as? String ?? "pending",
                completedCount: d["completedCount"] as? Int ?? 0,
                totalCount: d["totalCount"] as? Int ?? 0,
                startedAt: (d["startedAt"] as? Timestamp)?.dateValue() ?? Date(),
                completedAt: (d["completedAt"] as? Timestamp)?.dateValue(),
                errors: d["errors"] as? [String] ?? []
            )
        } ?? []
    }

    // MARK: - Actions

    func executeAction(_ actionId: String, params: [String: Any] = [:]) async -> Bool {
        guard let action = availableActions.first(where: { $0.id == actionId }) else { return false }

        _ = await callCloudRun(endpoint: "execute", body: [
            "actionId": actionId,
            "params": params
        ])

        // Log action
        recentActions.insert(action.name, at: 0)
        if recentActions.count > 20 { recentActions = Array(recentActions.prefix(20)) }

        try? await db.collection("ccActionLog").addDocument(data: [
            "actionId": actionId, "actionName": action.name,
            "category": action.category.rawValue,
            "timestamp": Timestamp(date: Date()),
            "params": params
        ])

        await refresh()
        return true
    }

    func bulkModerate(action: String, contentIds: [String]) async -> String {
        let opId = UUID().uuidString
        try? await db.collection("bulkOperations").document(opId).setData([
            "operation": action, "targetType": "content",
            "targetIds": contentIds, "status": "RUNNING",
            "completedCount": 0, "totalCount": contentIds.count,
            "startedAt": Timestamp(date: Date()), "errors": []
        ])
        _ = await callCloudRun(endpoint: "bulk", body: ["operationId": opId, "action": action, "contentIds": contentIds])
        await refresh()
        return opId
    }

    func toggleEmergencyControl(_ controlId: String, activate: Bool, activatedBy: String) async {
        try? await db.collection("emergencyControls").document(controlId).setData([
            "control": controlId,
            "isActive": activate,
            "activatedAt": activate ? Timestamp(date: Date()) : NSNull(),
            "activatedBy": activate ? activatedBy : NSNull(),
            "description": controlId == "kill_switch" ? "Immediately disable all non-essential services" : "Enable platform maintenance mode",
            "impact": controlId == "kill_switch" ? "All user-facing features disabled" : "Read-only mode for all users"
        ], merge: true)

        _ = await callCloudRun(endpoint: "emergency", body: ["controlId": controlId, "activate": activate])
        await refresh()
    }

    func toggleFeatureFlag(_ flagName: String, enabled: Bool) async {
        try? await db.collection("featureFlagOverrides").addDocument(data: [
            "flagName": flagName, "enabled": enabled,
            "changedBy": "owner", "changedAt": Timestamp(date: Date())
        ])
        _ = await callCloudRun(endpoint: "feature-flag", body: ["flagName": flagName, "enabled": enabled])
    }

    func sendMassNotification(title: String, body: String, targetSegment: String) async {
        _ = await callCloudRun(endpoint: "mass-notify", body: [
            "title": title, "body": body, "targetSegment": targetSegment
        ])
    }
}
