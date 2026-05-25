// Sana — WatchDataStore.swift
// Reads widget data from the shared App Group UserDefaults.
import Foundation

struct WatchWidgetData: Codable {
    var calories: Int
    var calorieTarget: Int
    var waterMl: Int
    var waterGoalMl: Int
    var streak: Int
    var protein: Double
    var proteinTarget: Double
    var isImperial: Bool = false

    static let placeholder = WatchWidgetData(
        calories: 0, calorieTarget: 2000,
        waterMl: 0, waterGoalMl: 2000,
        streak: 0, protein: 0, proteinTarget: 120
    )

    var calorieProgress: Double { min(1, Double(calories) / Double(max(1, calorieTarget))) }
    var waterProgress: Double   { min(1, Double(waterMl)  / Double(max(1, waterGoalMl))) }
    var proteinProgress: Double { min(1, protein / max(1, proteinTarget)) }
    var caloriesRemaining: Int  { max(0, calorieTarget - calories) }

    func formatWater(_ ml: Int) -> String {
        if isImperial {
            return String(format: "%.0f fl oz", Double(ml) * 0.033814)
        }
        return ml >= 1000 ? String(format: "%.1fL", Double(ml) / 1000) : "\(ml) ml"
    }
}

enum WatchDataStore {
    private static let appGroupID = "group.com.cagri.Sana"
    private static let dataKey    = "nourishWidgetData"
    private static let waterKey   = "siri.pendingWaterMl"

    static func load() -> WatchWidgetData {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let raw      = defaults.data(forKey: dataKey),
              let decoded  = try? JSONDecoder().decode(WatchWidgetData.self, from: raw)
        else { return .placeholder }
        return decoded
    }

    /// Queue a water log to be picked up by the iPhone app.
    static func logWater(_ ml: Int) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let current = defaults.integer(forKey: waterKey)
        defaults.set(current + ml, forKey: waterKey)
    }
}
