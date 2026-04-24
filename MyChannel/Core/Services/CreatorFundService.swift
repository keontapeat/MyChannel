//
//  CreatorFundService.swift
//  MyChannel
//
//  Phase 57: MyChannel Creator Fund.
//  Performance-based payouts from a platform pool, allocated monthly by
//  `creator-fund-allocator` Cloud Run service. Payouts settle via
//  Stripe Connect on the web dashboard only (App Review 3.1.1 compliant).
//

import Foundation

struct CreatorFundPeriod: Codable, Equatable {
    let monthStart: Date
    let monthEnd: Date
    let poolUSD: Decimal
    let recipients: Int
}

struct CreatorFundGrant: Codable, Identifiable, Equatable {
    let id: String
    let creatorId: String
    let period: CreatorFundPeriod
    let grantUSD: Decimal
    let engagementScore: Double     // 0...1
    let watchHours: Double
    let uniqueViewers: Int
    let monetizationFlags: [String]
    let status: Status

    enum Status: String, Codable { case pending, approved, paid, withheld }
}

struct CreatorFundEligibility: Codable {
    let eligible: Bool
    let reasons: [String]
    let nextCheckAt: Date?
}

@MainActor
final class CreatorFundService: ObservableObject {
    static let shared = CreatorFundService()
    private init() {}

    @Published private(set) var latestGrant: CreatorFundGrant?
    @Published private(set) var eligibility: CreatorFundEligibility?

    /// Returns current eligibility for the signed-in creator.
    func checkEligibility(creatorId: String) async throws -> CreatorFundEligibility {
        guard AppConfig.Features.enableCreatorFund else {
            let d = CreatorFundEligibility(eligible: false, reasons: ["creator_fund_disabled"], nextCheckAt: nil)
            eligibility = d
            return d
        }
        struct Request: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable {
            let eligible: Bool?
            let reasons: [String]?
            let next_check_at: Double?
        }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorFundAllocator,
            path: "/predict",
            body: Request(task: "eligibility", creatorId: creatorId)
        )
        let e = CreatorFundEligibility(
            eligible: r.eligible ?? false,
            reasons: r.reasons ?? [],
            nextCheckAt: r.next_check_at.map { Date(timeIntervalSince1970: $0) }
        )
        eligibility = e
        return e
    }

    /// Fetch the latest awarded grant for this creator (current or previous month).
    func latestGrant(creatorId: String) async throws -> CreatorFundGrant? {
        guard AppConfig.Features.enableCreatorFund else { return nil }
        struct Request: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable {
            let id: String?
            let creator_id: String?
            let month_start: Double?
            let month_end: Double?
            let pool_usd: Double?
            let recipients: Int?
            let grant_usd: Double?
            let engagement_score: Double?
            let watch_hours: Double?
            let unique_viewers: Int?
            let monetization_flags: [String]?
            let status: String?
        }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorFundAllocator,
            path: "/predict",
            body: Request(task: "latest_grant", creatorId: creatorId)
        )
        guard
            let id = r.id,
            let ms = r.month_start, let me = r.month_end,
            let pool = r.pool_usd, let grant = r.grant_usd
        else { return nil }
        let period = CreatorFundPeriod(
            monthStart: Date(timeIntervalSince1970: ms),
            monthEnd: Date(timeIntervalSince1970: me),
            poolUSD: Decimal(pool),
            recipients: r.recipients ?? 0
        )
        let g = CreatorFundGrant(
            id: id,
            creatorId: r.creator_id ?? creatorId,
            period: period,
            grantUSD: Decimal(grant),
            engagementScore: r.engagement_score ?? 0,
            watchHours: r.watch_hours ?? 0,
            uniqueViewers: r.unique_viewers ?? 0,
            monetizationFlags: r.monetization_flags ?? [],
            status: CreatorFundGrant.Status(rawValue: r.status ?? "pending") ?? .pending
        )
        latestGrant = g
        return g
    }

    /// Returns the signed URL the creator should open in Safari to accept
    /// Stripe Connect onboarding + claim payout. Opened externally — never
    /// rendered in-app per App Review 3.1.1.
    func payoutDashboardURL(creatorId: String) async throws -> URL {
        guard AppConfig.Features.enableCreatorFund else { throw FundError.disabled }
        struct Request: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let url: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorFundAllocator,
            path: "/predict",
            body: Request(task: "payout_url", creatorId: creatorId)
        )
        guard let urlStr = r.url, let url = URL(string: urlStr) else { throw FundError.noURL }
        return url
    }

    enum FundError: LocalizedError {
        case disabled, noURL
        var errorDescription: String? {
            switch self {
            case .disabled: return "Creator Fund is not enabled."
            case .noURL: return "Payout dashboard unavailable."
            }
        }
    }
}
