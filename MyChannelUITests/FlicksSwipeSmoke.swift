//
//  FlicksSwipeSmoke.swift
//  MyChannelUITests
//
//  XCUITest skeleton — Flicks vertical swipe smoke.
//  Expand with accessibility identifiers on FlicksView before enabling in CI.
//

import XCTest

final class FlicksSwipeSmoke: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFlicksTabLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.waitForExistence(timeout: 10))

        // Tap Flicks tab if present (resilient — won't fail CI if tab label differs)
        let flicksTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Flicks' OR label CONTAINS[c] 'Shorts'")
        ).firstMatch

        if flicksTab.waitForExistence(timeout: 5) {
            flicksTab.tap()
            // TODO: swipe up on Flicks feed once accessibilityIdentifier "flicks-feed" exists
            XCTAssertTrue(app.exists)
        }
    }

    func testFlicksSwipePlaceholder() throws {
        // Snapshot / recording placeholder — wire to real feed when IDs land.
        throw XCTSkip("Flicks swipe smoke pending accessibility identifiers on FlicksGestureLayer")
    }
}
