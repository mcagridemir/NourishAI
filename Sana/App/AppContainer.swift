// Sana — AppContainer.swift
// Dependency injection & SwiftData model container setup

import Foundation
import SwiftData

@MainActor
final class AppContainer {

    static let shared = AppContainer()

    let modelContainer: ModelContainer
    private(set) var storageIsTemporary = false
    let claude = ClaudeService.shared
    let healthKit = HealthKitService.shared
    let subscription = SubscriptionService.shared
    let notifications = NotificationService.shared

    private init() {
        let schema = Schema([User.self, MealEntry.self, MealPlan.self,
                             MealPlanDay.self, PlannedMeal.self,
                             ChatMessage.self, GroceryList.self,
                             WaterEntry.self, WeightEntry.self,
                             Supplement.self, SupplementLog.self])

        // CloudKit sync: flip BackendConfig.cloudKitEnabled to true once your
        // Apple Developer account is fully activated (can take 24-48h after first activation).
        let config = BackendConfig.cloudKitEnabled
            ? ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            : ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            modelContainer = container
        } else {
            // Schema changed — wipe and retry with a fresh local store
            Self.wipeSQLiteStore()
            if let container = try? ModelContainer(for: schema, configurations: [config]) {
                modelContainer = container
            } else {
                // Last resort: in-memory so the app never crashes on launch
                let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                modelContainer = try! ModelContainer(for: schema, configurations: [fallback])
                storageIsTemporary = true
            }
        }
    }

    private static func wipeSQLiteStore() {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let files = (try? FileManager.default.contentsOfDirectory(at: support, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "sqlite"
            || url.lastPathComponent.hasSuffix("-shm")
            || url.lastPathComponent.hasSuffix("-wal") {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // Fetch or create the current user
    func currentUser(in context: ModelContext) -> User? {
        let descriptor = FetchDescriptor<User>(sortBy: [SortDescriptor(\.createdAt)])
        return try? context.fetch(descriptor).first
    }
}
