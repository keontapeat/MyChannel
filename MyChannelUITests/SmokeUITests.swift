import XCTest

final class SmokeUITests: XCTestCase {
    func testLaunchAndExists() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.waitForExistence(timeout: 10))
    }
}
