//
//  AutonomousChannelManagerService.swift
//  MyChannel
//
//  Phase 227: Autonomous Channel Manager.
//  Rule-based auto-publish, archive, optimization loops,
//  approval-gated automations.
//  Uses `super-ai-team` Cloud Run.
//

import Foundation

// MARK: - Models

struct AutomationRule: Codable, Identifiable {
    let id: String
    let creatorId: String
    let trigger: String
    let action: String
    let condition: String
    let requiresApproval: Bool
    let isEnabled: Bool
    let lastFiredAt: Date?
}

struct AutomationLog: Codable, Identifiable {
    let id: String
    let ruleId: String
    let action: String
    let result: String
    let approvedBy: String?
    let timestamp: Date
}

// MARK: - Service

@MainActor
final class AutonomousChannelManagerService: ObservableObject {
    static let shared = AutonomousChannelManagerService()
    private init() {}

    @Published private(set) var rules: [AutomationRule] = []
    @Published private(set) var logs: [AutomationLog] = []

    func fetchRules(creatorId: String) async throws {
        guard AppConfig.Features.enableAutonomousChannelManager else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawRule: Decodable { let id: String; let trigger: String; let action: String; let condition: String; let approval: Bool; let enabled: Bool; let last_fired: String? }
        struct Raw: Decodable { let rules: [RawRule]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Req(task: "fetch_automation_rules", creatorId: creatorId)
        )
        rules = (r.rules ?? []).map {
            AutomationRule(id: $0.id, creatorId: creatorId, trigger: $0.trigger, action: $0.action,
                           condition: $0.condition, requiresApproval: $0.approval, isEnabled: $0.enabled,
                           lastFiredAt: $0.last_fired.flatMap { ISO8601DateFormatter().date(from: $0) })
        }
    }

    func createRule(creatorId: String, trigger: String, action: String, condition: String, requiresApproval: Bool) async throws -> AutomationRule {
        guard AppConfig.Features.enableAutonomousChannelManager else {
            return AutomationRule(id: "", creatorId: creatorId, trigger: trigger, action: action,
                                   condition: condition, requiresApproval: requiresApproval, isEnabled: false, lastFiredAt: nil)
        }
        struct Req: Encodable { let task: String; let creatorId: String; let trigger: String; let action: String; let condition: String; let approval: Bool }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Req(task: "create_automation_rule", creatorId: creatorId, trigger: trigger,
                      action: action, condition: condition, approval: requiresApproval)
        )
        let rule = AutomationRule(id: r.id, creatorId: creatorId, trigger: trigger, action: action,
                                   condition: condition, requiresApproval: requiresApproval, isEnabled: true, lastFiredAt: nil)
        rules.append(rule)
        return rule
    }

    func approveExecution(ruleId: String) async throws {
        guard AppConfig.Features.enableAutonomousChannelManager else { return }
        struct Req: Encodable { let task: String; let ruleId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Req(task: "approve_execution", ruleId: ruleId)
        )
    }

    func fetchLogs(creatorId: String, limit: Int = 50) async throws {
        guard AppConfig.Features.enableAutonomousChannelManager else { return }
        struct Req: Encodable { let task: String; let creatorId: String; let limit: Int }
        struct RawLog: Decodable { let id: String; let rule_id: String; let action: String; let result: String; let approved_by: String?; let ts: String? }
        struct Raw: Decodable { let logs: [RawLog]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Req(task: "fetch_automation_logs", creatorId: creatorId, limit: limit)
        )
        logs = (r.logs ?? []).map {
            AutomationLog(id: $0.id, ruleId: $0.rule_id, action: $0.action, result: $0.result,
                          approvedBy: $0.approved_by,
                          timestamp: $0.ts.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date())
        }
    }
}
