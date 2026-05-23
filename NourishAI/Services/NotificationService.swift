// NourishAI — NotificationService.swift
import Foundation
import UserNotifications

final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // Schedule daily meal reminders
    func scheduleMealReminders(breakfast: DateComponents, lunch: DateComponents, dinner: DateComponents) {
        cancelAll(withPrefix: "meal_")
        let meals: [(String, String, DateComponents)] = [
            ("meal_breakfast", "Time to log breakfast 🌅", breakfast),
            ("meal_lunch",     "Don't forget to log lunch 🥗", lunch),
            ("meal_dinner",    "Log your dinner to hit your goals 🌙", dinner)
        ]
        for (id, body, time) in meals {
            let content = UNMutableNotificationContent()
            content.title = "NourishAI"
            content.body = body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    // Deficiency alert
    func sendDeficiencyAlert(nutrient: String) {
        let content = UNMutableNotificationContent()
        content.title = "Nutrition tip 💡"
        content.body = "Your \(nutrient) intake has been low this week. Tap to see suggestions."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "deficiency_\(nutrient)_\(Date().timeIntervalSince1970)",
            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // Weekly summary every Sunday evening
    func scheduleWeeklySummary() {
        cancelAll(withPrefix: "weekly_")
        let content = UNMutableNotificationContent()
        content.title = "Your weekly nutrition recap 📊"
        content.body = "See how your nutrition stacked up this week."
        content.sound = .default
        var components = DateComponents()
        components.weekday = 1; components.hour = 19; components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "weekly_summary", content: content, trigger: trigger))
    }

    func cancelAll(withPrefix prefix: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
