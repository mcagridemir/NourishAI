// Sana — AppRouter.swift
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
        guard url.scheme == "sana" else { return }
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
        case "com.cagri.Sana.logMeal":
            selectedTab = .dashboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.showingMealLog = true }
        case "com.cagri.Sana.scanBarcode":
            selectedTab = .dashboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.showingBarcodeScanner = true }
        case "com.cagri.Sana.logWater":
            selectedTab = .dashboard   // WaterTrackerView is on the dashboard
        case "com.cagri.Sana.viewInsights":
            selectedTab = .insights
        default: break
        }
    }

    // MARK: - Static quick actions (registered at launch)

    static func registerQuickActions() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: "com.cagri.Sana.logMeal",
                localizedTitle: "Log meal",
                localizedSubtitle: "Snap a photo or enter manually",
                icon: UIApplicationShortcutIcon(systemImageName: "camera.fill")
            ),
            UIApplicationShortcutItem(
                type: "com.cagri.Sana.scanBarcode",
                localizedTitle: "Scan barcode",
                localizedSubtitle: "Look up food instantly",
                icon: UIApplicationShortcutIcon(systemImageName: "barcode.viewfinder")
            ),
            UIApplicationShortcutItem(
                type: "com.cagri.Sana.logWater",
                localizedTitle: "Log water",
                localizedSubtitle: "Track your hydration",
                icon: UIApplicationShortcutIcon(systemImageName: "drop.fill")
            ),
            UIApplicationShortcutItem(
                type: "com.cagri.Sana.viewInsights",
                localizedTitle: "My insights",
                localizedSubtitle: "Calories & macros at a glance",
                icon: UIApplicationShortcutIcon(systemImageName: "chart.bar.fill")
            )
        ]
    }
}
