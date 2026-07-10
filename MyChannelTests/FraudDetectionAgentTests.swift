//
//  FraudDetectionAgentTests.swift
//  MyChannelTests
//
//  Pins FraudDetectionAgent amount checks to integer cents.
//

import XCTest
@testable import MyChannel

@MainActor
final class FraudDetectionAgentTests: XCTestCase {

    func testUnusualAmountComparesInCents() {
        let agent = FraudDetectionAgent.shared
        let history = FraudDetectionAgent.UserHistory(
            averageTransaction: 10,
            transactionsLast24h: 1,
            accountAge: 30 * 24 * 60 * 60,
            locationChanged: false,
            failedPayments: 0
        )
        // $100 is 10x avg $10 — should flag
        let score = agent.analyzTransaction(
            userId: "u1",
            amount: 100,
            transactionType: .wager,
            userHistory: history
        )
        XCTAssertTrue(score.reasons.contains("Amount 10x higher than usual"))
    }

    func testNormalAmountLowRisk() {
        let agent = FraudDetectionAgent.shared
        let history = FraudDetectionAgent.UserHistory(
            averageTransaction: 50,
            transactionsLast24h: 2,
            accountAge: 90 * 24 * 60 * 60,
            locationChanged: false,
            failedPayments: 0
        )
        let score = agent.analyzTransaction(
            userId: "u2",
            amount: 55,
            transactionType: .wager,
            userHistory: history
        )
        XCTAssertEqual(score.risk, .low)
    }
}
