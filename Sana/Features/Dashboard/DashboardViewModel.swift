// Sana — DashboardViewModel.swift
import Foundation
import SwiftUI
internal import Combine

@MainActor
final class DashboardViewModel: ObservableObject {

    @Published var weeklyInsight: String?
    @Published var isLoadingInsights = false
    @Published var insightError: String?
    @Published var showPaywall = false

    private let user: User

    init(user: User) {
        self.user = user
    }

    var todayMeals: [MealEntry] {
        (user.mealEntries ?? [])
            .filter { Calendar.current.isDateInToday($0.loggedAt) }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    var todayCalories: Int { todayMeals.map { $0.calories }.reduce(0, +) }
    var todayProtein:  Double { todayMeals.map { $0.protein }.reduce(0, +) }
    var todayCarbs:    Double { todayMeals.map { $0.carbohydrates }.reduce(0, +) }
    var todayFat:      Double { todayMeals.map { $0.fat }.reduce(0, +) }
    var todayFiber:    Double { todayMeals.map { $0.fiber }.reduce(0, +) }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return String(localized: "Good morning,")
        case 12..<17: return String(localized: "Good afternoon,")
        case 17..<21: return String(localized: "Good evening,")
        default:      return String(localized: "Hey,")
        }
    }

    var calorieSurplus: Int { todayCalories - user.dailyCalorieTarget }
    var calorieProgress: Double { min(1.0, Double(todayCalories) / Double(max(1, user.dailyCalorieTarget))) }

    func loadInsights() async {
        WidgetDataStore.save(user.widgetData)
        LiveActivityService.shared.startOrUpdate(user: user)
        SpotlightService.indexMeals(user.mealEntries ?? [])
        fireGoalNudge()
        scheduleStreakRecovery()
        guard weeklyInsight == nil else { return }
        // Show insights when user has logged any meals ever (not just today)
        guard !(user.mealEntries ?? []).isEmpty else { return }
        isLoadingInsights = true
        insightError = nil
        defer { isLoadingInsights = false }
        do {
            weeklyInsight = try await ClaudeService.shared.generateWeeklyInsights(context: user.nutritionContext)
        } catch ClaudeError.quotaExceeded {
            showPaywall = true
        } catch {
            insightError = error.localizedDescription
        }
    }

    func retryInsights() async {
        weeklyInsight = nil
        insightError = nil
        await loadInsights()
    }

    private func fireGoalNudge() {
        NotificationService.shared.fireSmartGoalNudge(
            todayCalories: todayCalories,
            targetCalories: user.dailyCalorieTarget,
            todayProtein: todayProtein,
            targetProtein: user.dailyProteinTarget,
            todayWater: user.todayWaterMl,
            targetWater: user.dailyWaterGoalMl,
            targetWaterFormatted: user.formatWater(user.dailyWaterGoalMl)
        )
    }

    private func scheduleStreakRecovery() {
        let hasLoggedToday = (user.mealEntries ?? []).contains { Calendar.current.isDateInToday($0.loggedAt) }
        NotificationService.shared.scheduleStreakRecovery(
            currentStreak: user.currentStreak,
            hasLoggedToday: hasLoggedToday
        )
    }
}
