//
//  RightsLedgerService.swift
//  MyChannel
//
//  Phase 224: Rights Ledger & Revenue Splits.
//  Collaborator ownership graph, automatic payout split logic,
//  dispute-ready monetization audit trail.
//  Uses `revenue-split-maximizer` + `escrow-payments` Cloud Run.
//

import Foundation

// MARK: - Models

struct RightsEntry: Codable, Identifiable {
    let id: String
    let contentId: String
    let collaboratorId: String
    let role: String
    let ownershipPct: Double
    let revenueSharePct: Double
    let grantedAt: Date
    let isActive: Bool
}

struct RevenueSplit: Codable, Identifiable {
    let id: String
    let contentId: String
    let entries: [SplitEntry]
    let totalRevenue: Double
    let currency: String
    let periodStart: Date
    let periodEnd: Date

    struct SplitEntry: Codable {
        let collaboratorId: String
        let amount: Double
        let pct: Double
        let status: String
    }
}

struct RightsAuditEntry: Codable, Identifiable {
    let id: String
    let contentId: String
    let action: String
    let actor: String
    let details: String
    let timestamp: Date
}

// MARK: - Service

@MainActor
final class RightsLedgerService: ObservableObject {
    static let shared = RightsLedgerService()
    private init() {}

    @Published private(set) var rights: [RightsEntry] = []
    @Published private(set) var splits: [RevenueSplit] = []
    @Published private(set) var auditLog: [RightsAuditEntry] = []

    func fetchRightsLedger(contentId: String) async throws {
        guard AppConfig.Features.enableRightsLedger else { return }
        struct Req: Encodable { let task: String; let contentId: String }
        struct RawR: Decodable { let id: String; let collaborator: String; let role: String; let ownership: Double; let share: Double; let granted: String?; let active: Bool }
        struct Raw: Decodable { let rights: [RawR]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .revenueSplitMaximizer, path: "/predict",
            body: Req(task: "fetch_rights", contentId: contentId)
        )
        rights = (r.rights ?? []).map {
            RightsEntry(id: $0.id, contentId: contentId, collaboratorId: $0.collaborator, role: $0.role,
                        ownershipPct: $0.ownership, revenueSharePct: $0.share,
                        grantedAt: ISO8601DateFormatter().date(from: $0.granted ?? "") ?? Date(), isActive: $0.active)
        }
    }

    func assignRight(contentId: String, collaboratorId: String, role: String, ownershipPct: Double, sharePct: Double) async throws -> RightsEntry {
        guard AppConfig.Features.enableRightsLedger else {
            return RightsEntry(id: "", contentId: contentId, collaboratorId: collaboratorId, role: role,
                               ownershipPct: ownershipPct, revenueSharePct: sharePct, grantedAt: Date(), isActive: true)
        }
        struct Req: Encodable { let task: String; let contentId: String; let collaborator: String; let role: String; let ownership: Double; let share: Double }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .revenueSplitMaximizer, path: "/predict",
            body: Req(task: "assign_right", contentId: contentId, collaborator: collaboratorId,
                      role: role, ownership: ownershipPct, share: sharePct)
        )
        let entry = RightsEntry(id: r.id, contentId: contentId, collaboratorId: collaboratorId, role: role,
                                 ownershipPct: ownershipPct, revenueSharePct: sharePct, grantedAt: Date(), isActive: true)
        rights.append(entry)
        return entry
    }

    func computeSplits(contentId: String, totalRevenue: Double) async throws -> RevenueSplit {
        guard AppConfig.Features.enableRightsLedger else {
            return RevenueSplit(id: "", contentId: contentId, entries: [], totalRevenue: totalRevenue,
                                currency: "USD", periodStart: Date(), periodEnd: Date())
        }
        struct Req: Encodable { let task: String; let contentId: String; let revenue: Double }
        struct RawEntry: Decodable { let collaborator: String; let amount: Double; let pct: Double; let status: String }
        struct Raw: Decodable { let id: String; let entries: [RawEntry]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .escrowPayments, path: "/predict",
            body: Req(task: "compute_splits", contentId: contentId, revenue: totalRevenue), timeout: 30
        )
        let split = RevenueSplit(id: r.id, contentId: contentId,
                                  entries: (r.entries ?? []).map { RevenueSplit.SplitEntry(collaboratorId: $0.collaborator, amount: $0.amount, pct: $0.pct, status: $0.status) },
                                  totalRevenue: totalRevenue, currency: "USD", periodStart: Date(), periodEnd: Date())
        splits.append(split)
        return split
    }

    func fetchAuditTrail(contentId: String) async throws {
        guard AppConfig.Features.enableRightsLedger else { return }
        struct Req: Encodable { let task: String; let contentId: String }
        struct RawA: Decodable { let id: String; let action: String; let actor: String; let details: String; let ts: String? }
        struct Raw: Decodable { let audit: [RawA]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .revenueSplitMaximizer, path: "/predict",
            body: Req(task: "fetch_audit", contentId: contentId)
        )
        auditLog = (r.audit ?? []).map {
            RightsAuditEntry(id: $0.id, contentId: contentId, action: $0.action, actor: $0.actor,
                             details: $0.details, timestamp: ISO8601DateFormatter().date(from: $0.ts ?? "") ?? Date())
        }
    }
}
