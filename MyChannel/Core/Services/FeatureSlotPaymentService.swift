//
//  FeatureSlotPaymentService.swift
//  MyChannel
//
//  IAP-ONLY payment layer for ranked feature-slot bookings.
//
//  Apple Guideline 3.1.3(g): buying a "boost" to feature your own content
//  inside the app is a digital purchase and MUST use In-App Purchase. There is
//  no external/Stripe path here on purpose — using one would risk removal from
//  the App Store.
//
//  Each (rank, duration) maps to one Consumable IAP product. The flow is
//  review-BEFORE-pay: the creator is only allowed to purchase after an admin
//  approves the booking, so Apple is never charged for content that gets
//  rejected (no refunds, no disputes).
//
//  ──────────────────────────────────────────────────────────────────────────
//  APP STORE CONNECT SETUP (required before these purchases work):
//  Create 30 Consumable in-app purchases with these product IDs and prices.
//  Product IDs come from FeatureSlotPricing.productID(rank:duration:):
//
//    com.mychannel.feat.slot1.1week   = $5,000     (flagship #1 / week)
//    com.mychannel.feat.slot1.2weeks  = $8,000
//    com.mychannel.feat.slot1.1month  = $9,999
//    com.mychannel.feat.slot2.1week   = $2,500     ... etc (see FeatureSlotPricing.matrix)
//    ...
//    com.mychannel.feat.slot10.1month = $300
//
//  Prices above $999.99 require requesting the higher price points (up to
//  $9,999.99) in App Store Connect → your IAP → Price Schedule.
//  ──────────────────────────────────────────────────────────────────────────
//

import Foundation
import StoreKit

@MainActor
final class FeatureSlotPaymentService: ObservableObject {
    static let shared = FeatureSlotPaymentService()

    @Published var availableProducts: [Product] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    private init() {}

    // MARK: - Product loading

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: Set(FeatureSlotPricing.allProductIDs))
            availableProducts = products
            if products.isEmpty {
                print("⚠️ [FeatureSlotPayment] No products returned. Create the IAPs in App Store Connect (see file header).")
            }
        } catch {
            lastError = error.localizedDescription
            print("❌ [FeatureSlotPayment] loadProducts: \(error)")
        }
    }

    /// Live StoreKit price for a slot, or the fixed-matrix fallback for display
    /// before products load.
    func displayPrice(rank: Int, duration: FeatureSlotDuration) -> Double {
        if let product = product(rank: rank, duration: duration) {
            return Double(truncating: NSDecimalNumber(decimal: product.price))
        }
        return FeatureSlotPricing.price(rank: rank, duration: duration)
    }

    func product(rank: Int, duration: FeatureSlotDuration) -> Product? {
        let id = FeatureSlotPricing.productID(rank: rank, duration: duration)
        return availableProducts.first { $0.id == id }
    }

    // MARK: - Purchase (IAP only)

    /// Charges for an APPROVED slot and returns the verified transaction id.
    /// Throws if the product isn't configured, the user cancels, or verification
    /// fails. Callers must only invoke this after admin approval.
    func purchase(rank: Int, duration: FeatureSlotDuration) async throws -> String {
        guard let product = product(rank: rank, duration: duration) else {
            throw FeatureSlotError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                return String(transaction.id)
            case .unverified(_, let error):
                throw FeatureSlotError.paymentFailed(error.localizedDescription)
            }
        case .userCancelled:
            throw FeatureSlotError.userCancelled
        case .pending:
            throw FeatureSlotError.paymentFailed("Payment is pending approval. You'll be charged once it clears.")
        @unknown default:
            throw FeatureSlotError.paymentFailed("Unknown StoreKit result.")
        }
    }
}
