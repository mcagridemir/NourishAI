// NourishAI — MealPlanViewModel.swift
import Foundation
import SwiftData
internal import Combine

@MainActor
final class MealPlanViewModel: ObservableObject {

    @Published var currentPlan: MealPlan?
    @Published var isGenerating = false
    @Published var error: String?

    let user: User

    init(user: User) { self.user = user }

    func loadExistingPlan() {
        currentPlan = user.mealPlans
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
            let plan = MealPlan(weekStartDate: monday)
            plan.user = user

            for dayResp in response.days {
                let date = Calendar.current.date(byAdding: .day, value: dayResp.dayIndex, to: monday) ?? monday
                let day = MealPlanDay(date: date, dayIndex: dayResp.dayIndex)
                day.breakfastMeal = PlannedMeal(from: dayResp.breakfast, mealType: .breakfast)
                day.lunchMeal     = PlannedMeal(from: dayResp.lunch,     mealType: .lunch)
                day.dinnerMeal    = PlannedMeal(from: dayResp.dinner,    mealType: .dinner)
                day.snackMeals    = dayResp.snacks.map { PlannedMeal(from: $0, mealType: .snack) }
                plan.days.append(day)
            }

            // Deactivate old plans
            user.mealPlans.forEach { $0.isActive = false }
            user.mealPlans.append(plan)
            currentPlan = plan
        } catch {
            self.error = error.localizedDescription
            print("❌ Meal plan error: \(error)")
        }
    }
}
