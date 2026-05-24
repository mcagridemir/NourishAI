// NourishAI — WidgetDataStore.swift
// Shared between app target and widget extension target.
import Foundation
import WidgetKit

struct WidgetDataStore {

    static let appGroupID = "group.com.cagri.NourishAI"
    private static let key = "nourishWidgetData"

    static func save(_ data: NourishWidgetData) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load() -> NourishWidgetData {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let raw = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(NourishWidgetData.self, from: raw)
        else { return .placeholder }
        return decoded
    }
}
