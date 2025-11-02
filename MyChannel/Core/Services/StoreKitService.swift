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
    
    // Configure these in App Store Connect, then match IDs here
    private let subscriptionIDs = [
        "mc.music.monthly",
        "mc.music.annual"
    ]
    
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
    
    func restore() async {
        do {
            try await AppStore.sync()
            await updatePurchased()
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    @available(iOS 15.0, *)
    func hasActiveSubscription() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, subscriptionIDs.contains(tx.productID) {
                if tx.revocationDate == nil && tx.expirationDate ?? .distantFuture > Date() {
                    return true
                }
            }
        }
        return false
    }
    
    // Fallback for older iOS versions
    func hasActiveSubscriptionLegacy() async -> Bool {
        // For iOS 14 and below, assume no active subscription
        // Or implement alternative check using receipt validation
        return false
    }
    
    @available(iOS 15.0, *)
    private func updatePurchased() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result {
                ids.insert(tx.productID)
            }
        }
        purchasedProductIDs = ids
    }
}



