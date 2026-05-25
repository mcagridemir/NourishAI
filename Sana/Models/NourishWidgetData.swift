// Sana — SanaWidgetData.swift
// Shared between app target and widget extension target.
import Foundation

struct SanaWidgetData: Codable {
    var calories: Int
    var calorieTarget: Int
    var waterMl: Int
    var waterGoalMl: Int
    var streak: Int
    var protein: Double
    var proteinTarget: Double
    var updatedAt: Date
    var isImperial: Bool = false

    static let placeholder = SanaWidgetData(
        calories: 0, calorieTarget: 2000,
        waterMl: 0, waterGoalMl: 2000,
        streak: 0,
        protein: 0, proteinTarget: 120,
        updatedAt: .now
    )

    var calorieProgress: Double { min(1.0, Double(calories) / Double(max(1, calorieTarget))) }
    var waterProgress: Double { min(1.0, Double(waterMl) / Double(max(1, waterGoalMl))) }
    var proteinProgress: Double { min(1.0, protein / max(1, proteinTarget)) }
    var caloriesRemaining: Int { max(0, calorieTarget - calories) }

    func formatWater(_ ml: Int) -> String {
        if isImperial {
            return String(format: "%.0f fl oz", Double(ml) * 0.033814)
        }
        return ml >= 1000 ? String(format: "%.1fL", Double(ml) / 1000) : "\(ml) ml"
    }
}
