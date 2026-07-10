//
//  EscrowIdempotencyTests.swift
//  MyChannelTests
//
//  Guards double-release / dispute-freeze logic without hitting Stripe.
//

import XCTest
@testable import MyChannel

final class EscrowIdempotencyTests: XCTestCase {

    func testReleaseGuardProceedsWhenBothHeld() {
        XCTAssertEqual(
            EscrowReleaseGuard.canRelease(winnerStatus: .held, loserStatus: .held),
            .proceed
        )
    }

    func testReleaseGuardSkipsWhenAlreadyReleased() {
        XCTAssertEqual(
            EscrowReleaseGuard.canRelease(winnerStatus: .released, loserStatus: .held),
            .skipAlreadyProcessed
        )
        XCTAssertEqual(
            EscrowReleaseGuard.canRelease(winnerStatus: .held, loserStatus: .refunded),
            .skipAlreadyProcessed
        )
    }

    func testReleaseGuardBlocksWhenDisputed() {
        XCTAssertEqual(
            EscrowReleaseGuard.canRelease(winnerStatus: .disputed, loserStatus: .held),
            .blockedDispute
        )
        XCTAssertEqual(
            EscrowReleaseGuard.canRelease(winnerStatus: .held, loserStatus: .disputed),
            .blockedDispute
        )
    }

    func testDoubleReleaseSecondCallWouldSkip() {
        // Simulates idempotency: after first release both rows leave `.held`.
        let afterFirstRelease = EscrowReleaseGuard.canRelease(
            winnerStatus: .released,
            loserStatus: .released
        )
        XCTAssertEqual(afterFirstRelease, .skipAlreadyProcessed)
    }

    func testHoldFundsRejectsNonUSD() async {
        do {
            try await MoneyEscrowService.shared.holdFunds(
                userId: "u",
                amountCents: 100,
                matchId: "m",
                currency: "EUR"
            )
            XCTFail("expected unsupportedCurrency")
        } catch {
            guard case EscrowError.unsupportedCurrency(let code) = error else {
                XCTFail("unexpected error \(error)")
                return
            }
            XCTAssertEqual(code, "EUR")
        }
    }
}
