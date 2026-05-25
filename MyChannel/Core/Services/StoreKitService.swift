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
    static let plusSubscriptionIDs: Set<String> = [
        "com.mychannel.plus.monthly",
        "com.mychannel.plus.annual"
    ]
    
    static var allSubscriptionIDs: Set<String> {
        plusSubscriptionIDs
    }
    
    // MARK: - Transaction listener task (keeps running for the app's lifetime)
    private var transactionListenerTask: Task<Void, Never>?
    
    // MARK: - Unified Premium Status
    /// True when user has ANY active MyChannel Plus+ subscription
    var isPremium: Bool {
        !purchasedProductIDs.isEmpty
    }
    
    /// True when user has a Plus+ subscription (ad-free, downloads, background play)
    var isPlusSubscriber: Bool {
        !purchasedProductIDs.isDisjoint(with: Self.plusSubscriptionIDs)
    }
    
    /// Active subscription product ID (for display purposes)
    var activeSubscriptionProductID: String? {
        purchasedProductIDs.first
    }
    
    private init() {
        // 🔥 FIX 2.1(b): Don't start StoreKit when subscriptions are disabled
        guard AppConfig.Features.enableSubscriptions else { return }
        
        // Start listening for StoreKit transactions immediately
        transactionListenerTask = listenForTransactions()
        
        // Refresh entitlements on launch
        Task {
            await refreshEntitlements()
        }
    }
    
    deinit {
        transactionListenerTask?.cancel()
    }
    
    // MARK: - 🔄 Transaction Listener (YouTube Premium Parity)
    // Catches: renewals, family sharing grants/revocations, promo codes,
    // offer redemptions, refunds, and purchases made on other devices.
    
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }
                await self.handleTransactionResult(result)
            }
        }
    }
    
    private func handleTransactionResult(_ result: StoreKit.VerificationResult<StoreKit.Transaction>) async {
        switch result {
        case .verified(let transaction):
            print("✅ [StoreKit] Verified transaction: \(transaction.productID)")
            // Always finish verified transactions
            await transaction.finish()
            // Refresh entitlements & sync to Firestore
            await refreshEntitlements()
            
        case .unverified(let transaction, let error):
            print("⚠️ [StoreKit] Unverified transaction \(transaction.productID): \(error)")
            // Do NOT grant access for unverified transactions
        }
    }
    
    // MARK: - 🔃 Entitlement Refresh
    
    /// Refresh purchased product IDs from StoreKit and sync to Firestore + services
    func refreshEntitlements() async {
        var activeIDs = Set<String>()
        
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let tx) = result {
                // Only count non-revoked, non-expired subscriptions
                let isRevoked = tx.revocationDate != nil
                let isExpired: Bool = {
                    if let expiry = tx.expirationDate {
                        return expiry < Date()
                    }
                    return false // Non-expiring (lifetime) products
                }()
                
                if !isRevoked && !isExpired {
                    activeIDs.insert(tx.productID)
                }
            }
        }
        
        let previousIDs = purchasedProductIDs
        purchasedProductIDs = activeIDs
        
        let becamePremium = previousIDs.isEmpty && !activeIDs.isEmpty
        let lostPremium = !previousIDs.isEmpty && activeIDs.isEmpty
        
        // Sync Firestore whenever status changes
        if becamePremium || lostPremium || previousIDs != activeIDs {
            await syncSubscriptionToFirestore(isActive: !activeIDs.isEmpty)
        }
        
        print("👑 [StoreKit] Entitlements refreshed — isPremium: \(isPremium), ids: \(activeIDs)")
    }
    
    // MARK: - 🔥 Firestore Sync
    
    private func syncSubscriptionToFirestore(isActive: Bool) async {
        if isActive {
            try? await SubscriptionService.shared.activatePlusSubscription()
        } else {
            try? await SubscriptionService.shared.cancelSubscription()
        }
    }
    
    // MARK: - 📦 Load Products
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let storeProducts = try await Product.products(for: Self.allSubscriptionIDs)
            self.products = storeProducts.sorted(by: { $0.price < $1.price })
            print("🛍️ [StoreKit] Loaded \(storeProducts.count) products")
        } catch {
            lastError = error.localizedDescription
            print("⚠️ [StoreKit] Failed to load products: \(error)")
        }
    }
    
    // MARK: - 💰 Purchase Methods
    
    /// Purchase a StoreKit Product directly
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    print("✅ [StoreKit] Purchase verified: \(transaction.productID)")
                    await transaction.finish()
                    await refreshEntitlements()
                    return true
                case .unverified(_, let error):
                    print("⚠️ [StoreKit] Purchase unverified: \(error)")
                    lastError = MCStoreKitError.verificationFailed.localizedDescription
                    return false
                }
            case .userCancelled:
                print("🚫 [StoreKit] User cancelled purchase")
                return false
            case .pending:
                print("⏳ [StoreKit] Purchase pending (Ask to Buy, etc.)")
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            print("❌ [StoreKit] Purchase error: \(error)")
            return false
        }
    }
    
    /// Purchase using SubscriptionPlan enum
    func purchase(plan: SubscriptionPlan) async throws -> Bool {
        #if DEBUG && targetEnvironment(simulator)
        print("🛍️ [StoreKit] SIMULATOR: Simulating purchase for \(plan.displayName)")
        try await Task.sleep(nanoseconds: 500_000_000)
        // Simulate Firestore activation on simulator
        try await SubscriptionService.shared.activatePlusSubscription()
        return true
        #else
        if products.isEmpty {
            await loadProducts()
        }
        
        guard let product = products.first(where: { $0.id == plan.productID }) else {
            throw MCStoreKitError.productNotFound
        }
        
        return await purchase(product)
        #endif
    }
    
    // MARK: - ♻️ Restore Purchases
    
    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            print("✅ [StoreKit] Purchases restored")
        } catch {
            lastError = error.localizedDescription
            print("⚠️ [StoreKit] Restore failed: \(error)")
        }
    }
    
    // MARK: - ✅ Quick Premium Check (async, reads StoreKit directly)
    
    func hasActiveSubscription() async -> Bool {
        // Fast path: check cached state first
        if isPremium { return true }
        
        // Slow path: re-check StoreKit entitlements
        await refreshEntitlements()
        return isPremium
    }
    
    // MARK: - 📊 Subscription Details
    
    /// Returns the expiration date of the current subscription (if any)
    func currentSubscriptionExpiry() async -> Date? {
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               Self.allSubscriptionIDs.contains(tx.productID),
               tx.revocationDate == nil {
                return tx.expirationDate
            }
        }
        return nil
    }
    
    /// Returns the display product for the current active subscription
    func activeProduct() -> Product? {
        guard let activeID = purchasedProductIDs.first else { return nil }
        return products.first(where: { $0.id == activeID })
    }
}

// MARK: - Errors

enum MCStoreKitError: LocalizedError {
    case productNotFound
    case purchaseFailed
    case verificationFailed
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Subscription products are not available yet. Please try again later."
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        case .verificationFailed:
            return "Could not verify purchase. Please contact support."
        }
    }
}



