//
//  GlobalComplianceService.swift
//  MyChannel
//
//  Phase 198: Global Compliance Engine.
//  Per-country regulation, DMCA automation, tax withholding.
//  Uses `trust-safety-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct GlobalComplianceRule: Codable, Identifiable {
    let id: String
    let country: String
    let regulation: String
    let description: String
    let actions: [String]
    let effectiveDate: Date
}

struct ComplianceDMCARequest: Codable, Identifiable {
    let id: String
    let contentId: String
    let claimantName: String
    let claimantEmail: String
    let reason: String
    let status: String
    let filedAt: Date
    let resolvedAt: Date?
}

struct TaxWithholding: Codable, Identifiable {
    let id: String
    let creatorUid: String
    let country: String
    let withholdingPercent: Double
    let treatyRate: Double?
    let formType: String
}

// MARK: - Service

@MainActor
final class GlobalComplianceService: ObservableObject {
    static let shared = GlobalComplianceService()
    private init() {}

    @Published private(set) var rules: [GlobalComplianceRule] = []
    @Published private(set) var dmcaRequests: [ComplianceDMCARequest] = []
    @Published private(set) var taxWithholdings: [TaxWithholding] = []

    func loadRules(country: String) async throws {
        guard AppConfig.Features.enableGlobalCompliance else { return }
        struct Request: Encodable { let task: String; let country: String }
        struct RawRule: Decodable { let regulation: String; let desc: String; let actions: [String] }
        struct Raw: Decodable { let rules: [RawRule]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Request(task: "compliance_rules", country: country)
        )
        rules = (r.rules ?? []).map {
            GlobalComplianceRule(id: UUID().uuidString, country: country, regulation: $0.regulation,
                                 description: $0.desc, actions: $0.actions, effectiveDate: Date())
        }
    }

    func fileDMCA(contentId: String, claimantName: String, email: String, reason: String) async throws -> String {
        guard AppConfig.Features.enableGlobalCompliance else { return "" }
        struct Request: Encodable { let task: String; let contentId: String; let name: String; let email: String; let reason: String }
        struct Raw: Decodable { let request_id: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Request(task: "file_dmca", contentId: contentId, name: claimantName, email: email, reason: reason)
        )
        return r.request_id ?? ""
    }

    func calculateWithholding(creatorUid: String, country: String) async throws -> TaxWithholding {
        guard AppConfig.Features.enableGlobalCompliance else {
            return TaxWithholding(id: "", creatorUid: creatorUid, country: country, withholdingPercent: 0, treatyRate: nil, formType: "")
        }
        struct Request: Encodable { let task: String; let creatorUid: String; let country: String }
        struct Raw: Decodable { let percent: Double?; let treaty: Double?; let form: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Request(task: "tax_withholding", creatorUid: creatorUid, country: country)
        )
        return TaxWithholding(id: UUID().uuidString, creatorUid: creatorUid, country: country,
                             withholdingPercent: r.percent ?? 0, treatyRate: r.treaty, formType: r.form ?? "")
    }
}
