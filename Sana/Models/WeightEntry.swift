// Sana — WeightEntry.swift
import Foundation
import SwiftData

@Model
final class WeightEntry {
    var id: UUID
    var loggedAt: Date
    var weightKg: Double

    @Relationship(inverse: \User.weightEntries)
    var user: User?

    init(weightKg: Double) {
        self.id = UUID()
        self.loggedAt = .now
        self.weightKg = weightKg
    }
}
