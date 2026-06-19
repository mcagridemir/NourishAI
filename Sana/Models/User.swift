//
//  User.swift
//  Sana
//
//  Created by cagri.demir on 23.05.2026.
//

import Foundation
import SwiftData

@Model
final class User {
    var id: UUID = UUID()
    var authID: String = ""     // links to AuthService userID (Apple sub, email_address, etc.)
    var name: String = ""
    var email: String = ""      // empty — canonical email lives in Keychain
    var avatarData: Data?
    var createdAt: Date = Date.now

    var dateOfBirth: Date?
    var biologicalSex: BiologicalSex = BiologicalSex.preferNotToSay
    var heightCm: Double = 170
    var weightKg: Double = 70
    var activityLevel: ActivityLevel = ActivityLevel.moderatelyActive

    var primaryGoal: NutritionGoal = NutritionGoal.eatHealthier
    var dailyCalorieTarget: Int = 2000
    var dailyProteinTarget: Double = 112
    var dailyCarbTarget: Double = 225
    var dailyFatTarget: Double = 65
    var dailyFiberTarget: Double = 30
    var useCustomMacros: Bool = false

    var dietaryStyle: DietaryStyle = DietaryStyle.noPreference
    var allergies: [String] = []
    var healthConditions: [String] = []
    var country: String = ""
    var dislikedFoods: [String] = []
    var cuisinePreferences: [String] = []

    var subscriptionTier: SubscriptionTier = SubscriptionTier.free
    var dailyAnalysisCount: Int = 0
    var lastAnalysisResetDate: Date = Date.now

    var dailyWaterGoalMl: Int = 2000

    /// Target weight in kg (0 = not set).
    var targetWeightKg: Double = 0
    /// Whether the user prefers metric (kg/cm) or imperial (lbs/ft+in) units.
    var unitSystem: UnitSystem = UnitSystem.metric

    // CloudKit requires all to-many relationships to be Optional
    @Relationship(deleteRule: .cascade) var mealEntries: [MealEntry]?
    @Relationship(deleteRule: .cascade) var mealPlans: [MealPlan]?
    @Relationship(deleteRule: .cascade) var chatMessages: [ChatMessage]?
    @Relationship(deleteRule: .cascade) var waterEntries: [WaterEntry]?
    @Relationship(deleteRule: .cascade) var weightEntries: [WeightEntry]?
    @Relationship(deleteRule: .cascade) var progressPhotos: [ProgressPhoto]?

    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: .now).year
    }

    var latestWeightKg: Double {
        (weightEntries ?? []).sorted { $0.loggedAt > $1.loggedAt }.first?.weightKg ?? weightKg
    }

    var weightChangeSinceStart: Double? {
        let sorted = (weightEntries ?? []).sorted { $0.loggedAt < $1.loggedAt }
        guard sorted.count >= 2, let first = sorted.first, let last = sorted.last else { return nil }
        return last.weightKg - first.weightKg
    }

    var todayWaterMl: Int {
        (waterEntries ?? [])
            .filter { Calendar.current.isDateInToday($0.loggedAt) }
            .reduce(0) { $0 + $1.amountMl }
    }

    var todayCalories: Int {
        (mealEntries ?? [])
            .filter { Calendar.current.isDateInToday($0.loggedAt) }
            .map { $0.calories }.reduce(0, +)
    }

    var todayProtein: Double {
        (mealEntries ?? [])
            .filter { Calendar.current.isDateInToday($0.loggedAt) }
            .map { $0.protein }.reduce(0, +)
    }

    var todayMealCount: Int {
        (mealEntries ?? []).filter { Calendar.current.isDateInToday($0.loggedAt) }.count
    }

    var currentStreak: Int {
        let cal = Calendar.current
        let loggedDays = Set((mealEntries ?? []).map { cal.startOfDay(for: $0.loggedAt) })
        var streak = 0
        var date = cal.startOfDay(for: .now)
        if !loggedDays.contains(date) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = yesterday
        }
        for _ in 0..<365 {
            if loggedDays.contains(date) {
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
        if dietaryStyle != .noPreference { parts.append(dietaryStyle.rawValue) }
        if !country.isEmpty { parts.append("from \(country)") }
        if !healthConditions.isEmpty { parts.append("health conditions: \(healthConditions.joined(separator: ", "))") }
        if !allergies.isEmpty { parts.append("allergies: \(allergies.joined(separator: ", "))") }
        if !dislikedFoods.isEmpty { parts.append("dislikes: \(dislikedFoods.joined(separator: ", "))") }
        return parts.joined(separator: " | ")
    }

    /// Auto-detect country name (English) from the current device locale.
    static var deviceCountry: String {
        guard let code = Locale.autoupdatingCurrent.region?.identifier else { return "" }
        return Locale(identifier: "en_US").localizedString(forRegionCode: code) ?? ""
    }

    // MARK: - Unit display helpers

    var weightUnit: String    { unitSystem == .metric ? "kg"    : "lbs"   }
    var smallWeightUnit: String { unitSystem == .metric ? "g"   : "oz"    }
    var waterUnit: String     { unitSystem == .metric ? "ml"   : "fl oz" }

    func formatWeight(_ kg: Double) -> String {
        unitSystem == .metric
            ? String(format: "%.1f kg", kg)
            : String(format: "%.1f lbs", kg * 2.20462)
    }
    var formattedCurrentWeight: String { formatWeight(latestWeightKg) }
    var formattedTargetWeight: String  { targetWeightKg > 0 ? formatWeight(targetWeightKg) : "" }

    var formattedHeight: String {
        if unitSystem == .metric { return "\(Int(heightCm)) cm" }
        let totalInches = Int(heightCm * 0.393701)
        return "\(totalInches / 12)'\(totalInches % 12)\""
    }

    /// Convert a value in the user's chosen weight unit back to kg.
    func weightInputToKg(_ v: Double) -> Double { unitSystem == .metric ? v : v / 2.20462 }
    /// Convert kg to the user's chosen weight unit value.
    func kgToWeightInput(_ kg: Double) -> Double { unitSystem == .metric ? kg : kg * 2.20462 }
    /// Slider step for weight input in the user's unit.
    var weightInputStep: Double { unitSystem == .metric ? 0.5 : 1.0 }
    /// Slider range for weight in the user's unit.
    var weightInputRange: ClosedRange<Double> {
        unitSystem == .metric ? 40...160 : 88...353
    }

    /// Convert a height value in the user's chosen unit to cm.
    func heightInputToCm(_ v: Double) -> Double { unitSystem == .metric ? v : v * 2.54 }
    /// Convert cm to the user's chosen height unit value.
    func cmToHeightInput(_ cm: Double) -> Double { unitSystem == .metric ? cm : cm / 2.54 }
    var heightInputStep: Double { unitSystem == .metric ? 1.0 : 1.0 }  // 1 cm or 1 inch
    var heightInputRange: ClosedRange<Double> {
        unitSystem == .metric ? 140...220 : 55...87  // 55–87 inches ≈ 4'7"–7'3"
    }
    var heightUnit: String { unitSystem == .metric ? "cm" : "in" }

    /// Format water volume for display.
    func formatWater(_ ml: Int) -> String {
        unitSystem == .metric
            ? "\(ml) ml"
            : String(format: "%.0f fl oz", Double(ml) * 0.033814)
    }

    // MARK: - Weight goal / deficit

    var hasWeightTarget: Bool { targetWeightKg > 0 && abs(targetWeightKg - latestWeightKg) > 0.1 }

    /// Estimated weekly weight change (kg) based on avg 7-day deficit vs calorie goal.
    /// Positive = weight loss, Negative = weight gain.
    var projectedWeeklyWeightChangeKg: Double {
        let cal = Calendar.current
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        let recent = (mealEntries ?? []).filter { $0.loggedAt > cutoff }
        guard !recent.isEmpty else { return 0 }
        let daysLogged = max(1, Set(recent.map { cal.startOfDay(for: $0.loggedAt) }).count)
        let avgDaily = Double(recent.map { $0.calories }.reduce(0, +)) / Double(daysLogged)
        let avgDeficit = Double(dailyCalorieTarget) - avgDaily
        return avgDeficit * 7 / 7700  // 7700 kcal ≈ 1 kg fat
    }

    /// How far along the user is from starting weight to target (0–1).
    var weightGoalProgress: Double {
        guard hasWeightTarget else { return 0 }
        let startWeight = weightKg   // original set in profile
        let totalChange = startWeight - targetWeightKg
        guard abs(totalChange) > 0.1 else { return 1 }
        let achieved    = startWeight - latestWeightKg
        return min(1, max(0, achieved / totalChange))
    }

    private var last7DaysMeals: [MealEntry] {
        let cutoff = Date.now.addingTimeInterval(-7 * 86400)
        return (mealEntries ?? []).filter { $0.loggedAt > cutoff }
    }

    var recentNutritionSummary: String {
        let last7 = last7DaysMeals
        guard !last7.isEmpty else { return "No recent meals logged" }
        let avgCal = last7.map { $0.calories }.reduce(0, +) / last7.count
        let avgProt = last7.map { $0.protein }.reduce(0.0, +) / Double(last7.count)
        return "Avg last 7 days: \(avgCal) kcal, \(String(format: "%.0f", avgProt))g protein"
    }

    var detectedDeficiencies: [String] {
        let last7 = last7DaysMeals
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
        let cutoff = Date.now.addingTimeInterval(-7 * 86400)
        let last7 = last7DaysMeals
        let count = last7.count
        let daysSet = Set(last7.map { cal.startOfDay(for: $0.loggedAt) })
        let days = max(1, daysSet.count)
        let avgCal   = count == 0 ? 0 : last7.map { $0.calories }.reduce(0, +) / count
        let avgProt  = count == 0 ? 0 : Int(last7.map { $0.protein }.reduce(0, +)) / count
        let avgCarb  = count == 0 ? 0 : Int(last7.map { $0.carbohydrates }.reduce(0, +)) / count
        let avgFat   = count == 0 ? 0 : Int(last7.map { $0.fat }.reduce(0, +)) / count
        let avgScore = count == 0 ? 0 : last7.map { $0.healthScore }.reduce(0, +) / count

        let waterByDay = Dictionary(grouping: (waterEntries ?? []).filter { $0.loggedAt > cutoff }) {
            cal.startOfDay(for: $0.loggedAt)
        }
        let waterHitDays = waterByDay.filter { _, entries in
            entries.map { $0.amountMl }.reduce(0, +) >= dailyWaterGoalMl
        }.count

        return WeeklyStats(avgCalories: avgCal, avgProtein: avgProt, avgCarbs: avgCarb,
                           avgFat: avgFat, mealCount: count, daysTracked: days,
                           avgHealthScore: avgScore, waterGoalHitDays: waterHitDays)
    }

    var widgetData: SanaWidgetData {
        let todayMeals = (mealEntries ?? []).filter { Calendar.current.isDateInToday($0.loggedAt) }
        return SanaWidgetData(
            calories: todayMeals.map { $0.calories }.reduce(0, +),
            calorieTarget: dailyCalorieTarget,
            waterMl: todayWaterMl,
            waterGoalMl: dailyWaterGoalMl,
            streak: currentStreak,
            protein: todayMeals.map { $0.protein }.reduce(0, +),
            proteinTarget: dailyProteinTarget,
            carbs: todayMeals.map { $0.carbohydrates }.reduce(0, +),
            carbsTarget: dailyCarbTarget,
            fat: todayMeals.map { $0.fat }.reduce(0, +),
            fatTarget: dailyFatTarget,
            updatedAt: .now,
            isImperial: unitSystem == .imperial
        )
    }

    var nutritionContext: UserNutritionContext {
        let last7 = last7DaysMeals
        let count = last7.count
        let summary: String
        var deficiencies = [String]()
        if count == 0 {
            summary = "No recent meals logged"
        } else {
            let avgCal  = last7.map { $0.calories }.reduce(0, +) / count
            let avgProt = last7.map { $0.protein }.reduce(0.0, +) / Double(count)
            summary = "Avg last 7 days: \(avgCal) kcal, \(String(format: "%.0f", avgProt))g protein"
            if count >= 3 {
                let avgFiber = last7.map { $0.fiber }.reduce(0.0, +) / Double(count)
                if avgFiber < 20 { deficiencies.append("fiber") }
                if avgProt < dailyProteinTarget * 0.7 { deficiencies.append("protein") }
            }
        }
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        return UserNutritionContext(
            profileDescription: profileDescription,
            recentNutritionSummary: summary,
            detectedDeficiencies: deficiencies,
            allergies: allergies,
            healthConditions: healthConditions,
            country: country,
            dailyCalorieTarget: dailyCalorieTarget,
            language: langCode
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

    init(authID: String = "", name: String, email: String = "",
         dateOfBirth: Date? = nil,
         biologicalSex: BiologicalSex = .preferNotToSay,
         heightCm: Double = 170, weightKg: Double = 70,
         activityLevel: ActivityLevel = .moderatelyActive,
         primaryGoal: NutritionGoal = .eatHealthier,
         dietaryStyle: DietaryStyle = .noPreference,
         allergies: [String] = [],
         healthConditions: [String] = [],
         country: String = "",
         targetWeightKg: Double = 0) {
        self.id = UUID()
        self.authID = authID
        self.name = name
        self.email = email
        self.dateOfBirth = dateOfBirth
        self.biologicalSex = biologicalSex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
        self.primaryGoal = primaryGoal
        // Use full Mifflin-St Jeor when age is available, otherwise fall back to simple estimate
        let ageVal = dateOfBirth.flatMap { Calendar.current.dateComponents([.year], from: $0, to: .now).year }
        let calories: Int
        if let age = ageVal {
            calories = activityLevel.estimatedCalories(
                for: weightKg, heightCm: heightCm, age: age, sex: biologicalSex, goal: primaryGoal)
        } else {
            calories = activityLevel.estimatedCalories(for: weightKg, goal: primaryGoal)
        }
        self.dailyCalorieTarget = calories
        self.dailyProteinTarget = weightKg * 1.6
        self.dailyCarbTarget = Double(calories) * 0.45 / 4
        self.dailyFatTarget = Double(calories) * 0.30 / 9
        self.dailyFiberTarget = 30
        self.useCustomMacros = false
        self.dietaryStyle = dietaryStyle
        self.allergies = allergies
        self.healthConditions = healthConditions
        self.country = country.isEmpty ? User.deviceCountry : country
        self.targetWeightKg = targetWeightKg
        self.unitSystem = UnitSystem.deviceDefault
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
        self.progressPhotos = []
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
    /// Simple estimate (no age/height data).
    func estimatedCalories(for weightKg: Double, goal: NutritionGoal) -> Int {
        Int((10 * weightKg + 625) * multiplier + goal.calorieAdjustment)
    }

    /// Full Mifflin-St Jeor BMR using height, age, and biological sex.
    func estimatedCalories(for weightKg: Double, heightCm: Double, age: Int,
                           sex: BiologicalSex, goal: NutritionGoal) -> Int {
        let bmr: Double = sex == .female
            ? 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
            : 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        return max(1200, Int(bmr * multiplier + goal.calorieAdjustment))
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
    case noPreference  = "No preference"
    case omnivore      = "Omnivore"
    case vegetarian    = "Vegetarian"
    case vegan         = "Vegan"
    case pescatarian   = "Pescatarian"
    case keto          = "Keto"
    case paleo         = "Paleo"
    case mediterranean = "Mediterranean"
    case glutenFree    = "Gluten-free"
    case dairyFree     = "Dairy-free"
}

enum HealthCondition: String, Codable, CaseIterable {
    case type2Diabetes      = "Type 2 Diabetes"
    case type1Diabetes      = "Type 1 Diabetes"
    case prediabetes        = "Pre-diabetes"
    case anemia             = "Anemia"
    case hypertension       = "Hypertension"
    case highCholesterol    = "High Cholesterol"
    case celiacDisease      = "Celiac Disease"
    case lactoseIntolerance = "Lactose Intolerance"
    case ibs                = "IBS"
    case kidneyDisease      = "Kidney Disease"
    case thyroidDisorder    = "Thyroid Disorder"
    case pcos               = "PCOS"
    case heartDisease       = "Heart Disease"
    case gout               = "Gout"
    case osteoporosis       = "Osteoporosis"
}

enum SubscriptionTier: String, Codable { case free, premium }

enum UnitSystem: String, Codable {
    case metric   // kg, cm, ml
    case imperial // lbs, ft+in, fl oz

    /// Auto-detect from the device's Measurement System setting (Settings →
    /// General → Language & Region). This respects an explicit user choice and
    /// falls back to the locale's region; only the US system implies imperial.
    static var deviceDefault: UnitSystem {
        Locale.current.measurementSystem == .us ? .imperial : .metric
    }
}
