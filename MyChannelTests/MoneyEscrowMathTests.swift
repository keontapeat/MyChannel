//
//  MoneyEscrowMathTests.swift
//  MyChannelTests
//
//  Guards escrow payout math stays on MoneyMath (integer cents).
//

import XCTest
@testable import MyChannel

final class MoneyEscrowMathTests: XCTestCase {

    func testTwoSidedPotFeeAndPayout() {
        // Two $50 wagers → $100 pot → 10% fee $10 → winner $90
        let gross = MoneyMath.cents(fromDollars: 50) + MoneyMath.cents(fromDollars: 50)
        XCTAssertEqual(gross, 10_000)
        XCTAssertEqual(MoneyMath.platformFeeCents(grossCents: gross), 1_000)
        XCTAssertEqual(MoneyMath.winnerPayoutCents(grossCents: gross), 9_000)
    }

    func testEscrowReleaseMatchesLiveVersusDisplay() {
        // Same formula LiveVersusMatchView now uses
        let wager = 25.0
        let pot = MoneyMath.cents(fromDollars: wager) * 2
        let winner = MoneyMath.winnerPayoutCents(grossCents: pot)
        XCTAssertEqual(winner, 4_500) // $45.00
        XCTAssertEqual(MoneyMath.dollars(fromCents: winner), 45.0, accuracy: 0.001)
    }

    func testPennyWagerDoesNotLoseCents() {
        let wager = 19.99
        let pot = MoneyMath.cents(fromDollars: wager) * 2
        XCTAssertEqual(pot, 3998)
        let fee = MoneyMath.platformFeeCents(grossCents: pot)
        let payout = MoneyMath.winnerPayoutCents(grossCents: pot)
        XCTAssertEqual(fee + payout, pot)
    }
}
