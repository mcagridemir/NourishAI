// NourishAI — WaterEntry.swift
import Foundation
import SwiftData

@Model
final class WaterEntry {
    var id: UUID
    var loggedAt: Date
    var amountMl: Int

    @Relationship(inverse: \User.waterEntries)
    var user: User?

    init(amountMl: Int) {
        self.id = UUID()
        self.loggedAt = .now
        self.amountMl = amountMl
    }
}
