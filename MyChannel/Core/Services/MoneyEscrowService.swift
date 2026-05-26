//
//  MoneyEscrowService.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  💰 ESCROW SERVICE - Safe money handling for VS Matches
//  Stripe Connect + Instant payouts 🔥
//
//  PRODUCTION READY: Real Stripe integration
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class MoneyEscrowService: ObservableObject {
    static let shared = MoneyEscrowService()
    
    // MARK: - Published State
    @Published var heldFunds: [String: EscrowedFunds] = [:]
    @Published var isProcessing = false
    @Published var lastError: String?
    
    // MARK: - Configuration
    private let platformFeePercent: Double = 0.10 // 10% platform fee
    private let stripeAPIBaseURL = "https://api.stripe.com/v1"
    private let backendAPIBaseURL = "https://us-central1-mychannel-ca26d.cloudfunctions.net"
    
    // MARK: - Database
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
    
    private init() {
        Task {
            await loadPendingEscrows()
        }
    }
    
    // MARK: - 🔒 HOLD FUNDS (Creates Payment Intent)
    
    func holdFunds(userId: String, amount: Double, matchId: String) async throws {
        print("🔒 [Escrow] Holding $\(amount) from user \(userId) for match \(matchId)")
        isProcessing = true
        defer { isProcessing = false }
        
        // 1. Verify user has Stripe customer ID
        guard let stripeCustomerId = await getStripeCustomerId(userId: userId) else {
            throw EscrowError.noPaymentMethod
        }
        
        // 2. Verify user has sufficient balance (via wallet or payment method)
        guard await verifyUserBalance(userId: userId, amount: amount) else {
            throw EscrowError.insufficientFunds
        }
        
        // 3. Create Payment Intent with capture_method=manual (hold funds)
        let paymentIntentId = try await createPaymentIntent(
            customerId: stripeCustomerId,
            amount: amount,
            matchId: matchId
        )
        
        // 4. Create escrow record in Firestore
        let escrow = EscrowedFunds(
            id: UUID().uuidString,
            matchId: matchId,
            userId: userId,
            amount: amount,
            platformFee: amount * platformFeePercent,
            netAmount: amount * (1 - platformFeePercent),
            status: .held,
            stripePaymentIntentId: paymentIntentId,
            heldAt: Date()
        )
        
        #if canImport(FirebaseFirestore)
        try await db.collection("escrow").document(escrow.id).setData([
            "id": escrow.id,
            "matchId": escrow.matchId,
            "userId": escrow.userId,
            "amount": escrow.amount,
            "platformFee": escrow.platformFee,
            "netAmount": escrow.netAmount,
            "status": "held",
            "stripePaymentIntentId": paymentIntentId,
            "heldAt": FieldValue.serverTimestamp()
        ])
        #endif
        
        heldFunds["\(matchId)_\(userId)"] = escrow
        print("✅ [Escrow] Funds held - PaymentIntent: \(paymentIntentId)")
    }
    
    // MARK: - 💸 RELEASE FUNDS TO WINNER
    
    func releaseFunds(matchId: String, winnerId: String, loserId: String, totalPot: Double) async throws {
        print("💸 [Escrow] Releasing $\(totalPot) to winner \(winnerId)")
        isProcessing = true
        defer { isProcessing = false }
        
        // 1. Get escrow records for both players
        let winnerEscrowKey = "\(matchId)_\(winnerId)"
        let loserEscrowKey = "\(matchId)_\(loserId)"
        
        guard let winnerEscrow = heldFunds[winnerEscrowKey],
              let loserEscrow = heldFunds[loserEscrowKey] else {
            throw EscrowError.noFundsHeld
        }
        
        // 2. Capture both payment intents (finalize the holds)
        try await capturePaymentIntent(paymentIntentId: winnerEscrow.stripePaymentIntentId ?? "")
        try await capturePaymentIntent(paymentIntentId: loserEscrow.stripePaymentIntentId ?? "")
        
        // 3. Calculate amounts
        let totalAmount = winnerEscrow.amount + loserEscrow.amount
        let platformFee = totalAmount * platformFeePercent
        let winnerPayout = totalAmount - platformFee
        
        // 4. Get winner's Stripe Connect account ID
        guard let winnerConnectAccountId = await getStripeConnectAccountId(userId: winnerId) else {
            throw EscrowError.noConnectAccount
        }
        
        // 5. Create transfer to winner via Stripe Connect
        try await createTransfer(
            amount: winnerPayout,
            destinationAccountId: winnerConnectAccountId,
            matchId: matchId
        )
        
        // 6. Update escrow records
        #if canImport(FirebaseFirestore)
        let batch = db.batch()
        
        let winnerRef = db.collection("escrow").document(winnerEscrow.id)
        batch.updateData([
            "status": "released",
            "releasedAt": FieldValue.serverTimestamp(),
            "winnerPayout": winnerPayout,
            "platformFee": platformFee
        ], forDocument: winnerRef)
        
        let loserRef = db.collection("escrow").document(loserEscrow.id)
        batch.updateData([
            "status": "released",
            "releasedAt": FieldValue.serverTimestamp()
        ], forDocument: loserRef)
        
        try await batch.commit()
        #endif
        
        // 7. Update local state
        var updatedWinnerEscrow = winnerEscrow
        updatedWinnerEscrow.status = .released
        updatedWinnerEscrow.releasedAt = Date()
        heldFunds[winnerEscrowKey] = updatedWinnerEscrow
        
        var updatedLoserEscrow = loserEscrow
        updatedLoserEscrow.status = .released
        updatedLoserEscrow.releasedAt = Date()
        heldFunds[loserEscrowKey] = updatedLoserEscrow
        
        // 8. Record transaction for audit
        try await recordTransaction(
            type: .winnerPayout,
            matchId: matchId,
            winnerId: winnerId,
            loserId: loserId,
            amount: winnerPayout,
            platformFee: platformFee
        )
        
        print("✅ [Escrow] Winner paid $\(winnerPayout) (after $\(platformFee) platform fee)")
    }
    
    // MARK: - 🔄 REFUND (Match Cancelled)
    
    func refundFunds(matchId: String, userId: String) async throws {
        print("🔄 [Escrow] Refunding funds for match \(matchId), user \(userId)")
        isProcessing = true
        defer { isProcessing = false }
        
        let escrowKey = "\(matchId)_\(userId)"
        guard var escrow = heldFunds[escrowKey] else {
            throw EscrowError.noFundsHeld
        }
        
        // Cancel the payment intent (releases the hold)
        try await cancelPaymentIntent(paymentIntentId: escrow.stripePaymentIntentId ?? "")
        
        // Update Firestore
        #if canImport(FirebaseFirestore)
        try await db.collection("escrow").document(escrow.id).updateData([
            "status": "refunded",
            "releasedAt": FieldValue.serverTimestamp()
        ])
        #endif
        
        escrow.status = .refunded
        escrow.releasedAt = Date()
        heldFunds[escrowKey] = escrow
        
        print("✅ [Escrow] Refund processed - Payment intent cancelled")
    }
    
    // MARK: - 🔥 STRIPE API CALLS
    
    private func createPaymentIntent(customerId: String, amount: Double, matchId: String) async throws -> String {
        let url = URL(string: "\(backendAPIBaseURL)/create-escrow-payment")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "customerId": customerId,
            "amount": Int(amount * 100), // Stripe uses cents
            "matchId": matchId,
            "captureMethod": "manual" // Hold funds, don't capture yet
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.configured.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EscrowError.stripeError("Failed to create payment intent")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let paymentIntentId = json?["paymentIntentId"] as? String else {
            throw EscrowError.stripeError("Invalid response")
        }
        
        return paymentIntentId
    }
    
    private func capturePaymentIntent(paymentIntentId: String) async throws {
        let url = URL(string: "\(backendAPIBaseURL)/capture-payment")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["paymentIntentId": paymentIntentId])
        
        let (_, response) = try await URLSession.configured.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EscrowError.stripeError("Failed to capture payment")
        }
    }
    
    private func cancelPaymentIntent(paymentIntentId: String) async throws {
        let url = URL(string: "\(backendAPIBaseURL)/cancel-payment")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["paymentIntentId": paymentIntentId])
        
        let (_, response) = try await URLSession.configured.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EscrowError.stripeError("Failed to cancel payment")
        }
    }
    
    private func createTransfer(amount: Double, destinationAccountId: String, matchId: String) async throws {
        let url = URL(string: "\(backendAPIBaseURL)/create-transfer")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "amount": Int(amount * 100), // cents
            "destination": destinationAccountId,
            "matchId": matchId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.configured.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EscrowError.stripeError("Failed to transfer to winner")
        }
    }
    
    // MARK: - 📊 HELPER FUNCTIONS
    
    private func getStripeCustomerId(userId: String) async -> String? {
        #if canImport(FirebaseFirestore)
        let doc = try? await db.collection("users").document(userId).getDocument()
        return doc?.data()?["stripeCustomerId"] as? String
        #else
        return nil
        #endif
    }
    
    private func getStripeConnectAccountId(userId: String) async -> String? {
        #if canImport(FirebaseFirestore)
        let doc = try? await db.collection("users").document(userId).getDocument()
        return doc?.data()?["stripeConnectAccountId"] as? String
        #else
        return nil
        #endif
    }
    
    private func verifyUserBalance(userId: String, amount: Double) async -> Bool {
        #if canImport(FirebaseFirestore)
        // Check wallet balance in Firestore
        let walletDoc = try? await db.collection("wallets").document(userId).getDocument()
        let balance = walletDoc?.data()?["availableBalance"] as? Double ?? 0
        return balance >= amount
        #else
        return true
        #endif
    }
    
    private func loadPendingEscrows() async {
        #if canImport(FirebaseFirestore)
        let snapshot = try? await db.collection("escrow")
            .whereField("status", isEqualTo: "held")
            .getDocuments()
        
        for doc in snapshot?.documents ?? [] {
            let data = doc.data()
            let escrow = EscrowedFunds(
                id: data["id"] as? String ?? doc.documentID,
                matchId: data["matchId"] as? String ?? "",
                userId: data["userId"] as? String ?? "",
                amount: data["amount"] as? Double ?? 0,
                platformFee: data["platformFee"] as? Double ?? 0,
                netAmount: data["netAmount"] as? Double ?? 0,
                status: .held,
                stripePaymentIntentId: data["stripePaymentIntentId"] as? String,
                heldAt: (data["heldAt"] as? Timestamp)?.dateValue() ?? Date()
            )
            heldFunds["\(escrow.matchId)_\(escrow.userId)"] = escrow
        }
        #endif
    }
    
    private func recordTransaction(type: TransactionType, matchId: String, winnerId: String, loserId: String, amount: Double, platformFee: Double) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("vs_match_transactions").addDocument(data: [
            "type": type.rawValue,
            "matchId": matchId,
            "winnerId": winnerId,
            "loserId": loserId,
            "amount": amount,
            "platformFee": platformFee,
            "createdAt": FieldValue.serverTimestamp()
        ])
        #endif
    }
    
    // MARK: - 📊 STATISTICS
    
    func getTotalHeldAmount() -> Double {
        heldFunds.values.filter { $0.status == .held }.reduce(0) { $0 + $1.amount }
    }
    
    func getEscrowStats() -> EscrowStatistics {
        let held = heldFunds.values.filter { $0.status == .held }
        let released = heldFunds.values.filter { $0.status == .released }
        let refunded = heldFunds.values.filter { $0.status == .refunded }
        
        return EscrowStatistics(
            totalHeld: held.reduce(0) { $0 + $1.amount },
            totalReleased: released.reduce(0) { $0 + $1.amount },
            totalRefunded: refunded.reduce(0) { $0 + $1.amount },
            activeEscrows: held.count,
            completedEscrows: released.count + refunded.count
        )
    }
    
    private enum TransactionType: String {
        case winnerPayout
        case refund
        case platformFee
    }
}

// MARK: - 📊 Models

struct EscrowedFunds: Identifiable, Codable {
    let id: String
    let matchId: String
    let userId: String
    let amount: Double
    let platformFee: Double
    let netAmount: Double
    var status: EscrowStatus
    let stripePaymentIntentId: String?
    let heldAt: Date
    var releasedAt: Date?
    
    enum EscrowStatus: String, Codable {
        case held
        case released
        case refunded
        case disputed
        case expired
    }
}

struct EscrowStatistics {
    let totalHeld: Double
    let totalReleased: Double
    let totalRefunded: Double
    let activeEscrows: Int
    let completedEscrows: Int
    
    var platformRevenueTotal: Double {
        totalReleased * 0.10 // 10% platform fee
    }
}

enum EscrowError: LocalizedError {
    case insufficientFunds
    case noFundsHeld
    case transferFailed
    case noPaymentMethod
    case noConnectAccount
    case stripeError(String)
    case networkError
    case invalidAmount
    
    var errorDescription: String? {
        switch self {
        case .insufficientFunds:
            return "Insufficient funds in account. Please add funds to your wallet."
        case .noFundsHeld:
            return "No funds found in escrow for this match."
        case .transferFailed:
            return "Transfer failed. Please try again or contact support."
        case .noPaymentMethod:
            return "Please add a payment method to participate in matches."
        case .noConnectAccount:
            return "Please complete your payout setup to receive winnings."
        case .stripeError(let message):
            return "Payment error: \(message)"
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .invalidAmount:
            return "Invalid wager amount. Must be between $1 and $100,000."
        }
    }
}

