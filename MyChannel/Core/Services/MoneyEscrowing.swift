//
//  MoneyEscrowing.swift
//  MyChannel
//
//  Protocol abstraction for VS Match escrow operations — enables DI mocks in tests.
//

import Foundation

/// Canonical currency for all escrow / VS Match money movement.
enum EscrowCurrency {
    static let usd = "USD"

    /// Fail closed: only USD is supported for real-money escrow.
    static func assertUSDOnly(_ currency: String) throws {
        let normalized = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized == usd else {
            throw EscrowError.unsupportedCurrency(normalized)
        }
    }
}

/// Escrow hold / release / refund surface used by VersusMatch and wallet flows.
@MainActor
protocol MoneyEscrowing: AnyObject {
    func holdFunds(userId: String, amount: Double, matchId: String, currency: String) async throws
    func holdFunds(userId: String, amountCents: Int, matchId: String, currency: String) async throws
    func releaseFunds(matchId: String, winnerId: String, loserId: String, totalPot: Double) async throws
    func refundFunds(matchId: String, userId: String) async throws
    func createWalletDepositIntent(userId: String, amountCents: Int, currency: String) async throws -> String
}

extension MoneyEscrowing {
    func holdFunds(userId: String, amount: Double, matchId: String) async throws {
        try await holdFunds(userId: userId, amount: amount, matchId: matchId, currency: EscrowCurrency.usd)
    }

    func holdFunds(userId: String, amountCents: Int, matchId: String) async throws {
        try await holdFunds(userId: userId, amountCents: amountCents, matchId: matchId, currency: EscrowCurrency.usd)
    }

    func createWalletDepositIntent(userId: String, amountCents: Int) async throws -> String {
        try await createWalletDepositIntent(userId: userId, amountCents: amountCents, currency: EscrowCurrency.usd)
    }
}
