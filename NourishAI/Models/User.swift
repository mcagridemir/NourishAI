//
//  User.swift
//  NourishAI
//
//  Created by cagri.demir on 23.05.2026.
//

import Foundation
import SwiftData

@Model
final class User {
    var id: UUID
    var name: String
    var email: String
    var avatarData: Data?
    var createdAt: Date

    var dateOfBirth: Date?
    var biologicalSex: BiologicalSex
    var heightCm: Double
    var weightKg: Double
    var activityLevel: ActivityLevel

    var primaryGoal: NutritionGoal
    var dailyCalorieTarget: Int
    var dailyProteinTarget: Double
    var dailyCarbTarget: Double
    var dailyFatTarget: Double
    var dailyFiberTarget: Double

    var dietaryStyle: DietaryStyle
    var allergies: [String]
    var dislikedFoods: [String]
    var cuisinePreferences: [String]

    var subscriptionTier: SubscriptionTier
    var dailyAnalysisCount: Int
    var lastAnalysisResetDate: Date

    @Relationship(deleteRule: .cascade) var mealEntries: [MealEntry]
    @Relationship(deleteRule: .cascade) var mealPlans: [MealPlan]
    @Relationship(deleteRule: .cascade) var chatMessages: [ChatMessage]

    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: .now).year
    }

    var bmi: Double {
        guard heightCm > 0 else { return 0 }
        let h = heightCm / 100
        return weightKg / (h * h)
    }

    var profileDescription: String {
        var parts = [String]()
        if let age { parts.append("\(age)yo") }
        parts.append(biologicalSex.rawValue)
        parts.append("\(Int(weightKg))kg, \(Int(heightCm))cm")
        parts.append("BMI \(String(format: "%.1f", bmi))")
        parts.append(activityLevel.description)
        parts.append(primaryGoal.description)
        parts.append(dietaryStyle.rawValue)
        if !allergies.isEmpty { parts.append("allergies: \(allergies.joined(separator: ", "))") }
        if !dislikedFoods.isEmpty { parts.append("dislikes: \(dislikedFoods.joined(separator: ", "))") }
        return parts.joined(separator: " | ")
    }

    var recentNutritionSummary: String {
        let last7 = mealEntries.filter { $0.loggedAt > Date().addingTimeInterval(-7 * 86400) }
        guard !last7.isEmpty else { return "No recent meals logged" }
        let avgCal = last7.map { $0.calories }.reduce(0, +) / last7.count
        let avgProt = last7.map { $0.protein }.reduce(0.0, +) / Double(last7.count)
        return "Avg last 7 days: \(avgCal) kcal, \(String(format: "%.0f", avgProt))g protein"
    }

    var detectedDeficiencies: [String] {
        let last7 = mealEntries.filter { $0.loggedAt > Date().addingTimeInterval(-7 * 86400) }
        guard last7.count >= 3 else { return [] }
        var d = [String]()
        let avgFiber = last7.map { $0.fiber }.reduce(0.0, +) / Double(last7.count)
        if avgFiber < 20 { d.append("fiber") }
        let avgProt = last7.map { $0.protein }.reduce(0.0, +) / Double(last7.count)
        if avgProt < dailyProteinTarget * 0.7 { d.append("protein") }
        return d
    }

    var nutritionContext: UserNutritionContext {
        UserNutritionContext(
            profileDescription: profileDescription,
            recentNutritionSummary: recentNutritionSummary,
            detectedDeficiencies: detectedDeficiencies,
            allergies: allergies,
            dailyCalorieTarget: dailyCalorieTarget
        )
    }

    var canAnalyzeMeal: Bool {
        if subscriptionTier == .premium { return true }
        resetDailyCountIfNeeded()
        return dailyAnalysisCount < 5
    }

    var remainingFreeAnalyses: Int {
        resetDailyCountIfNeeded()
        return max(0, 5 - dailyAnalysisCount)
    }

    init(name: String, email: String, biologicalSex: BiologicalSex = .preferNotToSay,
         heightCm: Double = 170, weightKg: Double = 70,
         activityLevel: ActivityLevel = .moderatelyActive,
         primaryGoal: NutritionGoal = .eatHealthier,
         dietaryStyle: DietaryStyle = .omnivore, allergies: [String] = []) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.biologicalSex = biologicalSex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
        self.primaryGoal = primaryGoal
        let calories = activityLevel.estimatedCalories(for: weightKg, goal: primaryGoal)
        self.dailyCalorieTarget = calories
        self.dailyProteinTarget = weightKg * 1.6
        self.dailyCarbTarget = Double(calories) * 0.45 / 4
        self.dailyFatTarget = Double(calories) * 0.30 / 9
        self.dailyFiberTarget = 30
        self.dietaryStyle = dietaryStyle
        self.allergies = allergies
        self.dislikedFoods = []
        self.cuisinePreferences = []
        self.subscriptionTier = .free
        self.dailyAnalysisCount = 0
        self.lastAnalysisResetDate = .now
        self.createdAt = .now
        self.mealEntries = []
        self.mealPlans = []
        self.chatMessages = []
    }

    private func resetDailyCountIfNeeded() {
        if !Calendar.current.isDateInToday(lastAnalysisResetDate) {
            dailyAnalysisCount = 0
            lastAnalysisResetDate = .now
        }
    }
}

enum BiologicalSex: String, Codable, CaseIterable {
    case male = "Male"; case female = "Female"; case preferNotToSay = "Prefer not to say"
}

enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary = "Sedentary"
    case lightlyActive = "Lightly active"
    case moderatelyActive = "Moderately active"
    case veryActive = "Very active"
    case extraActive = "Extra active"
    var description: String { rawValue.lowercased() }
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2; case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55; case .veryActive: return 1.725
        case .extraActive: return 1.9
        }
    }
    func estimatedCalories(for weightKg: Double, goal: NutritionGoal) -> Int {
        Int((10 * weightKg + 625) * multiplier + goal.calorieAdjustment)
    }
}

enum NutritionGoal: String, Codable, CaseIterable {
    case loseWeight = "Lose weight"; case eatHealthier = "Eat healthier"
    case buildMuscle = "Build muscle"; case maintainWeight = "Maintain weight"
    case improveEnergy = "Improve energy"; case manageCondition = "Manage a condition"
    var description: String { rawValue.lowercased() }
    var calorieAdjustment: Double {
        switch self { case .loseWeight: return -500; case .buildMuscle: return 300; default: return 0 }
    }
}

enum DietaryStyle: String, Codable, CaseIterable {
    case omnivore = "Omnivore"; case vegetarian = "Vegetarian"; case vegan = "Vegan"
    case pescatarian = "Pescatarian"; case keto = "Keto"; case paleo = "Paleo"
    case mediterranean = "Mediterranean"; case glutenFree = "Gluten-free"; case dairyFree = "Dairy-free"
}

enum SubscriptionTier: String, Codable { case free, premium }
