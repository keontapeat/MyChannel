//
//  AdvertiserBillingService.swift
//  MyChannel
//
//  Stub for advertiser prepaid billing. See docs/ads-remaining.md
//

import Foundation

enum AdvertiserBillingError: LocalizedError {
    case insufficientBalance
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .insufficientBalance: return "Insufficient ad account balance"
        case .notImplemented: return "Advertiser billing is not yet available"
        }
    }
}

/// Prepaid advertiser balance debited per impression (production: Stripe Customer + CF).
@MainActor
final class AdvertiserBillingService {
    static let shared = AdvertiserBillingService()
    private init() {}

    struct BillingSummary: Sendable {
        let balanceCents: Int
        let currency: String
        let lastInvoiceId: String?
    }

    func fetchSummary(advertiserId: String) async throws -> BillingSummary {
        _ = advertiserId
        // Stub — return zero balance until ad-billing-charge CF is deployed.
        return BillingSummary(balanceCents: 0, currency: "usd", lastInvoiceId: nil)
    }

    func chargeImpression(campaignId: String, cpmCents: Int) async throws {
        _ = (campaignId, cpmCents)
        throw AdvertiserBillingError.notImplemented
    }
}
