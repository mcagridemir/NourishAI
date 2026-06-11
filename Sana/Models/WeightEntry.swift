// Sana — WeightEntry.swift
import Foundation
import SwiftData

@Model
final class WeightEntry {
    var id: UUID = UUID()
    var loggedAt: Date = Date.now
    var weightKg: Double = 0

    @Relationship(inverse: \User.weightEntries)
    var user: User?

    init(weightKg: Double) {
        self.id = UUID()
        self.loggedAt = .now
        self.weightKg = weightKg
    }
}
