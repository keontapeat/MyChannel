//
//  MoneyMathFuzzTests.swift
//  MyChannelTests
//
//  Fuzz-style property test: for random gross pots, platform fee + winner payout
//  must always equal gross (no cents lost or invented).
//

import XCTest
@testable import MyChannel

final class MoneyMathFuzzTests: XCTestCase {

    /// 50 pseudo-random gross pots — fee + payout == gross for every case.
    func testFeePlusPayoutEqualsGrossFuzz50() {
        var rng = SeededRNG(seed: 0xDEADBEEF_CAFE0001)

        for _ in 0..<50 {
            let grossCents = rng.nextInt(in: 0...10_000_000)
            let fee = MoneyMath.platformFeeCents(grossCents: grossCents)
            let payout = MoneyMath.winnerPayoutCents(grossCents: grossCents)

            XCTAssertEqual(fee + payout, grossCents,
                           "fee(\(fee)) + payout(\(payout)) must equal gross(\(grossCents))")
            XCTAssertGreaterThanOrEqual(fee, 0)
            XCTAssertGreaterThanOrEqual(payout, 0)
            XCTAssertLessThanOrEqual(fee, grossCents)
        }
    }
}

// MARK: - Deterministic RNG (repeatable across CI runs)

private struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xDEAD_BEEF_CAFE_BABE : seed
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        state = state &* 6364136223846793005 &+ 1
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        let value = Int(state % span) + range.lowerBound
        return value
    }
}
