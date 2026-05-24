// Sana — SanaActivityAttributes.swift
// Add this file to both the main app target AND the widget extension target.
import ActivityKit
import Foundation

struct SanaActivityAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable {
        var calories: Int
        var calorieTarget: Int
        var waterMl: Int
        var waterGoalMl: Int
        var protein: Double
        var proteinTarget: Double
        var mealCount: Int
        var streak: Int

        var calorieProgress: Double { min(1.0, Double(calories) / Double(max(1, calorieTarget))) }
        var waterProgress: Double   { min(1.0, Double(waterMl) / Double(max(1, waterGoalMl))) }
        var proteinProgress: Double { min(1.0, protein / max(1, proteinTarget)) }
        var caloriesRemaining: Int  { max(0, calorieTarget - calories) }
    }

    var userName: String
}
