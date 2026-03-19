import Foundation
import StoreKit
import SwiftUI

@MainActor
final class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil
    
    // MARK: - 🌟 MYCHANNEL PLUS+ SUBSCRIPTION IDS
    // Configure these in App Store Connect, then match IDs here
    private let subscriptionIDs = [
        "com.mychannel.plus.monthly",
        "com.mychannel.plus.annual",
        "mc.music.monthly",
        "mc.music.annual"
    ]
    
    // Quick access to premium status
    var isPremium: Bool {
        !purchasedProductIDs.isEmpty
    }
    
    private init() {}
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let storeProducts = try await Product.products(for: Set(subscriptionIDs))
            self.products = storeProducts.sorted(by: { $0.displayPrice < $1.displayPrice })
            await updatePurchased()
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    // MARK: - 💰 PURCHASE METHODS
    
    /// Purchase a product
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification { case .verified(_): break; case .unverified(_, _): break }
                await updatePurchased()
                return true
            case .userCancelled: return false
            case .pending: return false
            default: return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
    
    /// Purchase using SubscriptionPlan enum
    func purchase(plan: SubscriptionPlan) async throws -> Bool {
        #if DEBUG && targetEnvironment(simulator)
        // Simulator-only mock: avoids StoreKit sandbox requirement on simulators
        print("🛍️ [StoreKit] SIMULATOR: Simulating purchase for \(plan.displayName)")
        try await Task.sleep(nanoseconds: 500_000_000)
        return true
        #else
        // First, load products if not already loaded
        if products.isEmpty {
            await loadProducts()
        }
        
        // Find the matching product
        guard let product = products.first(where: { $0.id == plan.productID }) else {
            throw StoreKitError.productNotFound
        }
        
        return await purchase(product)
        #endif
    }
    
    func restore() async {
        do {
            try await AppStore.sync()
            await updatePurchased()
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    func hasActiveSubscription() async -> Bool {
        if #available(iOS 15.0, *) {
            // Note: Transaction.currentEntitlements requires iOS 15+
            do {
                for await result in StoreKit.Transaction.currentEntitlements {
                    if case .verified(let tx) = result, subscriptionIDs.contains(tx.productID) {
                        if tx.revocationDate == nil && tx.expirationDate ?? .distantFuture > Date() {
                            return true
                        }
                    }
                }
            } catch {
                print("⚠️ [StoreKit] Error checking entitlements: \(error)")
            }
            return false
        } else {
            // For iOS 14 and below, assume no active subscription
            // Or implement alternative check using receipt validation
            return false
        }
    }
    
    private func updatePurchased() async {
        if #available(iOS 15.0, *) {
            var ids = Set<String>()
            do {
                for await result in StoreKit.Transaction.currentEntitlements {
                    if case .verified(let tx) = result {
                        ids.insert(tx.productID)
                    }
                }
            } catch {
                print("⚠️ [StoreKit] Error updating purchased: \(error)")
            }
            purchasedProductIDs = ids
        }
    }
}

// MARK: - Errors

enum StoreKitError: Error {
    case productNotFound
    case purchaseFailed
    case verificationFailed
    
    var localizedDescription: String {
        switch self {
        case .productNotFound:
            return "Subscription product not found. Please try again."
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        case .verificationFailed:
            return "Could not verify purchase. Please contact support."
        }
    }
}



