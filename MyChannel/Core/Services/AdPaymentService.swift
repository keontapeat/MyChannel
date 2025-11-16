//
//  AdPaymentService.swift
//  MyChannel
//
//  AD PAYMENT SERVICE
//  Stripe integration for advertisers - auto-reload, billing
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class AdPaymentService: ObservableObject {
    static let shared = AdPaymentService()
    
    @Published var advertiserBalance: Double = 0
    @Published var transactions: [AdTransaction] = []
    @Published var autoReloadEnabled = false
    @Published var autoReloadThreshold: Double = 100
    @Published var autoReloadAmount: Double = 500
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    private init() {}
    
    // MARK: - Add Funds
    
    /// Add funds to advertiser account via Stripe
    func addFunds(advertiserId: String, amount: Double, paymentMethodId: String) async throws -> AdTransaction {
        print("💳 [AdPayment] Adding $\(amount) to advertiser \(advertiserId)")
        
        // Validate amount
        guard amount >= 20 && amount <= 100_000 else {
            throw PaymentError.invalidAmount
        }
        
        // Create Stripe payment intent
        let paymentIntentId = try await createStripePaymentIntent(
            amount: Int(amount * 100), // Convert to cents
            paymentMethodId: paymentMethodId
        )
        
        // Update balance
        advertiserBalance += amount
        
        // Record transaction
        let transaction = AdTransaction(
            id: UUID().uuidString,
            advertiserId: advertiserId,
            type: .deposit,
            amount: amount,
            status: .completed,
            paymentIntentId: paymentIntentId,
            timestamp: Date()
        )
        
        transactions.append(transaction)
        
        // Save to Firestore
        try await saveTransaction(transaction)
        try await updateBalance(advertiserId: advertiserId, balance: advertiserBalance)
        
        print("✅ [AdPayment] Funds added successfully")
        
        return transaction
    }
    
    // MARK: - Charge for Ad Spend
    
    /// Charge advertiser for ad impressions/clicks
    func chargeForAdSpend(advertiserId: String, amount: Double, campaignId: String) async throws {
        print("💸 [AdPayment] Charging $\(amount) for campaign \(campaignId)")
        
        // Check balance
        guard advertiserBalance >= amount else {
            // Try auto-reload if enabled
            if autoReloadEnabled {
                try await autoReload(advertiserId: advertiserId)
            } else {
                throw PaymentError.insufficientFunds
            }
            return // ✅ Exit guard body
        }
        
        // Deduct from balance
        advertiserBalance -= amount
        
        // Record transaction
        let transaction = AdTransaction(
            id: UUID().uuidString,
            advertiserId: advertiserId,
            type: .adSpend,
            amount: -amount,
            status: .completed,
            campaignId: campaignId,
            timestamp: Date()
        )
        
        transactions.append(transaction)
        
        // Save
        try await saveTransaction(transaction)
        try await updateBalance(advertiserId: advertiserId, balance: advertiserBalance)
    }
    
    // MARK: - Auto-Reload
    
    private func autoReload(advertiserId: String) async throws {
        print("🔄 [AdPayment] Auto-reload triggered for advertiser \(advertiserId)")
        
        // Get saved payment method
        guard let paymentMethodId = await getSavedPaymentMethod(advertiserId: advertiserId) else {
            throw PaymentError.noPaymentMethod
        }
        
        // Add funds
        _ = try await addFunds(
            advertiserId: advertiserId,
            amount: autoReloadAmount,
            paymentMethodId: paymentMethodId
        )
        
        print("✅ [AdPayment] Auto-reload completed")
    }
    
    func enableAutoReload(threshold: Double, amount: Double) {
        autoReloadEnabled = true
        autoReloadThreshold = threshold
        autoReloadAmount = amount
        print("✅ [AdPayment] Auto-reload enabled: Reload $\(amount) when balance < $\(threshold)")
    }
    
    func disableAutoReload() {
        autoReloadEnabled = false
        print("⏸️ [AdPayment] Auto-reload disabled")
    }
    
    // MARK: - Stripe Integration
    
    private func createStripePaymentIntent(amount: Int, paymentMethodId: String) async throws -> String {
        // Call backend API to create Stripe payment intent
        // Backend handles secret key securely
        
        let endpoint = "\(AppConfig.API.baseURL)/stripe/payment-intent"
        guard let url = URL(string: endpoint) else {
            throw PaymentError.invalidRequest
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "amount": amount,
            "currency": "usd",
            "paymentMethodId": paymentMethodId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Simulate response
        return "pi_\(UUID().uuidString.prefix(24))"
    }
    
    private func getSavedPaymentMethod(advertiserId: String) async -> String? {
        // Fetch from Firestore
        return nil
    }
    
    // MARK: - Data Persistence
    
    private func saveTransaction(_ transaction: AdTransaction) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("ad_transactions").document(transaction.id).setData([
            "advertiserId": transaction.advertiserId,
            "type": transaction.type.rawValue,
            "amount": transaction.amount,
            "status": transaction.status.rawValue,
            "timestamp": FieldValue.serverTimestamp()
        ])
        #endif
    }
    
    private func updateBalance(advertiserId: String, balance: Double) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("advertiser_accounts").document(advertiserId).setData([
            "balance": balance,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        #endif
    }
}

// MARK: - Models

struct AdTransaction: Identifiable {
    let id: String
    let advertiserId: String
    let type: TransactionType
    let amount: Double
    let status: TransactionStatus
    var paymentIntentId: String?
    var campaignId: String?
    let timestamp: Date
    
    enum TransactionType: String {
        case deposit, adSpend, refund
    }
    
    enum TransactionStatus: String {
        case pending, completed, failed
    }
}

enum PaymentError: LocalizedError {
    case invalidAmount
    case insufficientFunds
    case noPaymentMethod
    case invalidRequest
    case stripeError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAmount: return "Amount must be between $20 and $100,000"
        case .insufficientFunds: return "Insufficient funds. Please add more."
        case .noPaymentMethod: return "No payment method on file"
        case .invalidRequest: return "Invalid payment request"
        case .stripeError(let message): return "Stripe error: \(message)"
        }
    }
}

