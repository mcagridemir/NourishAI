// Sana — WaterEntry.swift
import Foundation
import SwiftData

@Model
final class WaterEntry {
    var id: UUID = UUID()
    var loggedAt: Date = Date.now
    var amountMl: Int = 0

    @Relationship(inverse: \User.waterEntries)
    var user: User?

    init(amountMl: Int) {
        self.id = UUID()
        self.loggedAt = .now
        self.amountMl = amountMl
    }
}
