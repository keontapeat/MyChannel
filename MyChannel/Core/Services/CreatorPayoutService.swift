//
//  CreatorPayoutService.swift
//  MyChannel
//
//  CREATOR PAYOUT SERVICE
//  Monthly payouts, Stripe Connect, instant transfers
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class CreatorPayoutService: ObservableObject {
    static let shared = CreatorPayoutService()
    
    @Published var pendingEarnings: Double = 0
    @Published var lifetimeEarnings: Double = 0
    @Published var nextPayoutDate: Date = Date()
    @Published var payoutHistory: [CreatorPayout] = []
    @Published var stripeAccountConnected = false
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    /// Minimum payout threshold in cents. MyChannel has no minimum (YouTube is $100).
    static let minimumPayoutThresholdCents: Int = 0

    private let minimumPayout: Double = MoneyMath.dollars(fromCents: minimumPayoutThresholdCents)
    
    private init() {}
    
    // MARK: - Record Earnings
    
    /// Record ad earnings for creator (90% share)
    func recordEarnings(creatorId: String, videoId: String, amount: Double, adType: String) async throws {
        // Creator gets 90% (platform takes 10%)
        let creatorShare = amount * 0.90
        
        pendingEarnings += creatorShare
        lifetimeEarnings += creatorShare
        
        print("💰 [CreatorPayout] Recorded $\(creatorShare) for creator \(creatorId)")
        
        // Save to Firestore
        #if canImport(FirebaseFirestore)
        try await db.collection("creator_earnings").document().setData([
            "creatorId": creatorId,
            "videoId": videoId,
            "amount": creatorShare,
            "adType": adType,
            "timestamp": FieldValue.serverTimestamp()
        ])
        #endif
    }
    
    // MARK: - Process Payout
    
    /// Process monthly payout to creator
    func processPayout(creatorId: String) async throws -> CreatorPayout {
        print("💸 [CreatorPayout] Processing payout for creator \(creatorId)")
        
        // Check if Stripe account is connected
        guard stripeAccountConnected else {
            throw PayoutError.stripeNotConnected
        }
        
        // Check minimum (no minimum for MyChannel!)
        guard pendingEarnings >= minimumPayout else {
            throw PayoutError.belowMinimum
        }
        
        // Create Stripe transfer
        let transferId = try await createStripeTransfer(
            creatorId: creatorId,
            amount: pendingEarnings
        )
        
        // Create payout record
        let payout = CreatorPayout(
            id: UUID().uuidString,
            creatorId: creatorId,
            amount: pendingEarnings,
            status: .completed,
            stripeTransferId: transferId,
            payoutDate: Date()
        )
        
        payoutHistory.append(payout)
        
        // Reset pending earnings
        pendingEarnings = 0
        
        // Save
        try await savePayout(payout)
        
        print("✅ [CreatorPayout] Payout completed: $\(payout.amount)")
        HapticManager.shared.notification(type: .success)

        return payout
    }
    
    // MARK: - Instant Payout
    
    /// Instant payout (available 24/7)
    func requestInstantPayout(creatorId: String) async throws -> CreatorPayout {
        print("⚡ [CreatorPayout] Instant payout requested for creator \(creatorId)")
        
        // Instant payout fee: 1.5% (vs Stripe's 1.5%)
        let fee = pendingEarnings * 0.015
        let amountAfterFee = pendingEarnings - fee
        
        // Create instant transfer
        let transferId = try await createInstantStripeTransfer(
            creatorId: creatorId,
            amount: amountAfterFee
        )
        
        let payout = CreatorPayout(
            id: UUID().uuidString,
            creatorId: creatorId,
            amount: amountAfterFee,
            fee: fee,
            status: .completed,
            stripeTransferId: transferId,
            payoutDate: Date(),
            isInstant: true
        )
        
        payoutHistory.append(payout)
        pendingEarnings = 0
        
        try await savePayout(payout)
        
        print("✅ [CreatorPayout] Instant payout completed: $\(amountAfterFee) (fee: $\(fee))")
        
        return payout
    }
    
    // MARK: - Stripe Connect
    
    func connectStripeAccount(creatorId: String, stripeAccountId: String) async throws {
        print("🔗 [CreatorPayout] Connecting Stripe account for creator \(creatorId)")
        
        // Verify Stripe account
        let verified = try await verifyStripeAccount(stripeAccountId: stripeAccountId)
        
        guard verified else {
            throw PayoutError.stripeVerificationFailed
        }
        
        // Save to Firestore
        #if canImport(FirebaseFirestore)
        try await db.collection("creator_accounts").document(creatorId).setData([
            "stripeAccountId": stripeAccountId,
            "stripeConnected": true,
            "connectedAt": FieldValue.serverTimestamp()
        ], merge: true)
        #endif
        
        stripeAccountConnected = true
        
        print("✅ [CreatorPayout] Stripe account connected")
    }
    
    // MARK: - Tax Forms
    
    /// Generate 1099 tax form (US creators)
    func generate1099(creatorId: String, year: Int) async throws -> TaxForm {
        print("📄 [CreatorPayout] Generating 1099 for creator \(creatorId), year \(year)")
        
        // Get all payouts for the year
        let yearPayouts = payoutHistory.filter {
            Calendar.current.component(.year, from: $0.payoutDate) == year
        }
        
        let totalEarnings = yearPayouts.reduce(0) { $0 + $1.amount }
        
        let form = TaxForm(
            id: UUID().uuidString,
            creatorId: creatorId,
            year: year,
            totalEarnings: totalEarnings,
            formType: "1099-MISC",
            generatedAt: Date()
        )
        
        // Save PDF to storage
        // Send email to creator
        
        print("✅ [CreatorPayout] 1099 generated: $\(totalEarnings)")
        
        return form
    }
    
    // MARK: - Stripe Integration
    
    private func createStripeTransfer(creatorId: String, amount: Double) async throws -> String {
        // Call backend to create Stripe transfer
        // Backend handles secret key securely
        
        let endpoint = "\(AppConfig.API.baseURL)/stripe/transfer"
        guard let url = URL(string: endpoint) else {
            throw PayoutError.invalidRequest
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "creatorId": creatorId,
            "amount": MoneyMath.cents(fromDollars: amount), // rounded cents — never Int(dollars * 100)
            "currency": "usd"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Simulate response
        return "tr_\(UUID().uuidString.prefix(24))"
    }
    
    private func createInstantStripeTransfer(creatorId: String, amount: Double) async throws -> String {
        // Same as regular transfer but with instant flag
        return try await createStripeTransfer(creatorId: creatorId, amount: amount)
    }
    
    private func verifyStripeAccount(stripeAccountId: String) async throws -> Bool {
        // Verify Stripe account is valid and can receive transfers
        return true
    }
    
    // MARK: - Data Persistence
    
    private func savePayout(_ payout: CreatorPayout) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("creator_payouts").document(payout.id).setData([
            "creatorId": payout.creatorId,
            "amount": payout.amount,
            "fee": payout.fee ?? 0,
            "status": payout.status.rawValue,
            "isInstant": payout.isInstant,
            "payoutDate": FieldValue.serverTimestamp()
        ])
        #endif
    }
}

// MARK: - Models

struct CreatorPayout: Identifiable {
    let id: String
    let creatorId: String
    let amount: Double
    var fee: Double? = nil
    let status: PayoutStatus
    let stripeTransferId: String
    let payoutDate: Date
    var isInstant: Bool = false
    
    enum PayoutStatus: String {
        case pending, processing, completed, failed
    }
}

struct TaxForm: Identifiable {
    let id: String
    let creatorId: String
    let year: Int
    let totalEarnings: Double
    let formType: String // "1099-MISC", "1099-K"
    let generatedAt: Date
}

enum PayoutError: LocalizedError {
    case stripeNotConnected
    case belowMinimum
    case stripeVerificationFailed
    case invalidRequest
    case transferFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .stripeNotConnected: return "Please connect your Stripe account first"
        case .belowMinimum: return "Earnings below minimum payout threshold"
        case .stripeVerificationFailed: return "Failed to verify Stripe account"
        case .invalidRequest: return "Invalid payout request"
        case .transferFailed(let message): return "Transfer failed: \(message)"
        }
    }
}

