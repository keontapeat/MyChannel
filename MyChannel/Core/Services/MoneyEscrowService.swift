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
class MoneyEscrowService: ObservableObject, MoneyEscrowing {
    static let shared = MoneyEscrowService()
    
    // MARK: - Published State
    @Published var heldFunds: [String: EscrowedFunds] = [:]
    @Published var isProcessing = false
    @Published var lastError: String?
    
    // MARK: - Configuration
    // Platform fee lives in MoneyMath.platformFeePercent — do not duplicate here.
    // 🔐 Money paths NEVER use AppSecrets AI keys — all Stripe ops go through
    // authenticated Cloud Functions with Firebase ID tokens only.
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
    
    func holdFunds(userId: String, amount: Double, matchId: String, currency: String = EscrowCurrency.usd) async throws {
        try await holdFunds(
            userId: userId,
            amountCents: MoneyMath.cents(fromDollars: amount),
            matchId: matchId,
            currency: currency
        )
    }

    /// Preferred entry: integer cents (canonical). Dollars overload rounds via MoneyMath.
    func holdFunds(userId: String, amountCents: Int, matchId: String, currency: String = EscrowCurrency.usd) async throws {
        try EscrowCurrency.assertUSDOnly(currency)
        guard amountCents > 0 else { throw EscrowError.invalidAmount }
        let amount = MoneyMath.dollars(fromCents: amountCents)
        print("🔒 [Escrow] Holding $\(amount) (\(amountCents)¢) from user \(userId) for match \(matchId)")
        // Crashlytics: tag escrow failures with `money_domain=escrow` via ErrorReportingManager
        // when hold/capture/transfer throws — never attach card or bank PII to custom keys.
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
            amountCents: amountCents,
            matchId: matchId
        )
        
        // 4. Create escrow record in Firestore (dollars + canonical cents)
        let platformFeeCents = MoneyMath.platformFeeCents(grossCents: amountCents)
        let netAmountCents = MoneyMath.winnerPayoutCents(grossCents: amountCents)
        let escrow = EscrowedFunds(
            id: UUID().uuidString,
            matchId: matchId,
            userId: userId,
            amount: amount,
            platformFee: MoneyMath.dollars(fromCents: platformFeeCents),
            netAmount: MoneyMath.dollars(fromCents: netAmountCents),
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
            "amountCents": amountCents,
            "platformFeeCents": platformFeeCents,
            "netAmountCents": netAmountCents,
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

        // 🔒 Dispute holds funds frozen — never capture or transfer while either side
        // is disputed. Ops must resolve the dispute and return rows to `held` first.
        guard winnerEscrow.status != .disputed, loserEscrow.status != .disputed else {
            print("🔒 [Escrow] Match \(matchId) funds frozen due to dispute — release blocked")
            throw EscrowError.fundsFrozenDispute
        }

        // 🔒 Idempotency: only release funds that are still held. Guards against a
        // retry double-capturing payment intents or double-transferring to the winner.
        guard winnerEscrow.status == .held, loserEscrow.status == .held else {
            print("⚠️ [Escrow] Funds for match \(matchId) already processed (winner: \(winnerEscrow.status.rawValue), loser: \(loserEscrow.status.rawValue)) — skipping to prevent double payout")
            return
        }
        
        // 2. Capture both payment intents (finalize the holds)
        try await capturePaymentIntent(paymentIntentId: winnerEscrow.stripePaymentIntentId ?? "")
        try await capturePaymentIntent(paymentIntentId: loserEscrow.stripePaymentIntentId ?? "")
        
        // 3. Calculate amounts in INTEGER CENTS (rounded) so the recorded audit
        // values match the server's settlement math. The authoritative transfer
        // is computed server-side in /create-transfer.
        let grossCents = MoneyMath.cents(fromDollars: winnerEscrow.amount + loserEscrow.amount)
        let platformFee = MoneyMath.dollars(fromCents: MoneyMath.platformFeeCents(grossCents: grossCents))
        let winnerPayout = MoneyMath.dollars(fromCents: MoneyMath.winnerPayoutCents(grossCents: grossCents))
        
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

        // 🔒 Idempotency: only refund funds still held — never re-cancel a payment
        // intent that was already released or refunded.
        guard escrow.status == .held else {
            print("⚠️ [Escrow] Funds for match \(matchId) user \(userId) already \(escrow.status.rawValue) — skipping refund")
            return
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
        
        let refundCents = escrow.amountCents
        print("✅ [Escrow] Refund processed - \(refundCents)¢ ($\(MoneyMath.dollars(fromCents: refundCents))) Payment intent cancelled")
    }
    
    // MARK: - 🔥 STRIPE API CALLS
    
    private func backendURL(_ path: String) throws -> URL {
        guard let url = URL(string: "\(backendAPIBaseURL)/\(path)") else {
            throw EscrowError.networkError
        }
        return url
    }
    
    /// 🔐 Create a wallet-deposit PaymentIntent through the AUTHENTICATED escrow
    /// backend. The secret key stays server-side; the wallet is credited by the
    /// Stripe webhook after the charge actually succeeds (never by the client).
    /// Returns the PaymentIntent id (to confirm via the Stripe Payment Sheet).
    func createWalletDepositIntent(userId: String, amountCents: Int, currency: String = EscrowCurrency.usd) async throws -> String {
        try EscrowCurrency.assertUSDOnly(currency)
        let url = try backendURL("create-escrow-payment")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await AuthTokenProvider.authorize(&request)
        let body: [String: Any] = [
            "customerId": userId,
            "amount": amountCents,
            "matchId": "wallet_deposit",
            "captureMethod": "automatic"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.configured.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw EscrowError.stripeError("Failed to create deposit intent")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let id = json?["paymentIntentId"] as? String else {
            throw EscrowError.stripeError("Invalid response")
        }
        return id
    }
    
    private func createPaymentIntent(customerId: String, amountCents: Int, matchId: String) async throws -> String {
        guard amountCents > 0 else { throw EscrowError.invalidAmount }
        let url = try backendURL("create-escrow-payment")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await AuthTokenProvider.authorize(&request)
        
        let body: [String: Any] = [
            "customerId": customerId,
            "amount": amountCents, // integer cents — never Double dollars
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
        let url = try backendURL("capture-payment")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await AuthTokenProvider.authorize(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["paymentIntentId": paymentIntentId])
        
        let (_, response) = try await URLSession.configured.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EscrowError.stripeError("Failed to capture payment")
        }
    }
    
    private func cancelPaymentIntent(paymentIntentId: String) async throws {
        let url = try backendURL("cancel-payment")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await AuthTokenProvider.authorize(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["paymentIntentId": paymentIntentId])
        
        let (_, response) = try await URLSession.configured.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EscrowError.stripeError("Failed to cancel payment")
        }
    }
    
    private func createTransfer(amount: Double, destinationAccountId: String, matchId: String) async throws {
        let url = try backendURL("create-transfer")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await AuthTokenProvider.authorize(&request)
        
        // 🔐 The backend derives the winner, payout amount, and destination from
        // the verified match outcome + captured escrow rows. The client only
        // names the match — amount/destination are intentionally NOT sent.
        let body: [String: Any] = [
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
        // 🔥 FIX: Read the SAME collection VSMatchWalletService writes deposits to
        // ("vs_match_wallets"). Previously this read "wallets", which is never
        // funded — so every wager failed the balance check even after a deposit.
        let walletDoc = try? await db.collection("vs_match_wallets").document(userId).getDocument()
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
        // Active = funds still in escrow awaiting capture/release.
        // Disputed and expired rows are excluded — they are not actionable holds.
        let held = heldFunds.values.filter { $0.status == .held }
        let released = heldFunds.values.filter { $0.status == .released }
        let refunded = heldFunds.values.filter { $0.status == .refunded }
        let disputed = heldFunds.values.filter { $0.status == .disputed }
        let expired = heldFunds.values.filter { $0.status == .expired }

        return EscrowStatistics(
            totalHeld: held.reduce(0) { $0 + $1.amount },
            totalReleased: released.reduce(0) { $0 + $1.amount },
            totalRefunded: refunded.reduce(0) { $0 + $1.amount },
            activeEscrows: held.count,
            completedEscrows: released.count + refunded.count,
            disputedEscrows: disputed.count,
            expiredEscrows: expired.count
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
    /// Legacy display dollars — prefer `platformFeeCents` / `platformFeeMoney` for math.
    @available(*, deprecated, message: "Use platformFeeCents or platformFeeMoney — Double drifts on settlement")
    let platformFee: Double
    let netAmount: Double
    var status: EscrowStatus
    let stripePaymentIntentId: String?
    let heldAt: Date
    var releasedAt: Date?
    
    /// Canonical Money views (integer cents) — prefer these for settlement math.
    var amountMoney: Money { Money(dollars: amount) }
    var platformFeeMoney: Money { Money(dollars: platformFee) }
    var netAmountMoney: Money { Money(dollars: netAmount) }
    var amountCents: Int { amountMoney.cents }
    var platformFeeCents: Int { platformFeeMoney.cents }
    var netAmountCents: Int { netAmountMoney.cents }
    
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
    /// Rows frozen by dispute — not counted in `activeEscrows`.
    var disputedEscrows: Int = 0
    /// Holds past expiry window — awaiting cleanup job.
    var expiredEscrows: Int = 0
    
    var platformRevenueTotal: Double {
        let releasedCents = MoneyMath.cents(fromDollars: totalReleased)
        return MoneyMath.dollars(fromCents: MoneyMath.platformFeeCents(grossCents: releasedCents))
    }
}

/// Firestore write DTO with canonical `Money` cents fields (Codable escrow contract).
struct EscrowFirestoreDTO: Codable {
    let id: String
    let matchId: String
    let userId: String
    let amount: Money
    let platformFee: Money
    let netAmount: Money
    let status: String
    let stripePaymentIntentId: String?

    init(from escrow: EscrowedFunds, amountCents: Int, platformFeeCents: Int, netAmountCents: Int) {
        id = escrow.id
        matchId = escrow.matchId
        userId = escrow.userId
        amount = Money(cents: amountCents)
        platformFee = Money(cents: platformFeeCents)
        netAmount = Money(cents: netAmountCents)
        status = escrow.status.rawValue
        stripePaymentIntentId = escrow.stripePaymentIntentId
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
    case unsupportedCurrency(String)
    case fundsFrozenDispute

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
        case .unsupportedCurrency(let code):
            return "Unsupported currency \"\(code)\". VS Match escrow is USD-only."
        case .fundsFrozenDispute:
            return "Funds are frozen while a dispute is open. Release is blocked until the dispute is resolved."
        }
    }
}

// MARK: - Release guard (unit-testable idempotency / dispute logic)

enum EscrowReleaseGuard {
    /// Returns whether `releaseFunds` may proceed for the given pair of escrow statuses.
    static func canRelease(winnerStatus: EscrowedFunds.EscrowStatus, loserStatus: EscrowedFunds.EscrowStatus) -> EscrowReleaseDecision {
        if winnerStatus == .disputed || loserStatus == .disputed {
            return .blockedDispute
        }
        guard winnerStatus == .held, loserStatus == .held else {
            return .skipAlreadyProcessed
        }
        return .proceed
    }
}

enum EscrowReleaseDecision: Equatable {
    case proceed
    case skipAlreadyProcessed
    case blockedDispute
}

