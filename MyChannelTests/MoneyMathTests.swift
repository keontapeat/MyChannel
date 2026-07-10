//
//  MoneyMathTests.swift
//  MyChannelTests
//
//  Regression tests for money arithmetic. Guards the penny-truncation bug where
//  Int(19.99 * 100) == 1998 instead of 1999, and the VS Match 10% platform fee.
//

import XCTest
@testable import MyChannel

final class MoneyMathTests: XCTestCase {

    // MARK: - Dollars → Cents (rounding, not truncation)

    func testCentsRoundsNotTruncates() {
        // The classic float-truncation trap: 19.99 * 100 == 1998.9999...
        XCTAssertEqual(MoneyMath.cents(fromDollars: 19.99), 1999)
        XCTAssertEqual(MoneyMath.cents(fromDollars: 0.29), 29)
        XCTAssertEqual(MoneyMath.cents(fromDollars: 1.10), 110)
        XCTAssertEqual(MoneyMath.cents(fromDollars: 100.07), 10007)
    }

    func testCentsWholeAndZeroAmounts() {
        XCTAssertEqual(MoneyMath.cents(fromDollars: 0), 0)
        XCTAssertEqual(MoneyMath.cents(fromDollars: 1), 100)
        XCTAssertEqual(MoneyMath.cents(fromDollars: 100_000), 10_000_000)
    }

    func testCentsDollarsRoundTrip() {
        for dollars in [1.0, 5.5, 19.99, 250.25, 999.99] {
            let cents = MoneyMath.cents(fromDollars: dollars)
            XCTAssertEqual(MoneyMath.dollars(fromCents: cents), dollars, accuracy: 0.0001)
        }
    }

    // MARK: - Platform Fee (10%)

    func testPlatformFeeTenPercent() {
        // $50 wager → 5000¢, 10% fee = 500¢
        XCTAssertEqual(MoneyMath.platformFeeCents(grossCents: 5000), 500)
        // $100 pot → 10000¢, fee 1000¢
        XCTAssertEqual(MoneyMath.platformFeeCents(grossCents: 10000), 1000)
    }

    func testPlatformFeeRoundsToNearestCent() {
        // 999¢ * 0.10 = 99.9¢ → rounds to 100¢
        XCTAssertEqual(MoneyMath.platformFeeCents(grossCents: 999), 100)
    }

    func testWinnerPayoutIsGrossMinusFee() {
        // Two $25 wagers → 5000¢ pot, 10% fee 500¢, winner gets 4500¢
        let pot = MoneyMath.cents(fromDollars: 25) + MoneyMath.cents(fromDollars: 25)
        XCTAssertEqual(pot, 5000)
        XCTAssertEqual(MoneyMath.winnerPayoutCents(grossCents: pot), 4500)
    }

    func testWinnerPayoutNeverNegative() {
        XCTAssertEqual(MoneyMath.winnerPayoutCents(grossCents: 0), 0)
    }

    func testFeePlusPayoutEqualsGross() {
        for pot in [100, 5000, 10007, 200000, 9_999_999] {
            let fee = MoneyMath.platformFeeCents(grossCents: pot)
            let payout = MoneyMath.winnerPayoutCents(grossCents: pot)
            XCTAssertEqual(fee + payout, pot, "fee + payout must equal the gross pot, no cents lost")
        }
    }

    /// Property-style sweep: fee + payout identity across many pots.
    func testFeePlusPayoutIdentityPropertySweep() {
        for pot in stride(from: 0, through: 50_000, by: 137) {
            let fee = MoneyMath.platformFeeCents(grossCents: pot)
            let payout = MoneyMath.winnerPayoutCents(grossCents: pot)
            XCTAssertEqual(fee + payout, pot)
            XCTAssertGreaterThanOrEqual(payout, 0)
        }
    }

    func testPartialRefundCentsIdentity() {
        for gross in [100, 5000, 19_999, 100_000] {
            for refund in [0, gross / 4, gross / 2, gross, gross + 500] {
                let split = MoneyMath.partialRefundCents(grossCents: gross, requestedRefundCents: refund)
                XCTAssertEqual(split.refund + split.retained, gross)
                XCTAssertLessThanOrEqual(split.refund, gross)
                XCTAssertGreaterThanOrEqual(split.retained, 0)
            }
        }
    }
}
