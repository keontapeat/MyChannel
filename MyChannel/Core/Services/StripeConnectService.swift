//
//  StripeConnectService.swift
//  MyChannel
//
//  Stripe Connect integration for real money VS matches
//

import Foundation

@MainActor
final class StripeConnectService: ObservableObject, StripeConnecting {
    
    static let shared = StripeConnectService()
    private init() {}
    
    @Published var isLoading = false
    @Published var connectedAccounts: [String: StripeAccount] = [:]
    
    // MARK: - Configuration
    // 🔐 SECURITY: The Stripe SECRET key must NEVER live in or be used by the
    // client. All privileged Stripe operations (account creation, onboarding
    // links, payment intents, transfers, balances) are performed by authenticated
    // backend Cloud Functions that hold the secret key server-side. The client
    // only ever sends a verified Firebase ID token.
    private let backendBaseURL = "https://us-central1-mychannel-ca26d.cloudfunctions.net"
    
    // MARK: - Connect Account Management
    
    /// Create a Stripe Connect account for a creator.
    /// 🔐 Account creation requires the Stripe secret key and therefore happens
    /// on the backend. Use the authenticated `createConnectOnboardingLink` Cloud
    /// Function (see ArtistEarningsView / music-payouts) which creates the Express
    /// account server-side and returns a hosted onboarding URL.
    func createConnectAccount(userId: String, email: String, country: String = "US") async throws -> StripeAccount {
        throw StripeError.mustUseBackend
    }
    
    /// Create an account link for onboarding.
    /// 🔐 Backend-only — see `createConnectOnboardingLink` Cloud Function.
    func createAccountLink(accountId: String, returnURL: String, refreshURL: String) async throws -> String {
        throw StripeError.mustUseBackend
    }
    
    // MARK: - Payment & Transfers
    
    /// Create a payment intent for a VS match wager.
    /// 🔐 Backend-only — routed through the authenticated escrow Cloud Function
    /// (`/create-escrow-payment`) via `MoneyEscrowService`.
    func createPaymentIntent(amount: Int, currency: String = "usd", customerId: String? = nil) async throws -> String {
        throw StripeError.mustUseBackend
    }
    
    /// Transfer winnings to the match winner via Stripe Connect.
    /// 🔐 HARDENED: routes through the authenticated `/create-transfer` Cloud
    /// Function with a verified Firebase ID token. The backend derives the
    /// winner, amount, and destination from the recorded match outcome — the
    /// client cannot set the amount or destination, and the secret key never
    /// touches the device.
    func transferToWinner(amount: Int, winnerId: String, currency: String = "usd", matchId: String) async throws {
        guard let url = URL(string: "\(backendBaseURL)/create-transfer") else {
            throw StripeError.networkError
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await AuthTokenProvider.authorize(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["matchId": matchId])
        
        let data = try await NetworkOptimizer.shared.optimizedRequest(
            for: request,
            priority: .high
        )
        _ = try? JSONDecoder().decode(TransferResponse.self, from: data)
        print("💸 [Stripe] Winner payout settled server-side for match \(matchId)")
    }
    
    // MARK: - Escrow Management
    
    /// Hold funds in escrow for a VS match.
    /// Routes through MoneyEscrowService (authenticated CF) — never creates PaymentIntents client-side.
    func holdInEscrow(matchId: String, amount: Double, player1Id: String, player2Id: String) async throws -> String {
        try await MoneyEscrowService.shared.holdFunds(
            userId: player1Id,
            amount: amount,
            matchId: matchId
        )
        try await MoneyEscrowService.shared.holdFunds(
            userId: player2Id,
            amount: amount,
            matchId: matchId
        )
        print("🏦 [Stripe] Held $\(amount * 2) in escrow for match \(matchId) (server-side)")
        return matchId
    }
    
    /// Release escrow funds to winner.
    /// `escrowAmount` is the gross pot (both wagers). Fee/payout use `MoneyMath`.
    func releaseEscrow(matchId: String, winnerId: String, loserId: String, escrowAmount: Double) async throws {
        let grossCents = MoneyMath.cents(fromDollars: escrowAmount)
        let platformFeeCents = MoneyMath.platformFeeCents(grossCents: grossCents)
        let winnerPayoutCents = MoneyMath.winnerPayoutCents(grossCents: grossCents)
        let winnerAmount = MoneyMath.dollars(fromCents: winnerPayoutCents)
        let platformFee = MoneyMath.dollars(fromCents: platformFeeCents)
        
        // Transfer to winner — backend derives amount/destination from the
        // verified match outcome; we pass the matchId so it can settle securely.
        try await transferToWinner(amount: winnerPayoutCents, winnerId: winnerId, matchId: matchId)
        
        // Release escrow (gross pot; escrow service recomputes fee from held legs)
        try await MoneyEscrowService.shared.releaseFunds(
            matchId: matchId,
            winnerId: winnerId,
            loserId: loserId,
            totalPot: MoneyMath.dollars(fromCents: grossCents)
        )
        
        print("🏆 [Stripe] Released $\(winnerAmount) to winner \(winnerId)")
        print("   Platform fee: $\(platformFee)")
    }
    
    // MARK: - Refunds
    
    /// Refund a match if it's cancelled or disputed
    func refundMatch(matchId: String, player1Id: String, player2Id: String, amount: Double) async throws {
        let amountCents = MoneyMath.cents(fromDollars: amount)
        
        // Stripe refund is handled server-side by the Cloud Function `processRefund`
        print("💳 [Stripe] Refunding $\(MoneyMath.dollars(fromCents: amountCents)) to both players")
        
        // Refund escrow to both players
        try await MoneyEscrowService.shared.refundFunds(matchId: matchId, userId: player1Id)
        try await MoneyEscrowService.shared.refundFunds(matchId: matchId, userId: player2Id)
    }
    
    // MARK: - Account Verification
    
    /// Check if account is verified and can receive payouts
    func isAccountVerified(userId: String) async -> Bool {
        guard let account = connectedAccounts[userId] else {
            return false
        }
        return account.isVerified
    }
    
    /// Get account balance.
    /// 🔐 Backend-only — the Stripe balance endpoint requires the secret key.
    func getAccountBalance(accountId: String) async throws -> Balance {
        throw StripeError.mustUseBackend
    }
}

// MARK: - Models

struct StripeAccount {
    let id: String
    let userId: String
    let email: String
    var isVerified: Bool
    let createdAt: Date
}

struct Balance {
    let available: Double
    let pending: Double
    let currency: String
}

// MARK: - API Response Models

struct StripeAccountResponse: Codable {
    let id: String
    let charges_enabled: Bool
    let payouts_enabled: Bool
}

struct AccountLinkResponse: Codable {
    let url: String
}

struct PaymentIntentResponse: Codable {
    let id: String
    let amount: Int
    let currency: String
    let status: String
}

struct TransferResponse: Codable {
    let id: String
    let amount: Int
    let currency: String
    let destination: String
}

struct BalanceResponse: Codable {
    let available: [BalanceAmount]
    let pending: [BalanceAmount]
}

struct BalanceAmount: Codable {
    let amount: Int
    let currency: String
}

// MARK: - Errors

enum StripeError: Error {
    case accountCreationFailed
    case accountNotFound
    case transferFailed
    case paymentFailed
    case invalidAmount
    case verificationRequired
    case mustUseBackend
    case networkError
}

extension StripeError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .accountCreationFailed:
            return "Failed to create Stripe Connect account"
        case .accountNotFound:
            return "Stripe account not found for this user"
        case .transferFailed:
            return "Failed to transfer funds"
        case .paymentFailed:
            return "Payment failed"
        case .invalidAmount:
            return "Invalid payment amount"
        case .verificationRequired:
            return "Account verification required to receive payments"
        case .mustUseBackend:
            return "This operation runs on the secure backend. Use the authenticated Cloud Function endpoint."
        case .networkError:
            return "Network error. Please check your connection and try again."
        }
    }
}

