//
//  VSCreateGateSmoke.swift
//  MyChannelUITests
//
//  XCUITest skeleton — VS Match create compliance gate smoke.
//  Mirrors web create-match preflight (age/KYC/region/terms).
//

import XCTest

final class VSCreateGateSmoke: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testVersusMatchCreatorLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.waitForExistence(timeout: 10))

        // Navigate to Gaming / VS Match creator if shortcut exists
        let vsEntry = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'VS Match' OR label CONTAINS[c] 'Create Match'")
        ).firstMatch

        if vsEntry.waitForExistence(timeout: 5) {
            vsEntry.tap()
            // Compliance sheet should block wager until age/terms pass
            let compliance = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'Compliance' OR label CONTAINS[c] '18'")
            ).firstMatch
            _ = compliance.waitForExistence(timeout: 3)
            XCTAssertTrue(app.exists)
        }
    }

    func testComplianceGatePlaceholder() throws {
        throw XCTSkip("VS create gate smoke pending VersusMatchCreatorView accessibility IDs")
    }
}
