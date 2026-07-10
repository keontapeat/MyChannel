//
//  VSMatchWalleting.swift
//  MyChannel
//
//  Protocol abstraction for VS Match wallet operations — enables DI mocks in tests.
//

import Foundation

/// Deposit, withdraw, and balance reads for the VS Match in-app wallet.
@MainActor
protocol VSMatchWalleting: AnyObject {
    func depositFunds(userId: String, amount: Double, paymentMethodId: String) async throws -> DepositResult
    func requestWithdrawal(userId: String, amount: Double, destination: WithdrawalDestination) async throws -> Withdrawal
    func getBalance(userId: String) async throws -> Double
}
