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

    /// (folder suffix, AppleLanguages value, AppleLocale value)
    private let locales: [(String, String, String)] = [
        ("en",   "en",    "en_US"),
        ("de",   "de",    "de_DE"),
        ("es",   "es",    "es_ES"),
        ("fr",   "fr",    "fr_FR"),
        ("ptBR", "pt-BR", "pt_BR"),
        ("tr",   "tr",    "tr_TR"),
    ]

    // Tab order in MainTabView: 0 Dashboard, 1 Log, 2 Coach, 3 Meal Plan, 4 Insights.
    private enum Tab { static let dashboard = 0, coach = 2, mealPlan = 3, insights = 4 }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureKeyScreens() throws {
        for (suffix, language, locale) in locales {
            let app = XCUIApplication()
            app.launchArguments = [
                "-uitest-demo",
                "-AppleLanguages", "(\(language))",
                "-AppleLocale", locale,
            ]
            app.launch()

            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "[\(suffix)] tab bar")

            capture(app, "\(suffix)-01-Dashboard")

            tabBar.buttons.element(boundBy: Tab.insights).tap();  settle()
            capture(app, "\(suffix)-02-Insights")

            tabBar.buttons.element(boundBy: Tab.mealPlan).tap();  settle()
            capture(app, "\(suffix)-03-MealPlan")

            tabBar.buttons.element(boundBy: Tab.coach).tap();     settle()
            capture(app, "\(suffix)-04-Coach")

            // Paywall — located by stable identifiers, so locale doesn't matter.
            tabBar.buttons.element(boundBy: Tab.dashboard).tap()
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

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
