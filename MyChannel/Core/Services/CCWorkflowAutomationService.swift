//
//  CCWorkflowAutomationService.swift
//  MyChannel
//
//  Phase 889: Command Center Workflow Automation
//  Automated task routing, approval chains, escalation policies, SLA tracking
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class CCWorkflowAutomationService: ObservableObject {
    static let shared = CCWorkflowAutomationService()

    // MARK: - Domain Models

    struct Workflow: Identifiable, Codable {
        let id: String
        let name: String
        let type: WorkflowType
        let status: WorkflowStatus
        let steps: [WorkflowStep]
        let currentStepIndex: Int
        let assignee: String?
        let department: String
        let createdAt: Date
        let updatedAt: Date
        let deadline: Date?
        let slaMinutes: Int
        let slaRemaining: Int?
        let priority: String
    }

    enum WorkflowType: String, Codable, CaseIterable {
        case contentReview = "CONTENT_REVIEW"
        case userAction = "USER_ACTION"
        case featureRollout = "FEATURE_ROLLOUT"
        case incidentResponse = "INCIDENT_RESPONSE"
        case approvalChain = "APPROVAL_CHAIN"
        case complianceReview = "COMPLIANCE_REVIEW"
    }

    enum WorkflowStatus: String, Codable {
        case pending = "PENDING"
        case inProgress = "IN_PROGRESS"
        case blocked = "BLOCKED"
        case completed = "COMPLETED"
        case escalated = "ESCALATED"
        case cancelled = "CANCELLED"
    }

    struct WorkflowStep: Identifiable, Codable {
        let id: String
        let name: String
        let assigneeRole: String
        let action: String
        let completedAt: Date?
        let autoAction: Bool
    }

    struct WorkflowTemplate: Identifiable, Codable {
        let id: String
        let name: String
        let type: WorkflowType
        let steps: [WorkflowStep]
        let slaMinutes: Int
        let department: String
    }

    // MARK: - Published State

    @Published private(set) var activeWorkflows: [Workflow] = []
    @Published private(set) var templates: [WorkflowTemplate] = []
    @Published private(set) var overdueCount: Int = 0
    @Published private(set) var completedToday: Int = 0
    @Published private(set) var avgCompletionMinutes: Double = 0

    private var db = Firestore.firestore()

    private init() {
        Task { await loadTemplates(); await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://cc-workflow-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableCCWorkflowAutomation else { return nil }
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

    // MARK: - Load

    func loadTemplates() async {
        let snap = try? await db.collection("workflowTemplates").getDocuments()
        templates = snap?.documents.compactMap { doc in
            let d = doc.data()
            guard let type = WorkflowType(rawValue: d["type"] as? String ?? "") else { return nil }
            let steps = (d["steps"] as? [[String: Any]])?.compactMap { s -> WorkflowStep? in
                WorkflowStep(
                    id: s["id"] as? String ?? UUID().uuidString,
                    name: s["name"] as? String ?? "",
                    assigneeRole: s["assigneeRole"] as? String ?? "",
                    action: s["action"] as? String ?? "",
                    completedAt: (s["completedAt"] as? Timestamp)?.dateValue(),
                    autoAction: s["autoAction"] as? Bool ?? false
                )
            } ?? []
            return WorkflowTemplate(
                id: doc.documentID, name: d["name"] as? String ?? "",
                type: type, steps: steps,
                slaMinutes: d["slaMinutes"] as? Int ?? 60,
                department: d["department"] as? String ?? "Operations"
            )
        } ?? []
    }

    func refresh() async {
        guard AppConfig.Features.enableCCWorkflowAutomation else { return }

        let snap = try? await db.collection("workflows")
            .whereField("status", isNotEqualTo: "COMPLETED")
            .order(by: "updatedAt", descending: true)
            .limit(to: 30)
            .getDocuments()
        activeWorkflows = snap?.documents.compactMap { parseWorkflow($0.data(), id: $0.documentID) } ?? []

        overdueCount = activeWorkflows.filter { wf in
            if let deadline = wf.deadline { return deadline < Date() && wf.status != .completed }
            return false
        }.count

        // Cloud Run for metrics
        if let result = await callCloudRun(endpoint: "metrics") {
            completedToday = result["completedToday"] as? Int ?? 0
            avgCompletionMinutes = result["avgCompletionMinutes"] as? Double ?? 0
        }
    }

    // MARK: - Actions

    func createWorkflow(templateId: String, assignee: String?, priority: String, deadline: Date?) async {
        guard let template = templates.first(where: { $0.id == templateId }) else { return }
        let id = UUID().uuidString
        let now = Date()

        try? await db.collection("workflows").document(id).setData([
            "name": template.name, "type": template.type.rawValue,
            "status": "PENDING", "currentStepIndex": 0,
            "assignee": assignee ?? "", "department": template.department,
            "createdAt": Timestamp(date: now), "updatedAt": Timestamp(date: now),
            "deadline": deadline != nil ? Timestamp(date: deadline!) : NSNull(),
            "slaMinutes": template.slaMinutes, "priority": priority,
            "steps": template.steps.map { [
                "id": $0.id, "name": $0.name, "assigneeRole": $0.assigneeRole,
                "action": $0.action, "autoAction": $0.autoAction
            ]}
        ])

        _ = await callCloudRun(endpoint: "create", body: ["workflowId": id])
        await refresh()
    }

    func advanceStep(_ workflowId: String) async {
        try? await db.collection("workflows").document(workflowId).updateData([
            "currentStepIndex": FieldValue.increment(Int64(1)),
            "updatedAt": Timestamp(date: Date())
        ])
        _ = await callCloudRun(endpoint: "advance", body: ["workflowId": workflowId])
        await refresh()
    }

    func escalate(_ workflowId: String, reason: String) async {
        try? await db.collection("workflows").document(workflowId).updateData([
            "status": "ESCALATED", "updatedAt": Timestamp(date: Date()),
            "escalationReason": reason
        ])
        _ = await callCloudRun(endpoint: "escalate", body: ["workflowId": workflowId, "reason": reason])
        await refresh()
    }

    // MARK: - Helpers

    private func parseWorkflow(_ d: [String: Any], id: String) -> Workflow? {
        guard let type = WorkflowType(rawValue: d["type"] as? String ?? ""),
              let status = WorkflowStatus(rawValue: d["status"] as? String ?? "") else { return nil }
        let steps = (d["steps"] as? [[String: Any]])?.compactMap { s -> WorkflowStep? in
            WorkflowStep(
                id: s["id"] as? String ?? UUID().uuidString,
                name: s["name"] as? String ?? "",
                assigneeRole: s["assigneeRole"] as? String ?? "",
                action: s["action"] as? String ?? "",
                completedAt: (s["completedAt"] as? Timestamp)?.dateValue(),
                autoAction: s["autoAction"] as? Bool ?? false
            )
        } ?? []
        return Workflow(
            id: id, name: d["name"] as? String ?? "", type: type, status: status,
            steps: steps, currentStepIndex: d["currentStepIndex"] as? Int ?? 0,
            assignee: d["assignee"] as? String, department: d["department"] as? String ?? "",
            createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            deadline: (d["deadline"] as? Timestamp)?.dateValue(),
            slaMinutes: d["slaMinutes"] as? Int ?? 60,
            slaRemaining: d["slaRemaining"] as? Int,
            priority: d["priority"] as? String ?? "MEDIUM"
        )
    }
}
