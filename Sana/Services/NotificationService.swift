// Sana — NotificationService.swift
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
            ("meal_breakfast", String(localized: "Time to log breakfast 🌅"), breakfast),
            ("meal_lunch",     String(localized: "Don't forget to log lunch 🥗"), lunch),
            ("meal_dinner",    String(localized: "Log your dinner to hit your goals 🌙"), dinner)
        ]
        for (id, body, time) in meals {
            let content = UNMutableNotificationContent()
            content.title = "Sana"
            content.body = body
            content.sound = .default
            content.categoryIdentifier = "MEAL_REMINDER"
            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    // Schedule meal reminders relative to a known wake time (sleep-aware scheduling).
    // Breakfast = wake + 1 h, Lunch = wake + 4.5 h, Dinner = wake + 10 h.
    func scheduleSmartMealReminders(wakeTime: Date) {
        cancelAll(withPrefix: "meal_")
        let cal = Calendar.current
        let offsets: [(String, String, Int)] = [
            ("meal_breakfast", String(localized: "Time to log breakfast 🌅"),          60),   // +1 h
            ("meal_lunch",     String(localized: "Don't forget to log lunch 🥗"),       270),  // +4.5 h
            ("meal_dinner",    String(localized: "Log your dinner to hit your goals 🌙"), 600)  // +10 h
        ]
        for (id, body, minuteOffset) in offsets {
            guard let fireDate = cal.date(byAdding: .minute, value: minuteOffset, to: wakeTime) else { continue }
            let comps = cal.dateComponents([.hour, .minute], from: fireDate)
            let content = UNMutableNotificationContent()
            content.title = "Sana"
            content.body  = body
            content.sound = .default
            content.categoryIdentifier = "MEAL_REMINDER"
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    // Deficiency alert
    func sendDeficiencyAlert(nutrient: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Nutrition tip 💡")
        content.body = String(format: NSLocalizedString("Your %@ intake has been low this week. Tap to see suggestions.", comment: ""), nutrient)
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
        content.title = String(localized: "Your weekly nutrition recap 📊")
        content.body = String(localized: "See how your nutrition stacked up this week.")
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
        content.title = String(localized: "Fast complete! 🎉")
        content.body = String(format: NSLocalizedString("You've completed your %d-hour fast. Great discipline — time to break your fast mindfully.", comment: ""), targetHours)
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
        content.title = String(localized: "Time to hydrate 💧")
        content.body = String(localized: "Don't forget to drink water to stay on track with your daily goal.")
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
                            todayWater: Int, targetWater: Int,
                            targetWaterFormatted: String = "") {
        let calRemaining   = targetCalories - todayCalories
        let protRemaining  = targetProtein - todayProtein
        let waterRemaining = targetWater - todayWater

        // Only nudge once per day per goal: use delivered notifications as guard
        let center = UNUserNotificationCenter.current()

        // Calorie goal close (within 200 kcal)
        if calRemaining > 0 && calRemaining <= 200 {
            send(center, id: "smart_cal_\(dayKey())",
                 title: String(localized: "Almost at your calorie goal 🎯"),
                 body: String(format: NSLocalizedString("Just %d kcal to go today. Keep it up!", comment: ""), calRemaining))
        }
        // Protein goal close (within 20 g)
        if protRemaining > 0 && protRemaining <= 20 {
            send(center, id: "smart_prot_\(dayKey())",
                 title: String(localized: "Protein goal almost reached 💪"),
                 body: String(format: NSLocalizedString("Only %dg more protein today — try a Greek yogurt or egg!", comment: ""), Int(protRemaining)))
        }
        // Calorie goal met
        if calRemaining <= 0 && calRemaining > -300 {
            send(center, id: "smart_cal_done_\(dayKey())",
                 title: String(localized: "Daily calorie goal hit! 🎉"),
                 body: String(format: NSLocalizedString("You've reached your %d kcal target. Great work today!", comment: ""), targetCalories))
        }
        // Water goal met
        if waterRemaining <= 0 && waterRemaining > -500 {
            let waterLabel = targetWaterFormatted.isEmpty ? "\(targetWater) ml" : targetWaterFormatted
            send(center, id: "smart_water_\(dayKey())",
                 title: String(localized: "Fully hydrated! 💧"),
                 body: String(format: NSLocalizedString("You've hit your %@ water goal. Your body thanks you.", comment: ""), waterLabel))
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
        content.title = String(format: NSLocalizedString("🔥 Don't break your %d-day streak!", comment: ""), currentStreak)
        content.body = String(localized: "Log a meal now to keep your streak alive — it only takes a second.")
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
        content.title = String(format: NSLocalizedString("💊 Time for %@", comment: ""), name)
        let localizedTime = NSLocalizedString(timeOfDay, comment: "supplement time of day").lowercased()
        content.body = String(format: NSLocalizedString("Don't forget your %@ supplement.", comment: ""), localizedTime)
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
