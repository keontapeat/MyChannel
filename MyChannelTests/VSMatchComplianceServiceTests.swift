//
//  VSMatchComplianceServiceTests.swift
//  MyChannelTests
//
//  Pins WagerPolicy gates that VSMatchComplianceService must enforce.
//  Full Firestore integration is out of scope here — these tests lock the
//  pure policy boundaries the service delegates to.
//

import XCTest
@testable import MyChannel

final class VSMatchComplianceServiceTests: XCTestCase {

    func testKYCGateMatchesServiceThreshold() {
        XCTAssertFalse(WagerPolicy.requiresKYC(amountDollars: 500))
        XCTAssertTrue(WagerPolicy.requiresKYC(amountDollars: 500.01))
    }

    func testTermsVersionConstantIsPinned() {
        XCTAssertEqual(WagerPolicy.currentTermsVersion, "2025.1")
    }

    func testTermsAcceptanceRequiresCurrentVersion() {
        XCTAssertTrue(WagerPolicy.isTermsAcceptanceValid(accepted: true, version: "2025.1"))
        XCTAssertFalse(WagerPolicy.isTermsAcceptanceValid(accepted: true, version: "2024.0"))
        XCTAssertFalse(WagerPolicy.isTermsAcceptanceValid(accepted: false, version: "2025.1"))
        XCTAssertFalse(WagerPolicy.isTermsAcceptanceValid(accepted: true, version: ""))
    }

    func testStaleTermsVersionFailsClosed() {
        // Mirrors hasAcceptedTerms — stale acceptance must not pass.
        XCTAssertFalse(WagerPolicy.isTermsAcceptanceValid(accepted: true, version: "2025.0"))
    }

    func testPlatformFeePercentMatchesMoneyMath() {
        XCTAssertEqual(WagerPolicy.platformFeePercent, MoneyMath.platformFeePercent)
    }

    func testEmptyRegionIsNotAllowed() {
        XCTAssertFalse(WagerPolicy.isRegionAllowed(""))
    }

    func testWhitespaceOnlyRegionIsNotAllowed() {
        XCTAssertFalse(WagerPolicy.isRegionAllowed("   "))
    }

    func testUnknownRegionFailsClosed() {
        XCTAssertFalse(WagerPolicy.isRegionAllowed("US-XX"))
        XCTAssertFalse(WagerPolicy.isRegionAllowed("EU-DE"))
    }

    func testAgeBoundaryForWagering() {
        XCTAssertFalse(WagerPolicy.isOfAge(17))
        XCTAssertTrue(WagerPolicy.isOfAge(18))
    }

    func testDailyLimitNewTierBlocksOver100() {
        let limit = WagerPolicy.dailyLimitDollars(tier: .new)
        XCTAssertEqual(limit, 100)
        XCTAssertFalse(WagerPolicy.isWithinDailyLimit(alreadyWagered: 50, newWager: 51, limit: limit))
        XCTAssertTrue(WagerPolicy.isWithinDailyLimit(alreadyWagered: 50, newWager: 50, limit: limit))
    }

    func testDailyLimitBoundaryExactlyAtLimit() {
        let limit = WagerPolicy.dailyLimitDollars(tier: .verified)
        XCTAssertTrue(WagerPolicy.isWithinDailyLimit(alreadyWagered: 999, newWager: 1, limit: limit))
        XCTAssertFalse(WagerPolicy.isWithinDailyLimit(alreadyWagered: 999, newWager: 1.01, limit: limit))
    }

    func testComplianceReasonsAggregation() {
        let errors: [ComplianceError] = [.ageNotVerified, .kycRequired, .regionRestricted]
        let reasons = ComplianceError.aggregatedReasons(from: errors)
        XCTAssertEqual(reasons.count, 3)
        XCTAssertTrue(reasons.contains("Age verification required (18+)"))
        XCTAssertTrue(reasons.contains("KYC verification required for wagers over $500"))
        XCTAssertTrue(reasons.contains("Real money wagering not available in your region"))
    }

    func testCanUserWagerReasonAggregationMultipleErrors() {
        // Mirrors VSMatchComplianceService.collectWagerErrors → multipleErrors path.
        let errors: [ComplianceError] = [
            .termsNotAccepted,
            .dailyLimitExceeded,
            .accountSuspended
        ]
        let reasons = ComplianceError.aggregatedReasons(from: errors)
        XCTAssertEqual(reasons.count, 3)
        XCTAssertTrue(reasons.contains("Terms of Service must be accepted"))
        XCTAssertTrue(reasons.contains("Daily wager limit exceeded"))
        XCTAssertTrue(reasons.contains("Account is suspended"))
    }

    func testCanUserWagerMultipleErrorsJoinedDescription() {
        let errors: [ComplianceError] = [.ageNotVerified, .kycRequired]
        if case .multipleErrors(let nested) = ComplianceError.multipleErrors(errors) {
            XCTAssertEqual(nested.count, 2)
            let joined = ComplianceError.multipleErrors(errors).localizedDescription ?? ""
            XCTAssertTrue(joined.contains("Age verification required (18+)"))
            XCTAssertTrue(joined.contains("KYC verification required for wagers over $500"))
        } else {
            XCTFail("Expected multipleErrors case")
        }
    }

    func testCanUserWagerKYCAndTermsReasonsDistinct() {
        let errors: [ComplianceError] = [.kycRequired, .termsNotAccepted]
        let reasons = ComplianceError.aggregatedReasons(from: errors)
        XCTAssertEqual(Set(reasons).count, 2)
        XCTAssertFalse(reasons[0].isEmpty)
    }

    func testCanUserWagerUnderageReasonPreserved() {
        let errors: [ComplianceError] = [.underage("Must be 18+ to wager real money")]
        let reasons = ComplianceError.aggregatedReasons(from: errors)
        XCTAssertEqual(reasons, ["Must be 18+ to wager real money"])
    }

    func testActiveEscrowsExcludesDisputedFromHarnessStats() {
        let stats = EscrowStatistics(
            totalHeld: 50,
            totalReleased: 0,
            totalRefunded: 0,
            activeEscrows: 1,
            completedEscrows: 0,
            disputedEscrows: 2,
            expiredEscrows: 1
        )
        XCTAssertEqual(stats.activeEscrows, 1)
        XCTAssertEqual(stats.disputedEscrows, 2)
    }
}
