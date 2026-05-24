// NourishAI — AppRouter.swift
// Central URL / deep-link and Quick Action handler. Shared via @EnvironmentObject.
import SwiftUI
internal import UIKit
internal import Combine

final class AppRouter: ObservableObject {
    @Published var selectedTab: MainTabView.Tab = .dashboard
    @Published var showingMealLog = false
    @Published var showingBarcodeScanner = false

    // MARK: - Deep link handler

    func handle(_ url: URL) {
        guard url.scheme == "nourishai" else { return }
        switch url.host {
        case "dashboard": selectedTab = .dashboard
        case "water":     selectedTab = .dashboard
        case "log":       showingMealLog = true
        case "scan":      showingBarcodeScanner = true
        case "insights":  selectedTab = .insights
        case "coach":     selectedTab = .coach
        case "plan":      selectedTab = .plan
        default:          selectedTab = .dashboard
        }
    }

    // MARK: - Home screen Quick Actions

    func handle(shortcutItem: UIApplicationShortcutItem) {
        switch shortcutItem.type {
        case "com.cagri.NourishAI.logMeal":
            selectedTab = .dashboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.showingMealLog = true }
        case "com.cagri.NourishAI.scanBarcode":
            selectedTab = .dashboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.showingBarcodeScanner = true }
        case "com.cagri.NourishAI.logWater":
            selectedTab = .dashboard   // WaterTrackerView is on the dashboard
        case "com.cagri.NourishAI.viewInsights":
            selectedTab = .insights
        default: break
        }
    }

    // MARK: - Static quick actions (registered at launch)

    static func registerQuickActions() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: "com.cagri.NourishAI.logMeal",
                localizedTitle: "Log meal",
                localizedSubtitle: "Snap a photo or enter manually",
                icon: UIApplicationShortcutIcon(systemImageName: "camera.fill")
            ),
            UIApplicationShortcutItem(
                type: "com.cagri.NourishAI.scanBarcode",
                localizedTitle: "Scan barcode",
                localizedSubtitle: "Look up food instantly",
                icon: UIApplicationShortcutIcon(systemImageName: "barcode.viewfinder")
            ),
            UIApplicationShortcutItem(
                type: "com.cagri.NourishAI.logWater",
                localizedTitle: "Log water",
                localizedSubtitle: "Track your hydration",
                icon: UIApplicationShortcutIcon(systemImageName: "drop.fill")
            ),
            UIApplicationShortcutItem(
                type: "com.cagri.NourishAI.viewInsights",
                localizedTitle: "My insights",
                localizedSubtitle: "Calories & macros at a glance",
                icon: UIApplicationShortcutIcon(systemImageName: "chart.bar.fill")
            )
        ]
    }
}
