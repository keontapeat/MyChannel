import Foundation
import StoreKit

/// Phase 38: Creator Tipping & Micro-transactions
/// Handles in-app purchases for tipping creators or buying premium badges using StoreKit 2.
@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    @Published var availableProducts: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    
    private var updatesTask: Task<Void, Never>?
    
    // Replace with your actual bundle IDs
    private let productIdentifiers: Set<String> = [
        "com.mychannel.tip.tier1",
        "com.mychannel.tip.tier2",
        "com.mychannel.superchat"
    ]
    
    private init() {
        updatesTask = listenForTransactions()
        Task {
            await fetchProducts()
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updatesTask?.cancel()
    }
    
    /// Fetches the products from the App Store.
    func fetchProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIdentifiers)
            self.availableProducts = storeProducts.sorted(by: { $0.price < $1.price })
            print("💰 [StoreKitManager] Fetched \(storeProducts.count) products.")
        } catch {
            print("⚠️ [StoreKitManager] Failed product fetch: \(error)")
        }
    }
    
    /// Purchases a specific product.
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateCustomerProductStatus()
            
            // 🔥 YOUTUBE PARITY: Trigger a Super Chat / Gamification Event
            print("🎉 [StoreKitManager] Purchased: \(product.displayName)")
            return transaction
            
        case .userCancelled, .pending:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.updateCustomerProductStatus()
                } catch {
                    print("⚠️ [StoreKitManager] Transaction failed verification")
                }
            }
        }
    }
    
    private func updateCustomerProductStatus() async {
        var purchased: Set<String> = []
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchased.insert(transaction.productID)
            } catch {
                print("⚠️ [StoreKitManager] Failed to verify entitlement")
            }
        }
        self.purchasedProductIDs = purchased
    }
    
    nonisolated private func checkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    enum StoreError: Error {
        case failedVerification
    }
}
