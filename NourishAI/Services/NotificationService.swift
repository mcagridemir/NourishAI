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

    // Schedule a one-shot notification when the fast completes
    func scheduleFastingComplete(in seconds: TimeInterval, targetHours: Int) {
        cancelAll(withPrefix: "fasting_")
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Fast complete! 🎉"
        content.body = "You've completed your \(targetHours)-hour fast. Great discipline — time to break your fast mindfully."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "fasting_complete", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelFastingNotification() {
        cancelAll(withPrefix: "fasting_")
    }

    // Hourly hydration reminders between startHour and endHour
    func scheduleHydrationReminders(intervalHours: Int = 2, startHour: Int = 8, endHour: Int = 21) {
        cancelAll(withPrefix: "hydration_")
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Time to hydrate 💧"
        content.body = "Don't forget to drink water to stay on track with your daily goal."
        content.sound = .default
        var hour = startHour
        var index = 0
        while hour <= endHour {
            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(identifier: "hydration_\(index)", content: content, trigger: trigger))
            hour += intervalHours
            index += 1
        }
    }

    func cancelHydrationReminders() {
        cancelAll(withPrefix: "hydration_")
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

    // MARK: - Smart goal notifications

    /// Call once after each meal log. Fires a one-shot nudge if the user is close (≤ 20%) to a goal.
    func fireSmartGoalNudge(todayCalories: Int, targetCalories: Int,
                            todayProtein: Double, targetProtein: Double,
                            todayWater: Int, targetWater: Int) {
        let calRemaining   = targetCalories - todayCalories
        let protRemaining  = targetProtein - todayProtein
        let waterRemaining = targetWater - todayWater

        // Only nudge once per day per goal: use delivered notifications as guard
        let center = UNUserNotificationCenter.current()

        // Calorie goal close (within 200 kcal)
        if calRemaining > 0 && calRemaining <= 200 {
            send(center, id: "smart_cal_\(dayKey())",
                 title: "Almost at your calorie goal 🎯",
                 body: "Just \(calRemaining) kcal to go today. Keep it up!")
        }
        // Protein goal close (within 20 g)
        if protRemaining > 0 && protRemaining <= 20 {
            send(center, id: "smart_prot_\(dayKey())",
                 title: "Protein goal almost reached 💪",
                 body: "Only \(Int(protRemaining))g more protein today — try a Greek yogurt or egg!")
        }
        // Calorie goal met
        if calRemaining <= 0 && calRemaining > -300 {
            send(center, id: "smart_cal_done_\(dayKey())",
                 title: "Daily calorie goal hit! 🎉",
                 body: "You've reached your \(targetCalories) kcal target. Great work today!")
        }
        // Water goal met
        if waterRemaining <= 0 && waterRemaining > -500 {
            send(center, id: "smart_water_\(dayKey())",
                 title: "Fully hydrated! 💧",
                 body: "You've hit your \(targetWater) ml water goal. Your body thanks you.")
        }
    }

    // MARK: - Streak recovery

    /// Schedule a streak-at-risk notification for 8 PM if the user has a streak but hasn't logged today.
    func scheduleStreakRecovery(currentStreak: Int, hasLoggedToday: Bool) {
        let center = UNUserNotificationCenter.current()
        let id = "streak_recovery_\(dayKey())"
        // Remove any stale request first
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard currentStreak >= 2 && !hasLoggedToday else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = 20
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "🔥 Don't break your \(currentStreak)-day streak!"
        content.body = "Log a meal now to keep your streak alive — it only takes a second."
        content.sound = .default
        content.categoryIdentifier = "STREAK_RECOVERY"

        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: - Supplement reminders

    /// Schedule a one-shot reminder for a supplement at the appropriate time-of-day.
    func scheduleSupplementReminder(name: String, timeOfDay: String, id: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let hour: Int
        switch timeOfDay {
        case "Afternoon": hour = 13
        case "Evening":   hour = 18
        case "Before bed": hour = 22
        case "With meals": hour = 12
        default: hour = 8  // Morning
        }

        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "💊 Time for \(name)"
        content.body = "Don't forget your \(timeOfDay.lowercased()) supplement."
        content.sound = .default

        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancelSupplementReminder(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    private func send(_ center: UNUserNotificationCenter, id: String, title: String, body: String) {
        center.getPendingNotificationRequests { pending in
            center.getDeliveredNotifications { delivered in
                let allIDs = Set(pending.map { $0.identifier } + delivered.map { $0.request.identifier })
                guard !allIDs.contains(id) else { return }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
            }
        }
    }

    private func dayKey() -> String {
        let d = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return "\(d.year ?? 0)-\(d.month ?? 0)-\(d.day ?? 0)"
    }
}
