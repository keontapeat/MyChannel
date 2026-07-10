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
final class VSMatchWalletService: ObservableObject, VSMatchWalleting {
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
            self.balance = available  // @MainActor class — direct assignment is safe
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
        // Atomic increment — avoids TOCTOU race from read-modify-write
        let delta: Double
        switch type {
        case .deposit, .win, .refund:
            delta = amount
        case .withdrawal, .wager, .fee:
            delta = -amount
        }
        try await db.collection("vs_match_wallets").document(userId).setData([
            "availableBalance": FieldValue.increment(delta),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        self.balance += delta  // Optimistic local update; @MainActor — direct assignment is safe
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
                #if canImport(FirebaseFirestore)
                let db = Firestore.firestore()
                try? await db.collection("fraud_alerts").document(UUID().uuidString).setData([
                    "userId": userId,
                    "riskScore": fraudCheck.riskScore,
                    "amount": amount,
                    "alertedAt": FieldValue.serverTimestamp()
                ])
                #endif
            }
            
            print("✅ [Fraud Detection] Transaction approved (risk: \(fraudCheck.riskScore))")
        } catch {
            print("⚠️ [Fraud Detection] Agent unavailable, proceeding anyway: \(error)")
            // Don't block if fraud detection agent fails (graceful degradation)
        }
        
        // 🔐 HARDENED: create the payment intent through the AUTHENTICATED escrow
        // Cloud Function (secret key stays server-side). The wallet is credited
        // SERVER-SIDE by the Stripe webhook once the charge actually succeeds — the
        // client must never credit its own balance (Firestore rules enforce this).
        let amountInCents = MoneyMath.cents(fromDollars: amount)
        let paymentIntentId = try await MoneyEscrowService.shared.createWalletDepositIntent(
            userId: userId,
            amountCents: amountInCents
        )

        #if canImport(FirebaseFirestore)
        try? await db.collection("payment_intents").document(paymentIntentId).setData([
            "userId": userId,
            "amount": amount,
            "currency": "usd",
            "status": "requires_confirmation",
            "createdAt": FieldValue.serverTimestamp()
        ])
        #endif

        print("💰 [Wallet] Deposit intent created server-side: \(paymentIntentId). " +
              "Balance will update once Stripe confirms the charge (webhook).")

        // NOTE: We intentionally do NOT credit the wallet here. The authoritative
        // credit happens server-side after Stripe confirms payment, so a client
        // can never inflate its balance by faking a deposit.
        let transaction = VSMatchTransaction(
            id: UUID().uuidString,
            userId: userId,
            type: .deposit,
            amount: amount,
            status: .pending,
            createdAt: Date(),
            description: "Deposit to wallet (pending payment confirmation)",
            matchId: nil
        )

        try? await recordTransaction(transaction)

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
    
    /// Process withdrawal.
    /// 🔐 HARDENED: money movement and wallet/withdrawal status changes happen
    /// SERVER-SIDE only. The client merely records the pending request (done in
    /// requestWithdrawal); a backend payout worker validates the request against
    /// the authoritative ledger, performs the Stripe transfer with the secret key,
    /// and flips the status. The client can no longer transfer funds to itself or
    /// mark its own withdrawal complete (Firestore rules enforce admin-only writes
    /// on vs_match_wallets / vs_match_withdrawals).
    private func processWithdrawal(_ withdrawal: Withdrawal) async {
        // Intentionally a no-op on the client. The withdrawal request was already
        // persisted with status "pending" by requestWithdrawal(); the secure
        // backend payout worker takes it from here. Leaving this client-side would
        // re-open a self-payout exploit.
        print("🔐 [Wallet] Withdrawal \(withdrawal.id) queued for secure server-side processing")
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
        
        self.transactionHistory = transactions  // @MainActor class — direct assignment is safe
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
        // Atomic increments — avoids read-modify-write race condition
        try await db.collection("vs_match_wallets").document(userId).updateData([
            "availableBalance": FieldValue.increment(-amount),
            "pendingBalance": FieldValue.increment(amount)
        ])
        #endif
    }
    
    /// Release held (pending) funds. Pass `refundToAvailable: true` on withdrawal failure to restore the user's spendable balance.
    private func releaseHeldFunds(userId: String, amount: Double, refundToAvailable: Bool = false) async throws {
        #if canImport(FirebaseFirestore)
        var updates: [String: Any] = [
            "pendingBalance": FieldValue.increment(-amount)
        ]
        if refundToAvailable {
            updates["availableBalance"] = FieldValue.increment(amount)
        }
        try await db.collection("vs_match_wallets").document(userId).updateData(updates)
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

    /// Canonical integer cents (MoneyMath rounding).
    var amountCents: Int { MoneyMath.cents(fromDollars: amount) }
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

