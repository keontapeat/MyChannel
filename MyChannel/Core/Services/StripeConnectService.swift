//
//  StripeConnectService.swift
//  MyChannel
//
//  Stripe Connect integration for real money VS matches
//

import Foundation

@MainActor
final class StripeConnectService: ObservableObject {
    
    static let shared = StripeConnectService()
    private init() {}
    
    @Published var isLoading = false
    @Published var connectedAccounts: [String: StripeAccount] = [:]
    
    // MARK: - Configuration
    private let apiKey = AppSecrets.stripeSecretKey
    private let baseURL = "https://api.stripe.com/v1"
    
    // MARK: - Connect Account Management
    
    /// Create a Stripe Connect account for a creator
    func createConnectAccount(userId: String, email: String, country: String = "US") async throws -> StripeAccount {
        isLoading = true
        defer { isLoading = false }
        
        let url = URL(string: "\(baseURL)/accounts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "type": "express",
            "country": country,
            "email": email,
            "capabilities[card_payments][requested]": "true",
            "capabilities[transfers][requested]": "true",
            "business_type": "individual"
        ]
        
        let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        // ⚡ PERFORMANCE: Use NetworkOptimizer for request deduplication
        let data = try await NetworkOptimizer.shared.optimizedRequest(
            for: request,
            priority: .high
        )
        
        let accountData = try JSONDecoder().decode(StripeAccountResponse.self, from: data)
        
        let account = StripeAccount(
            id: accountData.id,
            userId: userId,
            email: email,
            isVerified: accountData.charges_enabled,
            createdAt: Date()
        )
        
        connectedAccounts[userId] = account
        
        print("✅ [Stripe] Created Connect account for user \(userId)")
        return account
    }
    
    /// Create an account link for onboarding
    func createAccountLink(accountId: String, returnURL: String, refreshURL: String) async throws -> String {
        let url = URL(string: "\(baseURL)/account_links")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "account": accountId,
            "refresh_url": refreshURL,
            "return_url": returnURL,
            "type": "account_onboarding"
        ]
        
        let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        // ⚡ PERFORMANCE: Use NetworkOptimizer for request deduplication
        let data = try await NetworkOptimizer.shared.optimizedRequest(
            for: request,
            priority: .high
        )
        let linkData = try JSONDecoder().decode(AccountLinkResponse.self, from: data)
        
        return linkData.url
    }
    
    // MARK: - Payment & Transfers
    
    /// Create a payment intent for VS match wager
    func createPaymentIntent(amount: Int, currency: String = "usd", customerId: String? = nil) async throws -> String {
        let url = URL(string: "\(baseURL)/payment_intents")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var parameters: [String: String] = [
            "amount": "\(amount)",
            "currency": currency,
            "payment_method_types[]": "card"
        ]
        
        if let customerId = customerId {
            parameters["customer"] = customerId
        }
        
        let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        // ⚡ PERFORMANCE: Use NetworkOptimizer for request deduplication
        let data = try await NetworkOptimizer.shared.optimizedRequest(
            for: request,
            priority: .high
        )
        let intentData = try JSONDecoder().decode(PaymentIntentResponse.self, from: data)
        
        print("💰 [Stripe] Created payment intent: \(intentData.id)")
        return intentData.id
    }
    
    /// Transfer funds to winner's Connect account
    func transferToWinner(amount: Int, winnerId: String, currency: String = "usd") async throws {
        guard let account = connectedAccounts[winnerId] else {
            throw StripeError.accountNotFound
        }
        
        let url = URL(string: "\(baseURL)/transfers")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "amount": "\(amount)",
            "currency": currency,
            "destination": account.id
        ]
        
        let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        // ⚡ PERFORMANCE: Use NetworkOptimizer for request deduplication
        let data = try await NetworkOptimizer.shared.optimizedRequest(
            for: request,
            priority: .high
        )
        
        let transferData = try JSONDecoder().decode(TransferResponse.self, from: data)
        
        print("💸 [Stripe] Transferred $\(amount/100) to winner \(winnerId)")
        print("   Transfer ID: \(transferData.id)")
    }
    
    // MARK: - Escrow Management
    
    /// Hold funds in escrow for a VS match
    func holdInEscrow(matchId: String, amount: Double, player1Id: String, player2Id: String) async throws -> String {
        // Convert to cents
        let amountInCents = Int(amount * 100)
        
        // Create payment intent
        let intentId = try await createPaymentIntent(amount: amountInCents * 2) // Total pot from both players
        
        // Store escrow info in MoneyEscrowService (holding for both players)
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
        
        print("🏦 [Stripe] Held $\(amount * 2) in escrow for match \(matchId)")
        return intentId
    }
    
    /// Release escrow funds to winner
    func releaseEscrow(matchId: String, winnerId: String, loserId: String, escrowAmount: Double) async throws {
        // escrowAmount is passed in from the match data
        
        // Calculate platform fee (10%)
        let platformFee = escrowAmount * 0.1
        let winnerAmount = escrowAmount - platformFee
        
        // Transfer to winner
        let amountInCents = Int(winnerAmount * 100)
        try await transferToWinner(amount: amountInCents, winnerId: winnerId)
        
        // Release escrow
        try await MoneyEscrowService.shared.releaseFunds(
            matchId: matchId,
            winnerId: winnerId,
            loserId: loserId,
            totalPot: winnerAmount
        )
        
        print("🏆 [Stripe] Released $\(winnerAmount) to winner \(winnerId)")
        print("   Platform fee: $\(platformFee)")
    }
    
    // MARK: - Refunds
    
    /// Refund a match if it's cancelled or disputed
    func refundMatch(matchId: String, player1Id: String, player2Id: String, amount: Double) async throws {
        // Refund to both players
        let amountInCents = Int(amount * 100)
        
        // TODO: Implement actual Stripe refund
        print("💳 [Stripe] Refunding $\(amount) to both players")
        
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
    
    /// Get account balance
    func getAccountBalance(accountId: String) async throws -> Balance {
        let url = URL(string: "\(baseURL)/balance")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // ⚡ PERFORMANCE: Use NetworkOptimizer for caching and deduplication
        let data = try await NetworkOptimizer.shared.optimizedRequest(
            for: request,
            priority: .normal
        )
        let balanceData = try JSONDecoder().decode(BalanceResponse.self, from: data)
        
        let availableBalance = balanceData.available.first?.amount ?? 0
        let pendingBalance = balanceData.pending.first?.amount ?? 0
        
        return Balance(
            available: Double(availableBalance) / 100,
            pending: Double(pendingBalance) / 100,
            currency: balanceData.available.first?.currency ?? "usd"
        )
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
        }
    }
}

