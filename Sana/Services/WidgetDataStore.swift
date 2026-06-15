// Sana — WidgetDataStore.swift
// Shared between app target and widget extension target.
import Foundation
import WidgetKit

nonisolated struct WidgetDataStore {

    static let appGroupID = "group.com.cagri.Sana"
    private static let key = "nourishWidgetData"

    static func save(_ data: SanaWidgetData) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load() -> SanaWidgetData {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let raw = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(SanaWidgetData.self, from: raw)
        else { return .placeholder }
        return decoded
    }
}
