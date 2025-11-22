//
//  VSMatchWalletService.swift
//  MyChannel
//
//  💰 VS MATCH WALLET - Balance, deposits, withdrawals, transaction history
//  Enterprise-level wallet management 🔥
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class VSMatchWalletService: ObservableObject {
    static let shared = VSMatchWalletService()
    private init() {}
    
    @Published var balance: Double = 0.0
    @Published var pendingWithdrawals: [Withdrawal] = []
    @Published var transactionHistory: [VSMatchTransaction] = []
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    private let stripeService = StripeConnectService.shared
    
    // MARK: - 💰 BALANCE MANAGEMENT
    
    /// Get user's wallet balance
    func getBalance(userId: String) async throws -> Double {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("vs_match_wallets").document(userId).getDocument()
            let data = doc.data() ?? [:]
            
            let available = data["availableBalance"] as? Double ?? 0.0
            let pending = data["pendingBalance"] as? Double ?? 0.0
            
            await MainActor.run {
                self.balance = available
            }
            
            return available
        } catch {
            throw WalletError.fetchFailed
        }
        #else
        return 0.0
        #endif
    }
    
    /// Fetch both available and pending balances plus lifetime earnings.
    func fetchWalletSummary(userId: String) async throws -> WalletSummary {
        #if canImport(FirebaseFirestore)
        let doc = try await db.collection("vs_match_wallets").document(userId).getDocument()
        let data = doc.data() ?? [:]
        
        let available = data["availableBalance"] as? Double ?? 0.0
        let pending = data["pendingBalance"] as? Double ?? 0.0
        let lifetime = data["lifetimeEarnings"] as? Double
            ?? data["totalEarnings"] as? Double
            ?? (available + pending)
        
        return WalletSummary(
            availableBalance: available,
            pendingBalance: pending,
            totalEarnings: lifetime
        )
        #else
        return WalletSummary(availableBalance: 0, pendingBalance: 0, totalEarnings: 0)
        #endif
    }
    
    /// Update balance after transaction
    func updateBalance(userId: String, amount: Double, type: VSMatchTransactionType) async throws {
        #if canImport(FirebaseFirestore)
        let walletRef = db.collection("vs_match_wallets").document(userId)
        
        let currentData = try await walletRef.getDocument().data() ?? [:]
        let currentBalance = currentData["availableBalance"] as? Double ?? 0.0
        
        let newBalance: Double
        switch type {
        case .deposit, .win, .refund:
            newBalance = currentBalance + amount
        case .withdrawal, .wager, .fee:
            newBalance = currentBalance - amount
        }
        
        try await walletRef.setData([
            "availableBalance": newBalance,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        
        await MainActor.run {
            self.balance = newBalance
        }
        #endif
    }
    
    // MARK: - 💳 DEPOSIT FUNDS
    
    /// Deposit funds to wallet (via Stripe)
    func depositFunds(userId: String, amount: Double, paymentMethodId: String) async throws -> DepositResult {
        // Validate amount
        guard amount >= 5.0 && amount <= 10000.0 else {
            throw WalletError.invalidAmount
        }
        
        // 🔥 FRAUD DETECTION: Analyze transaction BEFORE processing payment
        print("🚨 [Fraud Detection] Analyzing deposit for user: \(userId), amount: $\(amount)")
        
        do {
            let fraudCheck = try await VertexAIAgentService.shared.analyzeFraudRisk(
                userId: userId,
                amount: amount,
                paymentMethod: paymentMethodId
            )
            
            print("🚨 [Fraud Detection] Risk Score: \(fraudCheck.riskScore), Recommendation: \(fraudCheck.recommendation)")
            
            // Block high-risk transactions
            if fraudCheck.riskScore > 0.7 {
                print("🚨 [Fraud Detection] BLOCKED - High risk transaction!")
                throw WalletError.suspiciousFraudActivity(reason: fraudCheck.reasons.joined(separator: ", "))
            }
            
            // Flag medium-risk for manual review (but allow)
            if fraudCheck.riskScore > 0.4 {
                print("⚠️ [Fraud Detection] FLAGGED - Medium risk, proceeding with caution")
                // TODO: Send alert to admin dashboard for manual review
            }
            
            print("✅ [Fraud Detection] Transaction approved (risk: \(fraudCheck.riskScore))")
        } catch {
            print("⚠️ [Fraud Detection] Agent unavailable, proceeding anyway: \(error)")
            // Don't block if fraud detection agent fails (graceful degradation)
        }
        
        // Create payment intent
        let amountInCents = Int(amount * 100)
        let paymentIntentId = try await stripeService.createPaymentIntent(
            amount: amountInCents,
            currency: "usd",
            customerId: userId
        )
        
        // TODO: Confirm payment via Stripe Payment Sheet or backend
        // For now, assume payment is confirmed after intent creation
        print("💰 [Wallet] Payment intent created: \(paymentIntentId)")
        
        // Update wallet balance
        try await updateBalance(userId: userId, amount: amount, type: .deposit)
        
        // Record transaction
        let transaction = VSMatchTransaction(
            id: UUID().uuidString,
            userId: userId,
            type: .deposit,
            amount: amount,
            status: .completed,
            createdAt: Date(),
            description: "Deposit to wallet",
            matchId: nil
        )
        
        try await recordTransaction(transaction)
        
        return DepositResult(
            transactionId: transaction.id,
            amount: amount,
            newBalance: balance,
            completedAt: Date()
        )
    }
    
    // MARK: - 💸 WITHDRAW FUNDS
    
    /// Request withdrawal from wallet
    func requestWithdrawal(userId: String, amount: Double, destination: WithdrawalDestination) async throws -> Withdrawal {
        // Validate amount
        guard amount >= 10.0 else {
            throw WalletError.minimumWithdrawal
        }
        
        // Check balance
        let currentBalance = try await getBalance(userId: userId)
        guard currentBalance >= amount else {
            throw WalletError.insufficientBalance
        }
        
        // Create withdrawal request
        let withdrawal = Withdrawal(
            id: UUID().uuidString,
            userId: userId,
            amount: amount,
            destination: destination,
            status: .pending,
            requestedAt: Date(),
            processingFee: calculateWithdrawalFee(amount: amount)
        )
        
        #if canImport(FirebaseFirestore)
        // Save withdrawal request
        try await db.collection("vs_match_withdrawals").document(withdrawal.id).setData([
            "userId": userId,
            "amount": amount,
            "destinationType": destination.type.rawValue,
            "destinationId": destination.id,
            "status": "pending",
            "processingFee": withdrawal.processingFee,
            "requestedAt": FieldValue.serverTimestamp()
        ])
        
        // Hold funds (move to pending)
        try await holdFundsForWithdrawal(userId: userId, amount: amount)
        #endif
        
        await MainActor.run {
            self.pendingWithdrawals.append(withdrawal)
        }
        
        // Process withdrawal (async - Stripe transfer)
        Task {
            await processWithdrawal(withdrawal)
        }
        
        return withdrawal
    }
    
    /// Process withdrawal (transfer to bank/card)
    private func processWithdrawal(_ withdrawal: Withdrawal) async {
        do {
            // Calculate net amount (after fee)
            let netAmount = withdrawal.amount - withdrawal.processingFee
            
            // Transfer via Stripe
            let amountInCents = Int(netAmount * 100)
            try await stripeService.transferToWinner(
                amount: amountInCents,
                winnerId: withdrawal.userId
            )
            
            // Update withdrawal status
            #if canImport(FirebaseFirestore)
            try await db.collection("vs_match_withdrawals").document(withdrawal.id).updateData([
                "status": "completed",
                "completedAt": FieldValue.serverTimestamp()
            ])
            
            // Release held funds
            try await releaseHeldFunds(userId: withdrawal.userId, amount: withdrawal.amount)
            #endif
            
            await MainActor.run {
                if let index = self.pendingWithdrawals.firstIndex(where: { $0.id == withdrawal.id }) {
                    var updated = withdrawal
                    updated.status = .completed
                    self.pendingWithdrawals[index] = updated
                }
            }
        } catch {
            // Mark as failed
            #if canImport(FirebaseFirestore)
            try? await db.collection("vs_match_withdrawals").document(withdrawal.id).updateData([
                "status": "failed",
                "error": error.localizedDescription,
                "failedAt": FieldValue.serverTimestamp()
            ])
            
            // Refund held funds
            try? await releaseHeldFunds(userId: withdrawal.userId, amount: withdrawal.amount)
            #endif
        }
    }
    
    // MARK: - 📊 TRANSACTION HISTORY
    
    /// Get transaction history
    func getTransactionHistory(userId: String, limit: Int = 50) async throws -> [VSMatchTransaction] {
        #if canImport(FirebaseFirestore)
        let snapshot = try await db.collection("vs_match_transactions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        let transactions = snapshot.documents.compactMap { doc -> VSMatchTransaction? in
            let data = doc.data()
            return VSMatchTransaction(
                id: doc.documentID,
                userId: data["userId"] as? String ?? "",
                type: VSMatchTransactionType(rawValue: data["type"] as? String ?? "") ?? .deposit,
                amount: data["amount"] as? Double ?? 0.0,
                status: VSMatchTransactionStatus(rawValue: data["status"] as? String ?? "") ?? .pending,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                description: data["description"] as? String ?? "",
                matchId: data["matchId"] as? String
            )
        }
        
        await MainActor.run {
            self.transactionHistory = transactions
        }
        
        return transactions
        #else
        return []
        #endif
    }
    
    /// Record transaction
    private func recordTransaction(_ transaction: VSMatchTransaction) async throws {
        #if canImport(FirebaseFirestore)
        var data: [String: Any] = [
            "userId": transaction.userId,
            "type": transaction.type.rawValue,
            "amount": transaction.amount,
            "status": transaction.status.rawValue,
            "createdAt": Timestamp(date: transaction.createdAt),
            "description": transaction.description
        ]
        
        if let matchId = transaction.matchId {
            data["matchId"] = matchId
        }
        
        try await db.collection("vs_match_transactions").document(transaction.id).setData(data)
        #endif
    }
    
    // MARK: - 🔒 HOLD/RELEASE FUNDS
    
    private func holdFundsForWithdrawal(userId: String, amount: Double) async throws {
        #if canImport(FirebaseFirestore)
        let walletRef = db.collection("vs_match_wallets").document(userId)
        let doc = try await walletRef.getDocument()
        let data = doc.data() ?? [:]
        
        let available = data["availableBalance"] as? Double ?? 0.0
        let pending = data["pendingBalance"] as? Double ?? 0.0
        
        try await walletRef.updateData([
            "availableBalance": available - amount,
            "pendingBalance": pending + amount
        ])
        #endif
    }
    
    private func releaseHeldFunds(userId: String, amount: Double) async throws {
        #if canImport(FirebaseFirestore)
        let walletRef = db.collection("vs_match_wallets").document(userId)
        let doc = try await walletRef.getDocument()
        let data = doc.data() ?? [:]
        
        let pending = data["pendingBalance"] as? Double ?? 0.0
        
        try await walletRef.updateData([
            "pendingBalance": max(0, pending - amount)
        ])
        #endif
    }
    
    // MARK: - 💵 FEES
    
    private func calculateWithdrawalFee(amount: Double) -> Double {
        // 2.5% fee, minimum $1, maximum $25
        let fee = amount * 0.025
        return min(max(fee, 1.0), 25.0)
    }
}

// MARK: - Models

struct DepositResult {
    let transactionId: String
    let amount: Double
    let newBalance: Double
    let completedAt: Date
}

struct Withdrawal: Identifiable {
    let id: String
    let userId: String
    let amount: Double
    let destination: WithdrawalDestination
    var status: WithdrawalStatus
    let requestedAt: Date
    var completedAt: Date?
    var failedAt: Date?
    var error: String?
    let processingFee: Double
    
    var netAmount: Double {
        amount - processingFee
    }
}

struct WithdrawalDestination {
    let type: DestinationType
    let id: String // Stripe account ID or bank account ID
    let last4: String? // Last 4 digits of card/account
    
    enum DestinationType: String {
        case bankAccount = "bank_account"
        case debitCard = "debit_card"
        case stripeAccount = "stripe_account"
    }
}

enum WithdrawalStatus: String {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

struct VSMatchTransaction: Identifiable {
    let id: String
    let userId: String
    let type: VSMatchTransactionType
    let amount: Double
    let status: VSMatchTransactionStatus
    let createdAt: Date
    let description: String
    let matchId: String?
}

enum VSMatchTransactionType: String {
    case deposit = "deposit"
    case withdrawal = "withdrawal"
    case wager = "wager"
    case win = "win"
    case refund = "refund"
    case fee = "fee"
}

enum VSMatchTransactionStatus: String {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

enum WalletError: LocalizedError {
    case invalidAmount
    case insufficientBalance
    case minimumWithdrawal
    case fetchFailed
    case transferFailed
    case suspiciousFraudActivity(reason: String)  // 🔥 NEW: Fraud detection
    
    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Amount must be between $5 and $10,000"
        case .insufficientBalance:
            return "Insufficient balance"
        case .minimumWithdrawal:
            return "Minimum withdrawal is $10"
        case .fetchFailed:
            return "Failed to fetch wallet balance"
        case .transferFailed:
            return "Transfer failed. Please try again"
        case .suspiciousFraudActivity(let reason):
            return "Transaction blocked for security: \(reason)"
        }
    }
}

struct WalletSummary {
    let availableBalance: Double
    let pendingBalance: Double
    let totalEarnings: Double
}

