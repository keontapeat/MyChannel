//
//  StripeConnecting.swift
//  MyChannel
//
//  Protocol abstraction for Stripe Connect payout surface — enables DI mocks in tests.
//

import Foundation

/// Connect onboarding and winner payout (all privileged ops are backend-only).
@MainActor
protocol StripeConnecting: AnyObject {
    func transferToWinner(amount: Int, winnerId: String, currency: String, matchId: String) async throws
    func createAccountLink(accountId: String, returnURL: String, refreshURL: String) async throws -> String
}
