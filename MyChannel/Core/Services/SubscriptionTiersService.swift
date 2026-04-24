//
//  SubscriptionTiersService.swift
//  MyChannel
//
//  Phase 59: MyChannel Plus+ tier matrix (Plus+ / Pro / Family).
//  Product IDs are StoreKit only — no external payment bridges.
//

import Foundation
#if canImport(StoreKit)
import StoreKit
#endif

enum PlusTier: String, CaseIterable, Codable {
    case plus
    case pro
    case family

    var displayName: String {
        switch self {
        case .plus:   return "MyChannel Plus+"
        case .pro:    return "MyChannel Plus+ Pro"
        case .family: return "MyChannel Plus+ Family"
        }
    }

    var productIds: (monthly: String, annual: String) {
        switch self {
        case .plus:
            return ("com.mychannel.plus.monthly",        "com.mychannel.plus.annual")
        case .pro:
            return ("com.mychannel.plus.pro.monthly",    "com.mychannel.plus.pro.annual")
        case .family:
            return ("com.mychannel.plus.family.monthly", "com.mychannel.plus.family.annual")
        }
    }

    var benefits: [String] {
        switch self {
        case .plus:
            return [
                "Ad-free on all VOD",
                "1080p offline downloads",
                "AskMyChannel assistant"
            ]
        case .pro:
            return [
                "Everything in Plus+",
                "4K offline downloads",
                "Exclusive AI creator tools (B-roll, thumbnails)",
                "MyChannel Originals",
                "Priority support"
            ]
        case .family:
            return [
                "6 seats in one household",
                "Per-seat Kids Mode profile",
                "Everything in Plus+ for all members"
            ]
        }
    }

    var monthlyPriceHint: String {
        switch self {
        case .plus:   return "$4.99 / mo"
        case .pro:    return "$9.99 / mo"
        case .family: return "$14.99 / mo"
        }
    }
}

@MainActor
final class SubscriptionTiersService: ObservableObject {
    static let shared = SubscriptionTiersService()
    private init() {}

    @Published private(set) var currentTier: PlusTier?
    @Published private(set) var renewsAt: Date?
    @Published private(set) var isLoading = false

    func allTiers() -> [PlusTier] {
        guard AppConfig.Features.enableTieredSubscriptions else { return [.plus] }
        return PlusTier.allCases
    }

    /// Resolve active entitlement from StoreKit 2.
    func refreshEntitlement() async {
        guard AppConfig.Features.enableSubscriptions else {
            currentTier = nil
            return
        }
        #if canImport(StoreKit)
        isLoading = true
        defer { isLoading = false }
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if let tier = Self.tier(for: tx.productID) {
                currentTier = tier
                renewsAt = tx.expirationDate
                return
            }
        }
        currentTier = nil
        renewsAt = nil
        #endif
    }

    /// Purchase the given tier/cadence. Returns true if unlocked.
    @discardableResult
    func purchase(_ tier: PlusTier, annual: Bool) async throws -> Bool {
        guard AppConfig.Features.enableSubscriptions else { throw TierError.subscriptionsDisabled }
        #if canImport(StoreKit)
        let id = annual ? tier.productIds.annual : tier.productIds.monthly
        let products = try await Product.products(for: [id])
        guard let product = products.first else { throw TierError.productMissing(id) }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let tx) = verification {
                await tx.finish()
                await refreshEntitlement()
                return true
            }
            return false
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: - Helpers

    private static func tier(for productId: String) -> PlusTier? {
        for tier in PlusTier.allCases {
            if productId == tier.productIds.monthly || productId == tier.productIds.annual {
                return tier
            }
        }
        return nil
    }

    enum TierError: LocalizedError {
        case subscriptionsDisabled
        case productMissing(String)
        var errorDescription: String? {
            switch self {
            case .subscriptionsDisabled: return "Subscriptions are disabled."
            case .productMissing(let id): return "Product not found: \(id)"
            }
        }
    }
}
