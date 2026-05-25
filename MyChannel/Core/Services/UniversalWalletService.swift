//
//  UniversalWalletService.swift
//  MyChannel
//
//  Phase 221: Universal Wallet & Entitlements.
//  Unified subscriptions, gifts, rentals, memberships, receipt reconciliation,
//  fraud-aware restore flow.
//  Uses `revenue-maximizer-ai` + `escrow-payments` Cloud Run.
//

import Foundation

// MARK: - Models

struct WalletEntitlement: Codable, Identifiable {
    let id: String
    let userId: String
    let type: EntitlementType
    let sourceId: String
    let sourcePlatform: String
    let grantedAt: Date
    let expiresAt: Date?
    let isActive: Bool

    enum EntitlementType: String, Codable {
        case subscription, gift, rental, membership, purchase
    }
}

struct WalletTransaction: Codable, Identifiable {
    let id: String
    let userId: String
    let kind: TransactionKind
    let amount: Double
    let currency: String
    let entitlementId: String?
    let receiptData: String?
    let status: TransactionStatus
    let createdAt: Date

    enum TransactionKind: String, Codable { case grant, revoke, restore, purchase, refund }
    enum TransactionStatus: String, Codable { case pending, completed, failed, refunded }
}

struct RestoreResult: Codable {
    let restoredCount: Int
    let entitlements: [WalletEntitlement]
    let fraudFlags: [String]
}

// MARK: - Service

@MainActor
final class UniversalWalletService: ObservableObject {
    static let shared = UniversalWalletService()
    private init() {}

    @Published private(set) var entitlements: [WalletEntitlement] = []
    @Published private(set) var transactions: [WalletTransaction] = []
    @Published private(set) var isRestoring: Bool = false
    @Published private(set) var walletBalance: Double = 0

    func fetchEntitlements(userId: String) async throws {
        guard AppConfig.Features.enableUniversalWallet else { return }
        struct Req: Encodable { let task: String; let userId: String }
        struct RawEnt: Decodable { let id: String; let type: String; let source_id: String; let platform: String; let granted: String?; let expires: String?; let active: Bool }
        struct Raw: Decodable { let entitlements: [RawEnt]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .revenueMaximizer, path: "/predict",
            body: Req(task: "fetch_entitlements", userId: userId)
        )
        entitlements = (r.entitlements ?? []).map {
            WalletEntitlement(id: $0.id, userId: userId, type: .init(rawValue: $0.type) ?? .purchase,
                              sourceId: $0.source_id, sourcePlatform: $0.platform,
                              grantedAt: ISO8601DateFormatter().date(from: $0.granted ?? "") ?? Date(),
                              expiresAt: $0.expires.flatMap { ISO8601DateFormatter().date(from: $0) },
                              isActive: $0.active)
        }
    }

    func restorePurchases(userId: String) async throws -> RestoreResult {
        guard AppConfig.Features.enableUniversalWallet else {
            return RestoreResult(restoredCount: 0, entitlements: [], fraudFlags: [])
        }
        isRestoring = true
        defer { isRestoring = false }
        struct Req: Encodable { let task: String; let userId: String }
        struct Raw: Decodable { let restored: Int?; let entitlements: [WalletEntitlement]?; let fraud_flags: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .escrowPayments, path: "/predict",
            body: Req(task: "restore_purchases", userId: userId), timeout: 45
        )
        let restored = r.entitlements ?? []
        entitlements.append(contentsOf: restored)
        return RestoreResult(restoredCount: r.restored ?? 0, entitlements: restored, fraudFlags: r.fraud_flags ?? [])
    }

    func recordTransaction(_ tx: WalletTransaction) async throws {
        guard AppConfig.Features.enableUniversalWallet else { return }
        struct Req: Encodable { let task: String; let id: String; let kind: String; let amount: Double; let currency: String; let status: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .revenueMaximizer, path: "/predict",
            body: Req(task: "record_transaction", id: tx.id, kind: tx.kind.rawValue,
                      amount: tx.amount, currency: tx.currency, status: tx.status.rawValue)
        )
        transactions.append(tx)
    }

    func reconcileReceipts(userId: String) async throws -> Int {
        guard AppConfig.Features.enableUniversalWallet else { return 0 }
        struct Req: Encodable { let task: String; let userId: String }
        struct Raw: Decodable { let reconciled: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .escrowPayments, path: "/predict",
            body: Req(task: "reconcile_receipts", userId: userId), timeout: 60
        )
        return r.reconciled ?? 0
    }
}
