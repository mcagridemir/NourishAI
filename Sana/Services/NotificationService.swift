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
            ("meal_breakfast", String(localized: "Time to log breakfast 🌅"),          Self.smartMealOffsetMinutes.breakfast),  // +1 h
            ("meal_lunch",     String(localized: "Don't forget to log lunch 🥗"),       Self.smartMealOffsetMinutes.lunch),      // +4.5 h
            ("meal_dinner",    String(localized: "Log your dinner to hit your goals 🌙"), Self.smartMealOffsetMinutes.dinner)      // +10 h
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

    /// Which smart-goal nudges apply for the given progress. Pure (no side effects) so it can be unit-tested.
    nonisolated enum GoalNudge: Hashable { case calorieClose, proteinClose, calorieMet, waterMet }

    nonisolated static func goalNudges(todayCalories: Int, targetCalories: Int,
                           todayProtein: Double, targetProtein: Double,
                           todayWater: Int, targetWater: Int) -> Set<GoalNudge> {
        var result: Set<GoalNudge> = []
        let calRemaining   = targetCalories - todayCalories
        let protRemaining  = targetProtein - todayProtein
        let waterRemaining = targetWater - todayWater
        if calRemaining > 0 && calRemaining <= 200       { result.insert(.calorieClose) }   // within 200 kcal
        if protRemaining > 0 && protRemaining <= 20      { result.insert(.proteinClose) }   // within 20 g
        if calRemaining <= 0 && calRemaining > -300      { result.insert(.calorieMet) }
        if waterRemaining <= 0 && waterRemaining > -500  { result.insert(.waterMet) }
        return result
    }

    /// Call once after each meal log. Fires a one-shot nudge if the user is close to (or just met) a goal.
    func fireSmartGoalNudge(todayCalories: Int, targetCalories: Int,
                            todayProtein: Double, targetProtein: Double,
                            todayWater: Int, targetWater: Int,
                            targetWaterFormatted: String = "") {
        let nudges = Self.goalNudges(todayCalories: todayCalories, targetCalories: targetCalories,
                                     todayProtein: todayProtein, targetProtein: targetProtein,
                                     todayWater: todayWater, targetWater: targetWater)

        // Only nudge once per day per goal: use delivered notifications as guard
        let center = UNUserNotificationCenter.current()

        if nudges.contains(.calorieClose) {
            let calRemaining = targetCalories - todayCalories
            send(center, id: "smart_cal_\(dayKey())",
                 title: String(localized: "Almost at your calorie goal 🎯"),
                 body: String(format: NSLocalizedString("Just %d kcal to go today. Keep it up!", comment: ""), calRemaining))
        }
        if nudges.contains(.proteinClose) {
            let protRemaining = targetProtein - todayProtein
            send(center, id: "smart_prot_\(dayKey())",
                 title: String(localized: "Protein goal almost reached 💪"),
                 body: String(format: NSLocalizedString("Only %dg more protein today — try a Greek yogurt or egg!", comment: ""), Int(protRemaining)))
        }
        if nudges.contains(.calorieMet) {
            send(center, id: "smart_cal_done_\(dayKey())",
                 title: String(localized: "Daily calorie goal hit! 🎉"),
                 body: String(format: NSLocalizedString("You've reached your %d kcal target. Great work today!", comment: ""), targetCalories))
        }
        if nudges.contains(.waterMet) {
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

        let hour = Self.supplementHour(forTimeOfDay: timeOfDay)

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

    // MARK: - Pure schedule logic (unit-tested)

    /// Minute offsets from wake time for sleep-aware meal reminders.
    nonisolated static let smartMealOffsetMinutes = (breakfast: 60, lunch: 270, dinner: 600)

    /// Maps a supplement time-of-day label to the hour it should fire at. Defaults to morning (8).
    nonisolated static func supplementHour(forTimeOfDay timeOfDay: String) -> Int {
        switch timeOfDay {
        case "Afternoon":  return 13
        case "Evening":    return 18
        case "Before bed": return 22
        case "With meals": return 12
        default:           return 8  // Morning
        }
    }
}
