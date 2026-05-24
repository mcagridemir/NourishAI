// NourishAI — NourishAIApp.swift
import SwiftUI
import SwiftData
import BackgroundTasks
internal import UIKit

// MARK: - AppDelegate (Quick Actions + cold-launch shortcut handling)

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        NotificationCenter.default.post(
            name: .nourishQuickAction,
            object: shortcutItem
        )
        completionHandler(true)
    }
}

extension Notification.Name {
    static let nourishQuickAction = Notification.Name("nourishQuickAction")
}

// MARK: - Main App

@main
struct NourishAIApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var subscription = SubscriptionService.shared
    @StateObject private var healthKit    = HealthKitService.shared
    @StateObject private var router       = AppRouter()
    @StateObject private var theme        = ThemeManager.shared

    private let bgTaskID = "com.cagri.NourishAI.widgetRefresh"

    init() {
        AppRouter.registerQuickActions()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(AppContainer.shared.modelContainer)
                .environmentObject(subscription)
                .environmentObject(healthKit)
                .environmentObject(router)
                .tint(theme.primaryColor)
                .onOpenURL { url in router.handle(url) }
                .onReceive(NotificationCenter.default.publisher(for: .nourishQuickAction)) { note in
                    if let item = note.object as? UIApplicationShortcutItem {
                        router.handle(shortcutItem: item)
                    }
                }
        }
        .backgroundTask(.appRefresh(bgTaskID)) {
            // Re-save widget data so the home screen widget stays current overnight
            let context = ModelContext(AppContainer.shared.modelContainer)
            if let user = try? context.fetch(FetchDescriptor<User>()).first {
                WidgetDataStore.save(user.widgetData)
            }
            scheduleBackgroundRefresh()
        }
    }

    /// Schedule next background refresh ~15 min from now (system may delay it).
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: bgTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

}
