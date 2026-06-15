//
//  ScreenshotTests.swift
//  SanaUITests
//
//  Captures App Store screenshots of the key screens, localized via the
//  scheme's run language. Launches with "-uitest-demo" (see UITestSupport)
//  so the dashboard is populated rather than empty.
//
//  Run for one locale + device, e.g.:
//    xcodebuild test -scheme Sana \
//      -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
//      -only-testing:SanaUITests/ScreenshotTests \
//      -testLanguage de -testRegion DE
//
//  Screenshots are attached to the resulting .xcresult; export them with:
//    xcrun xcresulttool export attachments --path <result>.xcresult --output-path ./shots
//

import XCTest

final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureKeyScreens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-demo"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar should appear")

        capture(app, "01-Dashboard")

        tabBar.buttons["Insights"].tap()
        settle()
        capture(app, "02-Insights")

        tabBar.buttons["Meal Plan"].tap()
        settle()
        capture(app, "03-MealPlan")

        tabBar.buttons["Coach"].tap()
        settle()
        capture(app, "04-Coach")

        // Paywall — the revenue screen.
        tabBar.buttons["Home"].tap()
        let openProfile = app.buttons["Open profile"]
        if openProfile.waitForExistence(timeout: 5) {
            openProfile.tap()
            let upgrade = app.buttons
                .matching(NSPredicate(format: "label BEGINSWITH 'Upgrade to Premium'"))
                .firstMatch
            if upgrade.waitForExistence(timeout: 5) {
                upgrade.tap()
                settle()
                capture(app, "05-Paywall")
            }
        }
    }

    // MARK: - Helpers

    /// Let animations / async content settle before the snapshot.
    private func settle() { Thread.sleep(forTimeInterval: 1.2) }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
