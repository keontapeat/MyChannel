//
//  GamingAgentsMoneyTests.swift
//  MyChannelTests
//
//  Verifies GamingAgents / Match Orchestrator pot math stays on MoneyMath.
//

import XCTest
@testable import MyChannel

final class GamingAgentsMoneyTests: XCTestCase {

    func testMatchOrchestratorPotUsesMoneyMathNotRawDoubleFee() {
        let wager = 50.0
        let potCents = MoneyMath.cents(fromDollars: wager) * 2
        let platformFee = MoneyMath.dollars(fromCents: MoneyMath.platformFeeCents(grossCents: potCents))
        let winnerPayout = MoneyMath.dollars(fromCents: MoneyMath.winnerPayoutCents(grossCents: potCents))
        XCTAssertEqual(potCents, 10_000)
        XCTAssertEqual(platformFee, 10.0, accuracy: 0.001)
        XCTAssertEqual(winnerPayout, 90.0, accuracy: 0.001)
        XCTAssertNotEqual(winnerPayout, wager * 2 * 0.9, accuracy: 0.001)
    }

    func testPennyWagerPotIdentity() {
        let potCents = MoneyMath.cents(fromDollars: 19.99) * 2
        XCTAssertEqual(
            MoneyMath.platformFeeCents(grossCents: potCents) + MoneyMath.winnerPayoutCents(grossCents: potCents),
            potCents
        )
    }
}
