// Sana — GroceryListViewModel.swift
import Foundation
import SwiftUI
internal import Combine

@MainActor
final class GroceryListViewModel: ObservableObject {

    @Published var sections: [GrocerySection] = []
    @Published var isGenerating = false
    @Published var error: String?
    @Published var showPaywall = false

    private let user: User

    init(user: User) {
        self.user = user
    }

    var checkedCount: Int { sections.flatMap { $0.items }.filter { $0.isChecked }.count }
    var totalCount: Int { sections.flatMap { $0.items }.count }
    var progress: Double { guard totalCount > 0 else { return 0 }; return Double(checkedCount) / Double(totalCount) }

    // MARK: - Persistence helpers

    private var activePlanKey: String? {
        guard let plan = user.mealPlans?.first(where: { $0.isActive }) else { return nil }
        return "groceryList.\(plan.id.uuidString)"
    }

    func loadList() {
        guard let key = activePlanKey,
              let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([GrocerySection].self, from: data)
        else { return }
        sections = saved
    }

    func saveCurrentState() {
        guard let key = activePlanKey,
              let data = try? JSONEncoder().encode(sections) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func generate() async {
        guard let plan = user.mealPlans?.first(where: { $0.isActive }) else { return }
        isGenerating = true
        defer { isGenerating = false }
        do {
            let planResp = MealPlanResponse(days: (plan.days ?? []).sorted { $0.dayIndex < $1.dayIndex }.compactMap { day -> MealPlanDayResponse? in
                guard let b = day.breakfastMeal, let l = day.lunchMeal, let d = day.dinnerMeal else { return nil }
                return MealPlanDayResponse(dayIndex: day.dayIndex,
                    breakfast: MealSuggestion(name: b.name, description: b.mealDescription, prepTime: b.prepTimeMinutes, calories: b.calories, protein: b.protein, carbohydrates: b.carbohydrates, fat: b.fat, ingredients: b.ingredients, recipe: b.recipeSteps),
                    lunch: MealSuggestion(name: l.name, description: l.mealDescription, prepTime: l.prepTimeMinutes, calories: l.calories, protein: l.protein, carbohydrates: l.carbohydrates, fat: l.fat, ingredients: l.ingredients, recipe: l.recipeSteps),
                    dinner: MealSuggestion(name: d.name, description: d.mealDescription, prepTime: d.prepTimeMinutes, calories: d.calories, protein: d.protein, carbohydrates: d.carbohydrates, fat: d.fat, ingredients: d.ingredients, recipe: d.recipeSteps),
                    snacks: day.snackMeals.map { MealSuggestion(name: $0.name, description: $0.mealDescription, prepTime: $0.prepTimeMinutes, calories: $0.calories, protein: $0.protein, carbohydrates: $0.carbohydrates, fat: $0.fat, ingredients: $0.ingredients, recipe: $0.recipeSteps) },
                    totalCalories: day.totalCalories)
            })
            sections = try await ClaudeService.shared.generateGroceryList(from: planResp, language: user.nutritionContext.language)
            saveCurrentState()
        } catch ClaudeError.quotaExceeded {
            showPaywall = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func uncheckAll() {
        for i in sections.indices {
            for j in sections[i].items.indices {
                sections[i].items[j].isChecked = false
            }
        }
        saveCurrentState()
    }

    func shareList() {
        let text = sections.map { s in
            "**\(s.category)**\n" + s.items.map { "- \($0.formattedQuantity) \($0.name)" }.joined(separator: "\n")
        }.joined(separator: "\n\n")
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let vc = scene.keyWindow?.rootViewController {
            vc.present(av, animated: true)
        }
    }
}
