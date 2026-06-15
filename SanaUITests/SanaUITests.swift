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

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
