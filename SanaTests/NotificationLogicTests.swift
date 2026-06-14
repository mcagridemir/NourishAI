// Sana — NotificationLogicTests.swift
import Testing
import Foundation
@testable import Sana

@Suite("Notification schedule logic")
struct NotificationLogicTests {

    // MARK: - Smart goal nudges

    @Test("calorie within 200 → calorieClose only")
    func calorieClose() {
        let n = NotificationService.goalNudges(
            todayCalories: 1850, targetCalories: 2000,
            todayProtein: 0, targetProtein: 200,        // far from protein
            todayWater: 0, targetWater: 2000)           // far from water
        #expect(n == [.calorieClose])
    }

    @Test("calorie remaining exactly 200 is still close (boundary)")
    func calorieCloseBoundary() {
        let n = NotificationService.goalNudges(
            todayCalories: 1800, targetCalories: 2000,
            todayProtein: 0, targetProtein: 200,
            todayWater: 0, targetWater: 2000)
        #expect(n.contains(.calorieClose))
    }

    @Test("calorie remaining 201 is NOT close")
    func calorieNotClose() {
        let n = NotificationService.goalNudges(
            todayCalories: 1799, targetCalories: 2000,
            todayProtein: 0, targetProtein: 200,
            todayWater: 0, targetWater: 2000)
        #expect(!n.contains(.calorieClose))
        #expect(!n.contains(.calorieMet))
    }

    @Test("protein within 20g → proteinClose")
    func proteinClose() {
        let n = NotificationService.goalNudges(
            todayCalories: 0, targetCalories: 2000,
            todayProtein: 130, targetProtein: 145,      // 15g remaining
            todayWater: 0, targetWater: 2000)
        #expect(n.contains(.proteinClose))
    }

    @Test("calorie goal just met (within 300 over) → calorieMet")
    func calorieMet() {
        let n = NotificationService.goalNudges(
            todayCalories: 2100, targetCalories: 2000,  // 100 over
            todayProtein: 0, targetProtein: 200,
            todayWater: 0, targetWater: 2000)
        #expect(n.contains(.calorieMet))
        #expect(!n.contains(.calorieClose))
    }

    @Test("calorie 300+ over goal → no calorie nudge (binged past window)")
    func calorieWayOver() {
        let n = NotificationService.goalNudges(
            todayCalories: 2400, targetCalories: 2000,  // 400 over
            todayProtein: 0, targetProtein: 200,
            todayWater: 0, targetWater: 2000)
        #expect(!n.contains(.calorieMet))
        #expect(!n.contains(.calorieClose))
    }

    @Test("water goal met within window → waterMet")
    func waterMet() {
        let n = NotificationService.goalNudges(
            todayCalories: 0, targetCalories: 2000,
            todayProtein: 0, targetProtein: 200,
            todayWater: 2100, targetWater: 2000)        // 100 over
        #expect(n.contains(.waterMet))
    }

    @Test("nothing close → empty set")
    func noNudges() {
        let n = NotificationService.goalNudges(
            todayCalories: 500, targetCalories: 2000,
            todayProtein: 20, targetProtein: 200,
            todayWater: 200, targetWater: 2000)
        #expect(n.isEmpty)
    }

    @Test("multiple goals can fire together")
    func multipleNudges() {
        let n = NotificationService.goalNudges(
            todayCalories: 1850, targetCalories: 2000,  // calorieClose
            todayProtein: 135, targetProtein: 145,      // proteinClose
            todayWater: 2100, targetWater: 2000)        // waterMet
        #expect(n == [.calorieClose, .proteinClose, .waterMet])
    }

    // MARK: - Supplement hour mapping

    @Test("supplement time-of-day maps to expected hour")
    func supplementHours() {
        #expect(NotificationService.supplementHour(forTimeOfDay: "Morning")    == 8)
        #expect(NotificationService.supplementHour(forTimeOfDay: "Afternoon")  == 13)
        #expect(NotificationService.supplementHour(forTimeOfDay: "Evening")    == 18)
        #expect(NotificationService.supplementHour(forTimeOfDay: "Before bed") == 22)
        #expect(NotificationService.supplementHour(forTimeOfDay: "With meals") == 12)
    }

    @Test("unknown time-of-day falls back to morning")
    func supplementUnknownFallback() {
        #expect(NotificationService.supplementHour(forTimeOfDay: "🤷") == 8)
        #expect(NotificationService.supplementHour(forTimeOfDay: "") == 8)
    }

    // MARK: - Smart meal offsets

    @Test("meal offsets are breakfast +1h, lunch +4.5h, dinner +10h")
    func mealOffsets() {
        let o = NotificationService.smartMealOffsetMinutes
        #expect(o.breakfast == 60)
        #expect(o.lunch == 270)
        #expect(o.dinner == 600)
    }

    @Test("offsets applied to a 7:00 wake time produce sane meal hours")
    func mealTimesFromWake() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 14; comps.hour = 7; comps.minute = 0
        let cal = Calendar.current
        let wake = cal.date(from: comps)!
        let o = NotificationService.smartMealOffsetMinutes

        let breakfast = cal.date(byAdding: .minute, value: o.breakfast, to: wake)!
        let lunch = cal.date(byAdding: .minute, value: o.lunch, to: wake)!
        let dinner = cal.date(byAdding: .minute, value: o.dinner, to: wake)!

        #expect(cal.component(.hour, from: breakfast) == 8)                                  // 08:00
        #expect(cal.component(.hour, from: lunch) == 11 && cal.component(.minute, from: lunch) == 30) // 11:30
        #expect(cal.component(.hour, from: dinner) == 17)                                    // 17:00
    }
}

@Suite("Subscription savings")
struct SubscriptionSavingsTests {

    @Test("yearly cheaper than 12× monthly → positive savings")
    func standardSavings() {
        // $4.99/mo → $59.88/yr; yearly $39.99 → ~33% savings
        let pct = SubscriptionService.yearlySavingsPercent(monthlyPrice: 4.99, yearlyPrice: 39.99)
        #expect(pct == 33)
    }

    @Test("yearly equal to 12× monthly → 0% savings")
    func noSavings() {
        let pct = SubscriptionService.yearlySavingsPercent(monthlyPrice: 5.00, yearlyPrice: 60.00)
        #expect(pct == 0)
    }

    @Test("zero monthly price → nil (avoid divide by zero)")
    func zeroMonthly() {
        #expect(SubscriptionService.yearlySavingsPercent(monthlyPrice: 0, yearlyPrice: 0) == nil)
    }

    @Test("half-price yearly → 50% savings")
    func halfPrice() {
        let pct = SubscriptionService.yearlySavingsPercent(monthlyPrice: 10.00, yearlyPrice: 60.00)
        #expect(pct == 50)
    }
}
