//
//  WagerPolicyTests.swift
//  MyChannelTests
//
//  Tests for the real-money wager compliance thresholds (18+, KYC > $500,
//  per-tier daily limits, region allowlist). These gate real money, so the
//  boundaries are pinned down here.
//

import XCTest
@testable import MyChannel

final class WagerPolicyTests: XCTestCase {

    // MARK: - Age (18+)

    func testAgeGate() {
        XCTAssertFalse(WagerPolicy.isOfAge(17))
        XCTAssertTrue(WagerPolicy.isOfAge(18))
        XCTAssertTrue(WagerPolicy.isOfAge(45))
    }

    // MARK: - KYC threshold (> $500)

    func testKYCRequiredOnlyAbove500() {
        XCTAssertFalse(WagerPolicy.requiresKYC(amountDollars: 500), "exactly $500 should not require KYC")
        XCTAssertTrue(WagerPolicy.requiresKYC(amountDollars: 500.01))
        XCTAssertTrue(WagerPolicy.requiresKYC(amountDollars: 5000))
        XCTAssertFalse(WagerPolicy.requiresKYC(amountDollars: 100))
    }

    // MARK: - Wager amount bounds ($1–$100,000)

    func testValidWagerAmount() {
        XCTAssertFalse(WagerPolicy.isValidWagerAmount(0.99))
        XCTAssertTrue(WagerPolicy.isValidWagerAmount(1))
        XCTAssertTrue(WagerPolicy.isValidWagerAmount(100_000))
        XCTAssertFalse(WagerPolicy.isValidWagerAmount(100_000.01))
    }

    // MARK: - Per-tier daily limits

    func testDailyLimitsByTier() {
        XCTAssertEqual(WagerPolicy.dailyLimitDollars(tier: .new), 100)
        XCTAssertEqual(WagerPolicy.dailyLimitDollars(tier: .verified), 1_000)
        XCTAssertEqual(WagerPolicy.dailyLimitDollars(tier: .premium), 10_000)
        XCTAssertEqual(WagerPolicy.dailyLimitDollars(tier: .vip), 100_000)
    }

    func testWithinDailyLimitBoundary() {
        // Exactly at the limit is allowed; one cent over is not.
        XCTAssertTrue(WagerPolicy.isWithinDailyLimit(alreadyWagered: 80, newWager: 20, limit: 100))
        XCTAssertFalse(WagerPolicy.isWithinDailyLimit(alreadyWagered: 80, newWager: 20.01, limit: 100))
        XCTAssertTrue(WagerPolicy.isWithinDailyLimit(alreadyWagered: 0, newWager: 100, limit: 100))
    }

    // MARK: - Region allowlist

    func testRegionAllowlist() {
        XCTAssertTrue(WagerPolicy.isRegionAllowed("US-CA"))
        XCTAssertTrue(WagerPolicy.isRegionAllowed("US-DC"))
        XCTAssertTrue(WagerPolicy.isRegionAllowed("US-WY"))
        XCTAssertFalse(WagerPolicy.isRegionAllowed("US-ZZ"))
        XCTAssertFalse(WagerPolicy.isRegionAllowed("CA-ON"), "non-US region should be rejected")
        XCTAssertFalse(WagerPolicy.isRegionAllowed(""))
    }

    func testRegionAllowlistCoversAllStatesPlusDC() {
        // 50 states + DC
        XCTAssertEqual(WagerPolicy.allowedRegions.count, 51)
    }
}
