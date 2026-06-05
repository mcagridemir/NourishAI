// Sana — SanaApp.swift
import SwiftUI
import SwiftData
import BackgroundTasks
import FirebaseCore
internal import Combine
internal import UIKit

// MARK: - AppDelegate (Quick Actions + notification deep-linking)

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Self.registerNotificationCategories()
        return true
    }

    // MARK: - Notification categories with action buttons

    static func registerNotificationCategories() {
        let logNowAction = UNNotificationAction(
            identifier: "LOG_NOW",
            title: "Log meal",
            options: .foreground          // opens the app
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_15",
            title: "Remind me in 15 min",
            options: []                   // background — no app launch
        )

        let mealCategory = UNNotificationCategory(
            identifier: "MEAL_REMINDER",
            actions: [logNowAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        let streakCategory = UNNotificationCategory(
            identifier: "STREAK_RECOVERY",
            actions: [logNowAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([mealCategory, streakCategory])
    }

    func application(_ application: UIApplication,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        NotificationCenter.default.post(name: .sanaQuickAction, object: shortcutItem)
        completionHandler(true)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    // Route notification taps and action buttons.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        switch response.actionIdentifier {
        case "LOG_NOW":
            // Foreground action — deep-link straight to the log sheet.
            NotificationCenter.default.post(name: .sanaDeepLink,
                                            object: URL(string: "sana://log")!)
        case "SNOOZE_15":
            // Background action — reschedule the same notification 15 minutes later.
            let original = response.notification.request
            let newContent = original.content.mutableCopy() as! UNMutableNotificationContent
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15 * 60, repeats: false)
            let newID = original.identifier + "_snooze"
            center.removePendingNotificationRequests(withIdentifiers: [newID])
            center.add(UNNotificationRequest(identifier: newID,
                                             content: newContent,
                                             trigger: trigger))
        default:
            // Default tap — use the identifier-based deep link.
            let url = Self.deepLinkURL(for: response.notification.request.identifier)
            NotificationCenter.default.post(name: .sanaDeepLink, object: url)
        }
        completionHandler()
    }

    // Show banners even when the app is foregrounded.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    private static func deepLinkURL(for identifier: String) -> URL {
        let path: String
        switch true {
        case identifier.hasPrefix("meal_"):            path = "log"
        case identifier.hasPrefix("deficiency_"):      path = "coach"
        case identifier == "weekly_summary":           path = "insights"
        case identifier == "fasting_complete":         path = "dashboard"
        case identifier.hasPrefix("hydration_"):       path = "water"
        case identifier.hasPrefix("streak_recovery_"): path = "log"
        case identifier.hasPrefix("smart_"):           path = "dashboard"
        case identifier.hasPrefix("supplement_"):      path = "dashboard"
        default:                                       path = "dashboard"
        }
        return URL(string: "sana://\(path)")!
    }
}

extension Notification.Name {
    static let sanaQuickAction = Notification.Name("sanaQuickAction")
    static let sanaDeepLink    = Notification.Name("sanaDeepLink")
}

// MARK: - Main App

@main
struct SanaApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth         = AuthService.shared
    @StateObject private var subscription = SubscriptionService.shared
    @StateObject private var healthKit    = HealthKitService.shared
    @StateObject private var router       = AppRouter()
    @StateObject private var theme        = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase

    private let bgTaskID = "com.cagri.Sana.widgetRefresh"

    init() {
        FirebaseApp.configure()
        AppRouter.registerQuickActions()
        _ = MetricsService.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(AppContainer.shared.modelContainer)
                .environmentObject(auth)
                .environmentObject(subscription)
                .environmentObject(healthKit)
                .environmentObject(router)
                .tint(theme.primaryColor)
                .onChange(of: auth.state) { _, state in
                    switch state {
                    case .signedIn(let id, let provider):
                        FirebaseService.shared.setUserID(id)
                        FirebaseService.shared.setUserProperty(provider.rawValue, for: .authProvider)
                    case .signedOut:
                        FirebaseService.shared.setUserID(nil)
                    case .loading:
                        break
                    }
                }
                .onOpenURL { url in router.handle(url) }
                .onReceive(NotificationCenter.default.publisher(for: .sanaQuickAction)) { note in
                    if let item = note.object as? UIApplicationShortcutItem {
                        router.handle(shortcutItem: item)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .sanaDeepLink)) { note in
                    if let url = note.object as? URL { router.handle(url) }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                if healthKit.isAuthorized {
                    Task { await healthKit.refreshAll() }
                }
                // Submit (or re-submit) the background refresh task each time the app
                // comes to the foreground. BGTaskScheduler replaces any pending request
                // with the same identifier, so this is idempotent. Without this, the
                // very first background-refresh run is never scheduled.
                scheduleBackgroundRefresh()
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
