import XCTest

/// Captures App Store screenshots. Run with scripts/screenshots.sh CraneLog.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAppScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-resetData", "-sampleData", "-skipOnboarding", "-uiTesting"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Cranes"].waitForExistence(timeout: 15))
        sleep(1)
        // The fleet, with the red-tagged machine in its own band at the top.
        snap("01-fleet", app)

        app.staticTexts["CD-02 — Broderson IC-80"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["CD-02"].waitForExistence(timeout: 5))
        sleep(1)
        snap("02-out-of-service", app)

        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
        sleep(1)

        app.staticTexts["RT-04 — Grove RT770E"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["RT-04"].waitForExistence(timeout: 5))
        sleep(1)
        snap("03-machine", app)

        // The row reads "Monthly … Due in n days", so match the prefix rather than the whole label.
        let monthly = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Monthly")).firstMatch
        XCTAssertTrue(monthly.waitForExistence(timeout: 5))
        monthly.tap()
        XCTAssertTrue(app.navigationBars["Monthly inspection"].waitForExistence(timeout: 5))
        sleep(1)
        snap("04-inspection", app)
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists { cancel.tap() }
        sleep(1)

        let back2 = app.navigationBars.buttons.element(boundBy: 0)
        if back2.exists { back2.tap() }
        XCTAssertTrue(app.buttons["How do I use this app?"].waitForExistence(timeout: 6))
        app.buttons["How do I use this app?"].tap()
        sleep(1)
        snap("05-how-to", app)
    }

    func testPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-uiTesting", "-mockPrices"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Lifetime"].waitForExistence(timeout: 10))
        snap("paywall", app)
    }

    private func snap(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
