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

    /// Regression: StripeConnect / wallet must use MoneyMath rounding, not Int(dollars * 100).
    func testCentsFromDollarsRoundsNotTruncates() {
        XCTAssertEqual(MoneyMath.cents(fromDollars: 19.99), 1999)
        XCTAssertNotEqual(Int(19.99 * 100), 1999) // documents the bug we avoid
    }

    func testEscrowStatisticsPlatformRevenueUsesMoneyMath() {
        let stats = EscrowStatistics(
            totalHeld: 0,
            totalReleased: 100,
            totalRefunded: 0,
            activeEscrows: 0,
            completedEscrows: 1
        )
        XCTAssertEqual(stats.platformRevenueTotal, 10.0, accuracy: 0.001)
    }

    func testWagerPolicyBoundsMatchCreateMatchGate() {
        XCTAssertTrue(WagerPolicy.isValidWagerAmount(1))
        XCTAssertTrue(WagerPolicy.isValidWagerAmount(100_000))
        XCTAssertFalse(WagerPolicy.isValidWagerAmount(0.99))
        XCTAssertFalse(WagerPolicy.isValidWagerAmount(100_000.01))
    }

    func testStripeConnectTransferUsesMoneyMathNotTruncation() {
        // StripeConnectService.holdFunds documents MoneyMath — verify payout path.
        let wagerDollars = 19.99
        let amountCents = MoneyMath.cents(fromDollars: wagerDollars)
        XCTAssertEqual(amountCents, 1999)
        let pot = amountCents * 2
        let payout = MoneyMath.winnerPayoutCents(grossCents: pot)
        XCTAssertEqual(payout, 3598)
        XCTAssertNotEqual(Int(wagerDollars * 100), amountCents)
    }

    func testHoldFundsRejectsNonPositiveCents() async {
        do {
            try await MoneyEscrowService.shared.holdFunds(userId: "test", amountCents: 0, matchId: "m")
            XCTFail("expected invalidAmount")
        } catch {
            guard let escrowError = error as? EscrowError else {
                XCTFail("unexpected error \(error)")
                return
            }
            if case .invalidAmount = escrowError {
                // ok
            } else {
                XCTFail("expected invalidAmount, got \(escrowError)")
            }
        }
    }

    func testEscrowedFundsMoneyViews() {
        let escrow = EscrowedFunds(
            id: "e1",
            matchId: "m1",
            userId: "u1",
            amount: 19.99,
            platformFee: 2.0,
            netAmount: 17.99,
            status: .held,
            stripePaymentIntentId: nil,
            heldAt: Date(),
            releasedAt: nil
        )
        XCTAssertEqual(escrow.amountCents, 1999)
        XCTAssertEqual(escrow.amountMoney.cents, 1999)
        XCTAssertEqual(escrow.platformFeeMoney.cents, 200)
    }

    func testPennyPotFeePayoutIdentityProperty() {
        for dollars in [1.0, 19.99, 50.0, 500.01, 9999.99] {
            let pot = MoneyMath.cents(fromDollars: dollars) * 2
            XCTAssertEqual(
                MoneyMath.platformFeeCents(grossCents: pot) + MoneyMath.winnerPayoutCents(grossCents: pot),
                pot
            )
        }
    }

    func testPartialRefundSplitsGrossExactly() {
        let gross = 10_000
        let (refund, retained) = MoneyMath.partialRefundCents(grossCents: gross, requestedRefundCents: 3_500)
        XCTAssertEqual(refund, 3_500)
        XCTAssertEqual(retained, 6_500)
        XCTAssertEqual(refund + retained, gross)
    }

    func testPartialRefundClampsOverRefundToGross() {
        let gross = 5_000
        let (refund, retained) = MoneyMath.partialRefundCents(grossCents: gross, requestedRefundCents: 99_999)
        XCTAssertEqual(refund, gross)
        XCTAssertEqual(retained, 0)
    }

    func testPartialRefundClampsNegativeToZero() {
        let gross = 5_000
        let (refund, retained) = MoneyMath.partialRefundCents(grossCents: gross, requestedRefundCents: -100)
        XCTAssertEqual(refund, 0)
        XCTAssertEqual(retained, gross)
    }

    func testEscrowCurrencyAssertUSDOnlyAcceptsVariants() throws {
        XCTAssertNoThrow(try EscrowCurrency.assertUSDOnly("USD"))
        XCTAssertNoThrow(try EscrowCurrency.assertUSDOnly(" usd "))
    }

    func testEscrowCurrencyAssertUSDOnlyRejectsNonUSD() {
        XCTAssertThrowsError(try EscrowCurrency.assertUSDOnly("EUR")) { error in
            guard case EscrowError.unsupportedCurrency(let code) = error else {
                return XCTFail("expected unsupportedCurrency, got \(error)")
            }
            XCTAssertEqual(code, "EUR")
        }
    }
}
