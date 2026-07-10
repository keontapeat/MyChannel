//
//  UpsellAgentTimingTests.swift
//  MyChannelTests
//
//  Pins UpsellAgent recommendation timing thresholds.
//

import XCTest
@testable import MyChannel

@MainActor
final class UpsellAgentTimingTests: XCTestCase {

    func testLowCreditsTriggersHighUrgencyUpsell() {
        let agent = UpsellAgent.shared
        let rec = agent.recommendUpsell(
            currentPlan: .starter,
            usage: UpsellAgent.UsageMetrics(creditsRemaining: 5, creditsTotal: 100, percentageUsed: 0.85),
            userBehavior: UpsellAgent.UserBehavior(sessionsPerWeek: 3, premiumFeatureAttempts: 0, videoCreationCount: 0)
        )
        XCTAssertNotNil(rec)
        XCTAssertEqual(rec?.urgency, .high)
    }

    func testPowerUserTriggersMediumUrgencyUpsell() {
        let agent = UpsellAgent.shared
        let rec = agent.recommendUpsell(
            currentPlan: .pro,
            usage: UpsellAgent.UsageMetrics(creditsRemaining: 50, creditsTotal: 500, percentageUsed: 0.95),
            userBehavior: UpsellAgent.UserBehavior(sessionsPerWeek: 12, premiumFeatureAttempts: 1, videoCreationCount: 5)
        )
        XCTAssertNotNil(rec)
        XCTAssertEqual(rec?.urgency, .medium)
    }

    func testNoUpsellWhenUsageHealthy() {
        let agent = UpsellAgent.shared
        let rec = agent.recommendUpsell(
            currentPlan: .pro,
            usage: UpsellAgent.UsageMetrics(creditsRemaining: 200, creditsTotal: 500, percentageUsed: 0.3),
            userBehavior: UpsellAgent.UserBehavior(sessionsPerWeek: 2, premiumFeatureAttempts: 0, videoCreationCount: 1)
        )
        XCTAssertNil(rec)
    }
}
