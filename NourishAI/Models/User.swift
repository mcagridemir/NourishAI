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
    var useCustomMacros: Bool

    var dietaryStyle: DietaryStyle
    var allergies: [String]
    var dislikedFoods: [String]
    var cuisinePreferences: [String]

    var subscriptionTier: SubscriptionTier
    var dailyAnalysisCount: Int
    var lastAnalysisResetDate: Date

    var dailyWaterGoalMl: Int

    @Relationship(deleteRule: .cascade) var mealEntries: [MealEntry]
    @Relationship(deleteRule: .cascade) var mealPlans: [MealPlan]
    @Relationship(deleteRule: .cascade) var chatMessages: [ChatMessage]
    @Relationship(deleteRule: .cascade) var waterEntries: [WaterEntry]
    @Relationship(deleteRule: .cascade) var weightEntries: [WeightEntry]

    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: .now).year
    }

    var latestWeightKg: Double {
        weightEntries.sorted { $0.loggedAt > $1.loggedAt }.first?.weightKg ?? weightKg
    }

    var weightChangeSinceStart: Double? {
        guard let first = weightEntries.sorted(by: { $0.loggedAt < $1.loggedAt }).first,
              let last = weightEntries.sorted(by: { $0.loggedAt > $1.loggedAt }).first,
              first.id != last.id else { return nil }
        return last.weightKg - first.weightKg
    }

    var todayWaterMl: Int {
        waterEntries
            .filter { Calendar.current.isDateInToday($0.loggedAt) }
            .reduce(0) { $0 + $1.amountMl }
    }

    var todayCalories: Int {
        mealEntries
            .filter { Calendar.current.isDateInToday($0.loggedAt) }
            .map { $0.calories }.reduce(0, +)
    }

    var todayProtein: Double {
        mealEntries
            .filter { Calendar.current.isDateInToday($0.loggedAt) }
            .map { $0.protein }.reduce(0, +)
    }

    var todayMealCount: Int {
        mealEntries.filter { Calendar.current.isDateInToday($0.loggedAt) }.count
    }

    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var date = Date.now.startOfDay
        let todayHasEntry = mealEntries.contains { cal.isDate($0.loggedAt, inSameDayAs: date) }
        if !todayHasEntry {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = yesterday
        }
        for _ in 0..<365 {
            let hasEntry = mealEntries.contains { cal.isDate($0.loggedAt, inSameDayAs: date) }
            if hasEntry {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
            } else { break }
        }
        return streak
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

    var weeklyStats: WeeklyStats {
        let cal = Calendar.current
        let last7 = mealEntries.filter { $0.loggedAt > Date().addingTimeInterval(-7 * 86400) }
        let count = last7.count
        let daysSet = Set(last7.map { cal.startOfDay(for: $0.loggedAt) })
        let days = max(1, daysSet.count)
        let avgCal  = count == 0 ? 0 : last7.map { $0.calories }.reduce(0, +) / count
        let avgProt = count == 0 ? 0 : Int(last7.map { $0.protein }.reduce(0, +)) / count
        let avgCarb = count == 0 ? 0 : Int(last7.map { $0.carbohydrates }.reduce(0, +)) / count
        let avgFat  = count == 0 ? 0 : Int(last7.map { $0.fat }.reduce(0, +)) / count
        let avgScore = count == 0 ? 0 : last7.map { $0.healthScore }.reduce(0, +) / count

        // Count days where water goal was met
        let waterByDay = Dictionary(grouping: waterEntries.filter { $0.loggedAt > Date().addingTimeInterval(-7 * 86400) }) {
            cal.startOfDay(for: $0.loggedAt)
        }
        let waterHitDays = waterByDay.filter { _, entries in
            entries.map { $0.amountMl }.reduce(0, +) >= dailyWaterGoalMl
        }.count

        return WeeklyStats(avgCalories: avgCal, avgProtein: avgProt, avgCarbs: avgCarb,
                           avgFat: avgFat, mealCount: count, daysTracked: days,
                           avgHealthScore: avgScore, waterGoalHitDays: waterHitDays)
    }

    var widgetData: NourishWidgetData {
        let todayMeals = mealEntries.filter { Calendar.current.isDateInToday($0.loggedAt) }
        return NourishWidgetData(
            calories: todayMeals.map { $0.calories }.reduce(0, +),
            calorieTarget: dailyCalorieTarget,
            waterMl: todayWaterMl,
            waterGoalMl: dailyWaterGoalMl,
            streak: currentStreak,
            protein: todayMeals.map { $0.protein }.reduce(0, +),
            proteinTarget: dailyProteinTarget,
            updatedAt: .now
        )
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
        self.useCustomMacros = false
        self.dietaryStyle = dietaryStyle
        self.allergies = allergies
        self.dislikedFoods = []
        self.cuisinePreferences = []
        self.subscriptionTier = .free
        self.dailyAnalysisCount = 0
        self.lastAnalysisResetDate = .now
        self.dailyWaterGoalMl = 2000
        self.createdAt = .now
        self.mealEntries = []
        self.mealPlans = []
        self.chatMessages = []
        self.waterEntries = []
        self.weightEntries = []
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
