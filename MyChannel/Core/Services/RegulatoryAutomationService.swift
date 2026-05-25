//
//  RegulatoryAutomationService.swift
//  MyChannel
//
//  Phase 239: Regulatory Automation Engine.
//  Region-aware compliance orchestration for privacy, AI labeling,
//  child safety, ad disclosure, and export rights.
//  Uses `legal-compliance-ai` + `trust-safety-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct ComplianceRule: Codable, Identifiable {
    let id: String
    let region: String
    let category: ComplianceCategory
    let requirement: String
    let severity: String
    let isSatisfied: Bool
    let lastChecked: Date

    enum ComplianceCategory: String, Codable {
        case privacy, aiLabeling, childSafety, adDisclosure, exportRights, dataResidency
    }
}

struct ComplianceReport: Codable, Identifiable {
    let id: String
    let region: String
    let overallStatus: String
    let rules: [ComplianceRule]
    let generatedAt: Date
    let nextReviewAt: Date?
}

struct RegulatoryAction: Codable, Identifiable {
    let id: String
    let ruleId: String
    let action: String
    let target: String
    let status: String
    let executedAt: Date?
    let result: String?
}

// MARK: - Service

@MainActor
final class RegulatoryAutomationService: ObservableObject {
    static let shared = RegulatoryAutomationService()
    private init() {}

    @Published private(set) var reports: [ComplianceReport] = []
    @Published private(set) var actions: [RegulatoryAction] = []

    func generateReport(region: String) async throws {
        guard AppConfig.Features.enableRegulatoryAutomation else { return }
        struct Req: Encodable { let task: String; let region: String }
        struct RawRule: Decodable { let id: String; let category: String; let requirement: String; let severity: String; let satisfied: Bool; let checked: String? }
        struct Raw: Decodable { let id: String; let status: String?; let rules: [RawRule]?; let next_review: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .legalCompliance, path: "/predict",
            body: Req(task: "generate_report", region: region), timeout: 30
        )
        let report = ComplianceReport(id: r.id, region: region, overallStatus: r.status ?? "unknown",
                                        rules: (r.rules ?? []).map {
                                            ComplianceRule(id: $0.id, region: region,
                                                            category: .init(rawValue: $0.category) ?? .privacy,
                                                            requirement: $0.requirement, severity: $0.severity,
                                                            isSatisfied: $0.satisfied,
                                                            lastChecked: $0.checked.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date())
                                        },
                                        generatedAt: Date(),
                                        nextReviewAt: r.next_review.flatMap { ISO8601DateFormatter().date(from: $0) })
        reports.append(report)
    }

    func executeRemediation(ruleId: String, action: String, target: String) async throws -> RegulatoryAction {
        guard AppConfig.Features.enableRegulatoryAutomation else {
            return RegulatoryAction(id: "", ruleId: ruleId, action: action, target: target, status: "pending", executedAt: nil, result: nil)
        }
        struct Req: Encodable { let task: String; let ruleId: String; let action: String; let target: String }
        struct Raw: Decodable { let id: String; let status: String?; let result: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Req(task: "execute_remediation", ruleId: ruleId, action: action, target: target), timeout: 30
        )
        let regAction = RegulatoryAction(id: r.id, ruleId: ruleId, action: action, target: target,
                                           status: r.status ?? "executed", executedAt: Date(), result: r.result)
        actions.append(regAction)
        return regAction
    }

    func checkRegionCompliance(region: String, feature: String) async throws -> Bool {
        guard AppConfig.Features.enableRegulatoryAutomation else { return true }
        struct Req: Encodable { let task: String; let region: String; let feature: String }
        struct Raw: Decodable { let compliant: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .legalCompliance, path: "/predict",
            body: Req(task: "check_compliance", region: region, feature: feature)
        )
        return r.compliant ?? true
    }
}
