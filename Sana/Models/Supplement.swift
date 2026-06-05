// Sana — Supplement.swift
import Foundation
import SwiftData

@Model
final class Supplement {
    var id: UUID
    var name: String
    var dosage: Double        // numeric amount
    var unit: String          // "mg", "mcg", "IU", "g", "tablet"
    var frequency: String     // "Daily", "Twice daily", "Weekly"
    var timeOfDay: String     // "Morning", "Afternoon", "Evening", "With meals"
    var notes: String
    var isActive: Bool
    var createdAt: Date
    var color: String         // hex string for tint

    @Relationship(deleteRule: .cascade, inverse: \SupplementLog.supplement) var logs: [SupplementLog]

    var dosageDisplay: String {
        let d = dosage == dosage.rounded() ? "\(Int(dosage))" : String(format: "%.1f", dosage)
        return "\(d) \(unit)"
    }

    var isLoggedToday: Bool {
        logs.contains { Calendar.current.isDateInToday($0.loggedAt) }
    }

    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var date = cal.startOfDay(for: .now)
        if !isLoggedToday {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = yesterday
        }
        for _ in 0..<365 {
            let hasLog = logs.contains { cal.isDate($0.loggedAt, inSameDayAs: date) }
            if hasLog {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
            } else { break }
        }
        return streak
    }

    init(name: String, dosage: Double, unit: String,
         frequency: String = "Daily", timeOfDay: String = "Morning",
         notes: String = "", color: String = "#2D9E75") {
        self.id = UUID()
        self.name = name
        self.dosage = dosage
        self.unit = unit
        self.frequency = frequency
        self.timeOfDay = timeOfDay
        self.notes = notes
        self.isActive = true
        self.createdAt = .now
        self.color = color
        self.logs = []
    }
}

@Model
final class SupplementLog {
    var id: UUID
    var loggedAt: Date

    // Back-reference required by Core Data / SwiftData for relationship inverse resolution.
    var supplement: Supplement?

    init() {
        self.id = UUID()
        self.loggedAt = .now
    }
}
