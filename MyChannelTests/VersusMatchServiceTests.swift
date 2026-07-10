//
//  VersusMatchServiceTests.swift
//  MyChannelTests
//
//  Pins create-match validation contract (WagerPolicy bounds) used by
//  VersusMatchService.createMatch before any money moves.
//

import XCTest
@testable import MyChannel

final class VersusMatchServiceTests: XCTestCase {

    func testCreateMatchRejectsSubMinimumWager() {
        XCTAssertFalse(WagerPolicy.isValidWagerAmount(0.99))
        XCTAssertEqual(
            MatchError.invalidWagerAmount.errorDescription,
            "Wager amount must be between $1 and $100,000"
        )
    }

    func testCreateMatchAcceptsPolicyBounds() {
        XCTAssertTrue(WagerPolicy.isValidWagerAmount(1))
        XCTAssertTrue(WagerPolicy.isValidWagerAmount(100_000))
    }

    func testVersusMatchCentsHelpers() {
        let match = VersusMatch(
            id: "m1",
            challengerId: "a",
            opponentId: "b",
            matchType: .headToHead,
            wagerAmount: 50,
            category: .gaming,
            rules: VersusMatch.MatchRules(
                duration: 300,
                category: .gaming,
                winCondition: .mostViews,
                customRules: nil
            ),
            status: .pending,
            winnerId: nil,
            createdAt: Date(),
            scheduledDate: Date(),
            startedAt: nil,
            completedAt: nil,
            finalStats: nil
        )
        XCTAssertEqual(match.wagerAmountCents, 5_000)
        XCTAssertEqual(match.potCents, 10_000)
        XCTAssertEqual(match.winnerPayoutCents, 9_000)
    }
}
