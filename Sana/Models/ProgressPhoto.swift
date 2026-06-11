// Sana — ProgressPhoto.swift
import Foundation
import SwiftData

@Model
final class ProgressPhoto {
    var id: UUID = UUID()
    var takenAt: Date = Date.now
    var notes: String = ""
    var weightKg: Double = 0
    /// Relative path inside the app's Application Support directory.
    var relativePath: String = ""

    @Relationship(inverse: \User.progressPhotos)
    var user: User?

    init(relativePath: String, weightKg: Double, notes: String = "") {
        self.id = UUID()
        self.takenAt = .now
        self.relativePath = relativePath
        self.weightKg = weightKg
        self.notes = notes
    }

    var imageURL: URL? {
        guard !relativePath.isEmpty else { return nil }
        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(relativePath)
    }
}
