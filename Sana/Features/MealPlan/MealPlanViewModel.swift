// Sana — MealPlanViewModel.swift
import Foundation
import SwiftData
internal import UIKit
internal import Combine

@MainActor
final class MealPlanViewModel: ObservableObject {

    @Published var currentPlan: MealPlan?
    @Published var isGenerating = false
    @Published var isReplacingMeal = false
    @Published var error: String?
    @Published var replacementSuccess = false
    @Published var showPaywall = false

    let user: User

    init(user: User) { self.user = user }

    func loadExistingPlan() {
        currentPlan = (user.mealPlans ?? [])
            .filter { $0.isActive }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    func generatePlan() async {
        isGenerating = true
        error = nil
        defer { isGenerating = false }
        do {
            let response = try await ClaudeService.shared.generateMealPlan(context: user.nutritionContext)
            let monday = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) ?? .now

            // Deactivate old plans before creating the new one so SwiftData's
            // inverse relationship update doesn't immediately deactivate the new plan.
            (user.mealPlans ?? []).forEach { $0.isActive = false }

            let plan = MealPlan(weekStartDate: monday)
            plan.user = user

            for dayResp in response.days {
                let date = Calendar.current.date(byAdding: .day, value: dayResp.dayIndex, to: monday) ?? monday
                let day = MealPlanDay(date: date, dayIndex: dayResp.dayIndex)
                day.meals = [
                    PlannedMeal(from: dayResp.breakfast, mealType: .breakfast),
                    PlannedMeal(from: dayResp.lunch,     mealType: .lunch),
                    PlannedMeal(from: dayResp.dinner,    mealType: .dinner)
                ] + dayResp.snacks.map { PlannedMeal(from: $0, mealType: .snack) }
                day.plan = plan
            }

            currentPlan = plan
        } catch ClaudeError.quotaExceeded {
            showPaywall = true
        } catch {
            self.error = error.localizedDescription
            print("❌ Meal plan error: \(error)")
        }
    }

    /// Replace a specific planned meal using Claude.
    func replaceMeal(_ meal: PlannedMeal, preference: String = "") async {
        isReplacingMeal = true
        error = nil
        defer { isReplacingMeal = false }
        do {
            let suggestion = try await ClaudeService.shared.replaceMealSuggestion(
                currentMealName: meal.name,
                mealType: meal.mealType,
                preference: preference,
                context: user.nutritionContext
            )
            meal.name            = suggestion.name
            meal.mealDescription = suggestion.description
            meal.prepTimeMinutes = suggestion.prepTime
            meal.calories        = suggestion.calories
            meal.protein         = suggestion.protein
            meal.carbohydrates   = suggestion.carbohydrates
            meal.fat             = suggestion.fat
            meal.ingredients     = suggestion.ingredients
            meal.recipeSteps     = suggestion.recipe
            meal.isCompleted     = false
            HapticService.notification(.success)
            replacementSuccess = true
        } catch ClaudeError.quotaExceeded {
            showPaywall = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Build and save a meal plan directly from a coach-generated response.
    func savePlanFromCoach(_ response: MealPlanResponse) {
        let monday = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        ) ?? .now
        (user.mealPlans ?? []).forEach { $0.isActive = false }
        let plan = MealPlan(weekStartDate: monday, title: "Coach Plan")
        plan.user = user
        for dayResp in response.days {
            let date = Calendar.current.date(byAdding: .day, value: dayResp.dayIndex, to: monday) ?? monday
            let day  = MealPlanDay(date: date, dayIndex: dayResp.dayIndex)
            day.meals = [
                PlannedMeal(from: dayResp.breakfast, mealType: .breakfast),
                PlannedMeal(from: dayResp.lunch,     mealType: .lunch),
                PlannedMeal(from: dayResp.dinner,    mealType: .dinner)
            ] + dayResp.snacks.map { PlannedMeal(from: $0, mealType: .snack) }
            day.plan = plan
        }
        currentPlan = plan
    }

    /// Log a planned meal to the user's diary as a real MealEntry.
    func logPlannedMeal(_ planned: PlannedMeal) {
        HapticService.notification(.success)
        let entry = MealEntry(
            manual: planned.name,
            calories: planned.calories,
            protein: planned.protein,
            carbs: planned.carbohydrates,
            fat: planned.fat,
            mealType: planned.mealType
        )
        entry.aiInsights = [planned.mealDescription]
        entry.logSource = "plan"
        entry.user = user
        planned.isCompleted = true
        WidgetDataStore.save(user.widgetData)
        Task { @MainActor in
            LiveActivityService.shared.startOrUpdate(user: user)
        }
    }
}
