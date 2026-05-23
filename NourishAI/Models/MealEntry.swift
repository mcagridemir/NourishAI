//
//  MealEntry.swift
//  NourishAI
//
//  Created by cagri.demir on 23.05.2026.
//

import Foundation
import SwiftData

@Model
final class MealEntry {
    var id: UUID
    var loggedAt: Date
    var mealType: MealType
    var photoData: Data?
    var mealName: String
    var estimatedPortionSize: String

    // Macros
    var calories: Int
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var sodium: Double

    // Micros (stored as JSON string for flexibility)
    var vitaminsJSON: String
    var mineralsJSON: String

    // AI metadata
    var healthScore: Int          // 0-100
    var aiInsights: [String]
    var aiSuggestions: [String]
    var confidence: Double        // 0-1 how sure Claude was
    var isManualEntry: Bool

    // Notes
    var userNotes: String

    @Relationship(inverse: \User.mealEntries)
    var user: User?

    // Computed
    var vitamins: [String: Double] {
        get { (try? JSONDecoder().decode([String: Double].self, from: Data(vitaminsJSON.utf8))) ?? [:] }
        set { vitaminsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "{}" }
    }

    var minerals: [String: Double] {
        get { (try? JSONDecoder().decode([String: Double].self, from: Data(mineralsJSON.utf8))) ?? [:] }
        set { mineralsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "{}" }
    }

    var formattedDate: String {
        loggedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var macroBreakdown: MacroBreakdown {
        let proteinCal = protein * 4
        let carbCal = carbohydrates * 4
        let fatCal = fat * 9
        let total = proteinCal + carbCal + fatCal
        guard total > 0 else { return MacroBreakdown(proteinPct: 0, carbPct: 0, fatPct: 0) }
        return MacroBreakdown(
            proteinPct: proteinCal / total,
            carbPct: carbCal / total,
            fatPct: fatCal / total
        )
    }

    var healthScoreColor: String {
        switch healthScore {
        case 75...100: return "green"
        case 50..<75:  return "yellow"
        default:       return "red"
        }
    }

    init(from analysis: NutritionAnalysis, mealType: MealType = .snack, photoData: Data? = nil) {
        self.id = UUID()
        self.loggedAt = .now
        self.mealType = mealType
        self.photoData = photoData
        self.mealName = analysis.mealName
        self.estimatedPortionSize = analysis.estimatedPortionSize
        self.calories = analysis.calories
        self.protein = analysis.protein
        self.carbohydrates = analysis.carbohydrates
        self.fat = analysis.fat
        self.fiber = analysis.fiber
        self.sugar = analysis.sugar
        self.sodium = analysis.sodium
        self.vitaminsJSON = (try? String(data: JSONEncoder().encode(analysis.vitamins), encoding: .utf8)) ?? "{}"
        self.mineralsJSON = (try? String(data: JSONEncoder().encode(analysis.minerals), encoding: .utf8)) ?? "{}"
        self.healthScore = analysis.healthScore
        self.aiInsights = analysis.insights
        self.aiSuggestions = analysis.suggestions
        self.confidence = analysis.confidence
        self.isManualEntry = false
        self.userNotes = ""
    }

    init(manual name: String, calories: Int, protein: Double, carbs: Double, fat: Double, mealType: MealType) {
        self.id = UUID()
        self.loggedAt = .now
        self.mealType = mealType
        self.mealName = name
        self.estimatedPortionSize = "1 serving"
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbs
        self.fat = fat
        self.fiber = 0
        self.sugar = 0
        self.sodium = 0
        self.vitaminsJSON = "{}"
        self.mineralsJSON = "{}"
        self.healthScore = 50
        self.aiInsights = []
        self.aiSuggestions = []
        self.confidence = 1.0
        self.isManualEntry = true
        self.userNotes = ""
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    case drink = "Drink"

    var icon: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .snack: return "leaf"
        case .drink: return "drop"
        }
    }

    var defaultTime: Date {
        let cal = Calendar.current
        let h: Int
        switch self {
        case .breakfast: h = 8; case .lunch: h = 12
        case .dinner: h = 19; case .snack: h = 15; case .drink: h = 10
        }
        return cal.date(bySettingHour: h, minute: 0, second: 0, of: .now) ?? .now
    }
}

struct MacroBreakdown {
    let proteinPct: Double
    let carbPct: Double
    let fatPct: Double
}
