//
//  MoneyMathGoldenTests.swift
//  MyChannelTests
//
//  Golden table of known MoneyMath values — catches rounding regressions.
//

import XCTest
@testable import MyChannel

final class MoneyMathGoldenTests: XCTestCase {

    /// Known (dollars, potCents, feeCents, payoutCents) tuples.
    private let goldenTable: [(dollars: Double, pot: Int, fee: Int, payout: Int)] = [
        (1.0, 200, 20, 180),
        (19.99, 3998, 400, 3598),
        (50.0, 10_000, 1_000, 9_000),
        (500.0, 100_000, 10_000, 90_000),
        (100_000.0, 20_000_000, 2_000_000, 18_000_000),
    ]

    func testGoldenTableFeeAndPayout() {
        for row in goldenTable {
            let pot = MoneyMath.cents(fromDollars: row.dollars) * 2
            XCTAssertEqual(pot, row.pot, "pot mismatch for $\(row.dollars)")
            XCTAssertEqual(MoneyMath.platformFeeCents(grossCents: pot), row.fee)
            XCTAssertEqual(MoneyMath.winnerPayoutCents(grossCents: pot), row.payout)
            XCTAssertEqual(row.fee + row.payout, row.pot)
        }
    }

    func testGoldenDollarsFromCentsRoundTrip() {
        for row in goldenTable {
            let cents = MoneyMath.cents(fromDollars: row.dollars)
            XCTAssertEqual(MoneyMath.dollars(fromCents: cents), row.dollars, accuracy: 0.001)
        }
    }
}
