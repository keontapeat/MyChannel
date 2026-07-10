//
//  AdRefundService.swift
//  MyChannel
//
//  Stub refund path for unused ad spend. See docs/ads-remaining.md
//

import Foundation

enum AdRefundReason: String, Codable, Sendable {
    case campaignPaused
    case campaignCancelled
    case billingError
    case policyViolation
}

enum AdRefundError: LocalizedError {
    case nothingToRefund
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .nothingToRefund: return "No refundable ad spend on this campaign"
        case .notImplemented: return "Ad spend refunds are not yet available"
        }
    }
}

/// Refunds unused prepaid ad balance (30-day window, prorated for paused campaigns).
@MainActor
final class AdRefundService {
    static let shared = AdRefundService()
    private init() {}

    struct RefundRequest: Sendable {
        let campaignId: String
        let advertiserId: String
        let reason: AdRefundReason
        let idempotencyKey: String
    }

    func requestRefund(_ request: RefundRequest) async throws -> Int {
        guard !request.campaignId.isEmpty else { throw AdRefundError.nothingToRefund }
        // Idempotency: ad_refund_{campaignId}_{reason} — enforced server-side in production.
        _ = request
        throw AdRefundError.notImplemented
    }
}
