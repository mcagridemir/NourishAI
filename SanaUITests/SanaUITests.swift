//
//  SanaUITests.swift
//  SanaUITests
//
//  Smoke tests for the critical path: launch (auth + onboarding bypassed via
//  the "-uitest" DEBUG hook) → main tab bar → navigate every tab without crashing.
//

import XCTest

final class SanaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest"]
        app.launch()
        return app
    }

    /// Proves the auth bypass + seeded user land us on the main tab bar.
    @MainActor
    func testLaunchShowsAllTabs() throws {
        let app = launchApp()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10),
                      "Main tab bar should appear after launch")

        for label in ["Home", "Log Meal", "Coach", "Meal Plan", "Insights"] {
            XCTAssertTrue(tabBar.buttons[label].exists, "Missing tab: \(label)")
        }
    }

    /// Tapping through every tab must not crash; the tab bar stays present.
    @MainActor
    func testCanNavigateEveryTab() throws {
        let app = launchApp()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        for label in ["Insights", "Meal Plan", "Coach", "Home"] {
            let button = tabBar.buttons[label]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Tab \(label) not found")
            button.tap()
            XCTAssertTrue(tabBar.buttons[label].isSelected || tabBar.exists,
                          "Tab bar should remain after selecting \(label)")
        }
    }

    /// The revenue path: Dashboard → profile → Upgrade → paywall renders.
    /// Asserts only static chrome, so it passes without a StoreKit config.
    @MainActor
    func testPaywallPresentsFromProfile() throws {
        let app = launchApp()

        let openProfile = app.buttons["Open profile"]
        XCTAssertTrue(openProfile.waitForExistence(timeout: 10),
                      "Profile avatar should be in the dashboard header")
        openProfile.tap()

        // The button composes its label from title + subtitle ("Upgrade to
        // Premium, N free analyses remaining today"), so match by prefix.
        let upgrade = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'Upgrade to Premium'"))
            .firstMatch
        XCTAssertTrue(upgrade.waitForExistence(timeout: 5),
                      "Upgrade button should be on the Profile screen")
        upgrade.tap()

        // Chrome that renders regardless of whether StoreKit products loaded.
        let restore = app.buttons["Restore purchases"]
        let feature = app.staticTexts["Unlimited meal analyses"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5) || feature.exists,
                      "Paywall should present its static content")
    }

    /// The core-loop path: Log Meal tab → Manual entry → the form renders.
    @MainActor
    func testManualMealEntryFormPresents() throws {
        let app = launchApp()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        tabBar.buttons["Log Meal"].tap()

        let manual = app.buttons["Manual entry"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5),
                      "Log Meal should expose a Manual entry action")
        manual.tap()

        XCTAssertTrue(app.textFields["Meal name"].waitForExistence(timeout: 5),
                      "Manual entry should show the Meal name field")
        XCTAssertTrue(app.buttons["Save"].exists,
                      "Manual entry should show a Save button")
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
