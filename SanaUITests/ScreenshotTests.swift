//
//  ScreenshotTests.swift
//  SanaUITests
//
//  Captures App Store screenshots for every supported locale in a single test
//  session — the app is relaunched per locale via -AppleLanguages/-AppleLocale
//  (the fastlane-snapshot approach), which is far more stable than spawning a
//  separate `xcodebuild test` per language. Launches with "-uitest-demo" (see
//  UITestSupport) so the dashboard is populated.
//
//  Run on the 6.9" device:
//    xcodebuild test -scheme Sana \
//      -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
//      -only-testing:SanaUITests/ScreenshotTests
//
//  Export the screenshots from the result bundle:
//    RESULT=$(ls -dt ~/Library/Developer/Xcode/DerivedData/Sana-*/Logs/Test/*.xcresult | head -1)
//    xcrun xcresulttool export attachments --path "$RESULT" --output-path ./shots
//  Attachment names are "<locale>-01-Dashboard" … "<locale>-05-Paywall".
//

import XCTest

final class ScreenshotTests: XCTestCase {

    /// (folder suffix, AppleLanguages value, AppleLocale value, demo units)
    private let locales: [(String, String, String, String)] = [
        ("en",   "en",    "en_US", "imperial"),
        ("de",   "de",    "de_DE", "metric"),
        ("es",   "es",    "es_ES", "metric"),
        ("fr",   "fr",    "fr_FR", "metric"),
        ("ptBR", "pt-BR", "pt_BR", "metric"),
        ("tr",   "tr",    "tr_TR", "metric"),
    ]

    // Tab order in MainTabView: 0 Dashboard, 1 Log, 2 Coach, 3 Meal Plan, 4 Insights.
    private enum Tab { static let dashboard = 0, coach = 2, mealPlan = 3, insights = 4 }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureKeyScreens() throws {
        for (suffix, language, locale, units) in locales {
            let app = XCUIApplication()
            app.launchArguments = [
                "-uitest-demo",
                "-demo-units", units,
                "-AppleLanguages", "(\(language))",
                "-AppleLocale", locale,
            ]
            app.launch()

            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "[\(suffix)] tab bar")

            capture(app, "\(suffix)-01-Dashboard")

            selectTab(tabBar, Tab.insights)
            capture(app, "\(suffix)-02-Insights")

            selectTab(tabBar, Tab.mealPlan)
            capture(app, "\(suffix)-03-MealPlan")

            selectTab(tabBar, Tab.coach)
            capture(app, "\(suffix)-04-Coach")

            // Paywall — located by stable identifiers, so locale doesn't matter.
            selectTab(tabBar, Tab.dashboard)
            let openProfile = app.buttons["openProfile"]
            if openProfile.waitForExistence(timeout: 5) {
                openProfile.tap()
                let upgrade = app.buttons["upgradeToPremium"]
                if upgrade.waitForExistence(timeout: 5) {
                    upgrade.tap(); settle()
                    capture(app, "\(suffix)-05-Paywall")
                }
            }

            app.terminate()
        }
    }

    // MARK: - Helpers

    private func settle() { Thread.sleep(forTimeInterval: 1.0) }

    /// Tap a tab and wait until it is actually selected. The first tap right
    /// after a relaunch can be swallowed while the dashboard reloads its data,
    /// which previously left a duplicate dashboard in place of the next screen.
    private func selectTab(_ tabBar: XCUIElement, _ index: Int) {
        let button = tabBar.buttons.element(boundBy: index)
        guard button.waitForExistence(timeout: 10) else { return }
        var attempts = 0
        repeat {
            button.tap()
            Thread.sleep(forTimeInterval: 0.6)
            attempts += 1
        } while !button.isSelected && attempts < 5
        settle()
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
