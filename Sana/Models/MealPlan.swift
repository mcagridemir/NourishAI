//
//  MealPlan.swift
//  Sana
//
//  Created by cagri.demir on 23.05.2026.
//

import Foundation
import SwiftData

@Model
final class MealPlan {
    var id: UUID
    var createdAt: Date
    var weekStartDate: Date
    var title: String
    var isActive: Bool

    @Relationship(deleteRule: .cascade)
    var days: [MealPlanDay]

    @Relationship(inverse: \User.mealPlans)
    var user: User?

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
    }

    var totalCaloriesAverage: Int {
        guard !days.isEmpty else { return 0 }
        return days.map { $0.totalCalories }.reduce(0, +) / days.count
    }

    var groceryItems: [GroceryItem] {
        days.flatMap { $0.allMeals }.flatMap { $0.ingredients }
            .map { GroceryItem(name: $0, quantity: 1, unit: "serving") }
    }

    init(weekStartDate: Date, title: String = "Weekly Plan") {
        self.id = UUID()
        self.createdAt = .now
        self.weekStartDate = weekStartDate
        self.title = title
        self.isActive = true
        self.days = []
    }
}

@Model
final class MealPlanDay {
    var id: UUID
    var date: Date
    var dayIndex: Int    // 0 = Monday

    // Single relationship to PlannedMeal — multiple optional @Relationships to the
    // same @Model type without inverses breaks SwiftData's schema validation.
    // Use PlannedMeal.mealType to distinguish breakfast / lunch / dinner / snack.
    @Relationship(deleteRule: .cascade) var meals: [PlannedMeal]

    var plan: MealPlan?

    // Computed accessors — call sites stay the same
    var breakfastMeal: PlannedMeal? { meals.first { $0.mealType == .breakfast } }
    var lunchMeal: PlannedMeal?     { meals.first { $0.mealType == .lunch     } }
    var dinnerMeal: PlannedMeal?    { meals.first { $0.mealType == .dinner    } }
    var snackMeals: [PlannedMeal]   { meals.filter { $0.mealType == .snack   } }

    var totalCalories: Int { meals.map { $0.calories }.reduce(0, +) }
    var allMeals: [PlannedMeal] { meals }

    var dayName: String {
        date.formatted(.dateTime.weekday(.wide))
    }

    init(date: Date, dayIndex: Int) {
        self.id = UUID()
        self.date = date
        self.dayIndex = dayIndex
        self.meals = []
    }
}

@Model
final class PlannedMeal {
    var id: UUID
    var name: String
    var mealDescription: String
    var prepTimeMinutes: Int
    var calories: Int
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var ingredients: [String]
    var recipeSteps: String
    var isCompleted: Bool   // user ticked it off
    var mealType: MealType

    init(from suggestion: MealSuggestion, mealType: MealType) {
        self.id = UUID()
        self.name = suggestion.name
        self.mealDescription = suggestion.description
        self.prepTimeMinutes = suggestion.prepTime
        self.calories = suggestion.calories
        self.protein = suggestion.protein
        self.carbohydrates = suggestion.carbohydrates
        self.fat = suggestion.fat
        self.ingredients = suggestion.ingredients
        self.recipeSteps = suggestion.recipe
        self.isCompleted = false
        self.mealType = mealType
    }
}
