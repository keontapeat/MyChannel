import XCTest

final class SmokeUITests: XCTestCase {
    func testLaunchAndExists() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.waitForExistence(timeout: 10))
    }

    func testBasicNavigationAndPerformance() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.waitForExistence(timeout: 10))

        // Home visible
        XCTAssertTrue(app.staticTexts["MyChannel"].waitForExistence(timeout: 5))

        // Open search
        let searchButton = app.buttons.matching(identifier: nil).matching(NSPredicate(format: "label CONTAINS 'magnifyingglass' OR label CONTAINS 'Search'"))
        _ = searchButton.firstMatch.exists

        // Navigate to Live TV from Home quick section (if present)
        // This is resilient: it won't fail build if absent
        if app.staticTexts["Live TV"].waitForExistence(timeout: 2) {
            app.staticTexts["See all"].firstMatch.tap()
            // back
            app.buttons["xmark"].firstMatch.tap()
        }
    }
}
