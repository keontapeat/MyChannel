//
//  MoneyEscrowIntegrationHarnessTests.swift
//  MyChannelTests
//
//  In-memory MoneyEscrowing harness — exercises hold/release guards without Stripe.
//

import XCTest
@testable import MyChannel

@MainActor
final class MockMoneyEscrowHarness: MoneyEscrowing {
    private(set) var held: [String: EscrowedFunds] = [:]
    var shouldFailHold = false

    func holdFunds(userId: String, amount: Double, matchId: String, currency: String) async throws {
        try await holdFunds(userId: userId, amountCents: MoneyMath.cents(fromDollars: amount), matchId: matchId, currency: currency)
    }

    func holdFunds(userId: String, amountCents: Int, matchId: String, currency: String) async throws {
        try EscrowCurrency.assertUSDOnly(currency)
        guard amountCents > 0 else { throw EscrowError.invalidAmount }
        if shouldFailHold { throw EscrowError.insufficientFunds }
        let key = "\(matchId)_\(userId)"
        let feeCents = MoneyMath.platformFeeCents(grossCents: amountCents)
        held[key] = EscrowedFunds(
            id: UUID().uuidString,
            matchId: matchId,
            userId: userId,
            amount: MoneyMath.dollars(fromCents: amountCents),
            platformFee: MoneyMath.dollars(fromCents: feeCents),
            netAmount: MoneyMath.dollars(fromCents: MoneyMath.winnerPayoutCents(grossCents: amountCents)),
            status: .held,
            stripePaymentIntentId: "pi_test",
            heldAt: Date()
        )
    }

    func releaseFunds(matchId: String, winnerId: String, loserId: String, totalPot: Double) async throws {
        let winnerKey = "\(matchId)_\(winnerId)"
        let loserKey = "\(matchId)_\(loserId)"
        guard var winner = held[winnerKey], var loser = held[loserKey] else {
            throw EscrowError.noFundsHeld
        }
        switch EscrowReleaseGuard.canRelease(winnerStatus: winner.status, loserStatus: loser.status) {
        case .proceed:
            winner.status = .released
            loser.status = .released
            held[winnerKey] = winner
            held[loserKey] = loser
        case .skipAlreadyProcessed:
            return
        case .blockedDispute:
            throw EscrowError.fundsFrozenDispute
        }
    }

    func refundFunds(matchId: String, userId: String) async throws {
        let key = "\(matchId)_\(userId)"
        guard var row = held[key] else { throw EscrowError.noFundsHeld }
        row.status = .refunded
        held[key] = row
    }

    func createWalletDepositIntent(userId: String, amountCents: Int, currency: String) async throws -> String {
        try await holdFunds(userId: userId, amountCents: amountCents, matchId: "wallet_deposit", currency: currency)
        return "pi_deposit_test"
    }

    func getEscrowStats() -> EscrowStatistics {
        let heldRows = held.values.filter { $0.status == .held }
        let released = held.values.filter { $0.status == .released }
        let refunded = held.values.filter { $0.status == .refunded }
        return EscrowStatistics(
            totalHeld: heldRows.reduce(0) { $0 + $1.amount },
            totalReleased: released.reduce(0) { $0 + $1.amount },
            totalRefunded: refunded.reduce(0) { $0 + $1.amount },
            activeEscrows: heldRows.count,
            completedEscrows: released.count + refunded.count
        )
    }

    func markDisputed(matchId: String, userId: String) {
        let key = "\(matchId)_\(userId)"
        guard var row = held[key] else { return }
        row.status = .disputed
        held[key] = row
    }
}

final class MoneyEscrowIntegrationHarnessTests: XCTestCase {

    @MainActor
    func testHarnessHoldAndReleaseUpdatesStats() async throws {
        let harness = MockMoneyEscrowHarness()
        try await harness.holdFunds(userId: "u1", amountCents: 5000, matchId: "m1")
        try await harness.holdFunds(userId: "u2", amountCents: 5000, matchId: "m1")
        XCTAssertEqual(harness.getEscrowStats().activeEscrows, 2)

        try await harness.releaseFunds(matchId: "m1", winnerId: "u1", loserId: "u2", totalPot: 90)
        XCTAssertEqual(harness.getEscrowStats().activeEscrows, 0)
        XCTAssertEqual(harness.getEscrowStats().completedEscrows, 2)
    }

    @MainActor
    func testHarnessDisputedRowExcludedFromActiveCount() async throws {
        let harness = MockMoneyEscrowHarness()
        try await harness.holdFunds(userId: "u1", amountCents: 1000, matchId: "m2")
        harness.markDisputed(matchId: "m2", userId: "u1")
        XCTAssertEqual(harness.getEscrowStats().activeEscrows, 0)
    }

    @MainActor
    func testEscrowFirestoreDTOEncodesMoneyCents() async throws {
        let escrow = EscrowedFunds(
            id: "e1",
            matchId: "m1",
            userId: "u1",
            amount: 50,
            platformFee: 5,
            netAmount: 45,
            status: .held,
            stripePaymentIntentId: "pi_1",
            heldAt: Date()
        )
        let dto = EscrowFirestoreDTO(
            from: escrow,
            amountCents: 5000,
            platformFeeCents: 500,
            netAmountCents: 4500
        )
        let data = try JSONEncoder().encode(dto)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["amount"])
    }

    func testWalletWithdrawCentsUsesMoneyMathRounding() {
        let withdrawDollars = 19.99
        let cents = MoneyMath.cents(fromDollars: withdrawDollars)
        XCTAssertEqual(cents, 1999)
        XCTAssertGreaterThanOrEqual(cents, 100)
    }
}
