//
//  TipStoreKitService.swift
//  MyChannel
//
//  Apple IAP-compliant tipping system (Guideline 3.1.1).
//  Viewers purchase tip credits via IAP, then send them to creators.
//  Platform takes 30% (Apple) + 10% (MyChannel) = 40% total; creator gets 60%.
//

import Foundation
import StoreKit
import Combine

// MARK: - Tip Product IDs (configure these in App Store Connect)

enum TipProductID: String, CaseIterable {
    case tip1 = "com.mychannel.tip.1"      // $0.99 → 1 credit
    case tip5 = "com.mychannel.tip.5"      // $4.99 → 5 credits
    case tip10 = "com.mychannel.tip.10"    // $9.99 → 10 credits
    case tip20 = "com.mychannel.tip.20"    // $19.99 → 20 credits
    case tip50 = "com.mychannel.tip.50"    // $49.99 → 50 credits
    case tip100 = "com.mychannel.tip.100"  // $99.99 → 100 credits
    
    var credits: Int {
        switch self {
        case .tip1: return 1
        case .tip5: return 5
        case .tip10: return 10
        case .tip20: return 20
        case .tip50: return 50
        case .tip100: return 100
        }
    }
}

// MARK: - Tip Store Service

@MainActor
final class TipStoreKitService: NSObject, ObservableObject {
    static let shared = TipStoreKitService()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var updateListenerTask: Task<Void, Error>?
    
    private override init() {
        super.init()
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let productIDs = TipProductID.allCases.map { $0.rawValue }
            let loadedProducts = try await Product.products(for: productIDs)
            self.products = loadedProducts.sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Could not load tip products: \(error.localizedDescription)"
            print("⚠️ [TipStore] Product load failed: \(error)")
        }
    }
    
    // MARK: - Purchase Flow
    
    func purchase(_ product: Product, for creatorId: String, message: String? = nil) async throws -> StoreKit.Transaction {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Send tip to backend (credits the creator's ledger)
            try await sendTipToBackend(
                transaction: transaction,
                creatorId: creatorId,
                message: message
            )
            
            // Finish the transaction
            await transaction.finish()
            
            await updatePurchasedProducts()
            return transaction
            
        case .userCancelled:
            throw TipStoreError.userCancelled
            
        case .pending:
            throw TipStoreError.purchasePending
            
        @unknown default:
            throw TipStoreError.unknownError
        }
    }
    
    // MARK: - Transaction Verification
    
    private nonisolated func checkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw TipStoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("⚠️ [TipStore] Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            } catch {
                print("⚠️ [TipStore] Failed to verify entitlement: \(error)")
            }
        }
        
        self.purchasedProductIDs = purchased
    }
    
    // MARK: - Backend Integration
    
    private func sendTipToBackend(transaction: StoreKit.Transaction, creatorId: String, message: String?) async throws {
        guard let appState = AppState.shared.currentUser else {
            throw TipStoreError.notSignedIn
        }
        
        // Extract credits from product ID
        guard let productID = TipProductID(rawValue: transaction.productID) else {
            throw TipStoreError.invalidProduct
        }
        let credits = productID.credits
        
        // Apple takes 30%, MyChannel takes 10% of the remaining 70% = 7% total
        // Creator gets 63% of the original purchase price
        let creatorSharePercentage = 0.63
        let amountCents = Int(Double(credits) * 100.0 * creatorSharePercentage)
        
        struct TipRequest: Codable {
            let fromUserId: String
            let toUserId: String
            let amount: Int
            let currency: String
            let message: String?
            let transactionId: String
            let productId: String
            let credits: Int
        }
        
        let request = TipRequest(
            fromUserId: appState.id,
            toUserId: creatorId,
            amount: amountCents,
            currency: "usd",
            message: message,
            transactionId: String(transaction.id),
            productId: transaction.productID,
            credits: credits
        )
        
        let _: MessageResponse = try await NetworkService.shared.post(
            endpoint: .custom("/pay/tip/iap"),
            body: request,
            responseType: MessageResponse.self
        )
        
        print("✅ [TipStore] Tip sent: \(credits) credits → creator \(creatorId)")
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }
}

// MARK: - Errors

enum TipStoreError: LocalizedError {
    case userCancelled
    case purchasePending
    case failedVerification
    case unknownError
    case notSignedIn
    case invalidProduct
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase was cancelled"
        case .purchasePending:
            return "Purchase is pending approval"
        case .failedVerification:
            return "Transaction verification failed"
        case .unknownError:
            return "An unknown error occurred"
        case .notSignedIn:
            return "You must be signed in to send tips"
        case .invalidProduct:
            return "Invalid tip product"
        }
    }
}

// MARK: - Tip Credit Balance (local tracking)

extension TipStoreKitService {
    /// Get the user's current tip credit balance from backend
    func getCreditBalance(userId: String) async throws -> Int {
        struct BalanceResponse: Codable { let credits: Int }
        let response: BalanceResponse = try await NetworkService.shared.get(
            endpoint: .custom("/pay/tip/balance/\(userId)"),
            responseType: BalanceResponse.self
        )
        return response.credits
    }
}
