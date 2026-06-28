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
                             Supplement.self, SupplementLog.self,
                             ProgressPhoto.self])

        let cloudConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        // 1. Preferred: CloudKit sync (requires iCloud.com.cagri.Sana to be provisioned)
        if BackendConfig.cloudKitEnabled,
           let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
            modelContainer = container
            return
        }

        // 2. CloudKit unavailable / disabled — use persisted local store
        if let container = try? ModelContainer(for: schema, configurations: [localConfig]) {
            modelContainer = container
            return
        }

        // 3. Schema migration needed — wipe SQLite and retry local
        Self.wipeSQLiteStore()
        if let container = try? ModelContainer(for: schema, configurations: [localConfig]) {
            modelContainer = container
            return
        }

        // 4. Absolute last resort: in-memory (data lost on restart)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [memoryConfig])
            storageIsTemporary = true
        } catch {
            // Log the full error so we can diagnose schema issues in Xcode console
            print("❌ AppContainer: ALL configurations failed.")
            print("❌ Final error: \(error)")
            print("❌ Full detail: \(String(reflecting: error))")
            Self.diagnoseSchema()
            fatalError("AppContainer: could not create any ModelContainer — \(error)")
        }
    }

    /// Binary-search schema diagnostic: adds models one-by-one to pinpoint which
    /// model (or pair) causes the loadIssueModelContainer crash.
    private static func diagnoseSchema() {
        let allTypes: [any PersistentModel.Type] = [
            User.self, MealEntry.self, MealPlan.self,
            MealPlanDay.self, PlannedMeal.self,
            ChatMessage.self, GroceryList.self,
            WaterEntry.self, WeightEntry.self,
            Supplement.self, SupplementLog.self,
            ProgressPhoto.self
        ]
        let names = ["User", "MealEntry", "MealPlan",
                     "MealPlanDay", "PlannedMeal",
                     "ChatMessage", "GroceryList",
                     "WaterEntry", "WeightEntry",
                     "Supplement", "SupplementLog",
                     "ProgressPhoto"]
        print("🔍 Schema diagnostic — testing models one by one:")
        for i in 1...allTypes.count {
            let subset = Array(allTypes.prefix(i))
            let label  = Array(names.prefix(i)).joined(separator: " + ")
            do {
                let s = Schema(subset)
                let c = ModelConfiguration(schema: s, isStoredInMemoryOnly: true)
                _ = try ModelContainer(for: s, configurations: [c])
                print("  ✅ \(label)")
            } catch {
                print("  ❌ FAILED adding \(names[i-1])")
                print("  ❌ Combo: \(label)")
                print("  ❌ Error: \(error)")
                return
            }
        }
        print("  ⚠️ All pass individually — must be a combination issue")
    }

    /// Move the incompatible store aside (not delete) so a failed migration is
    /// recoverable rather than silently destroying the user's data. Keeps a
    /// single quarantine copy per file, overwriting any previous one.
    private static func wipeSQLiteStore() {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let files = (try? fm.contentsOfDirectory(at: support, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "sqlite"
            || url.lastPathComponent.hasSuffix("-shm")
            || url.lastPathComponent.hasSuffix("-wal") {
            let quarantine = url.appendingPathExtension("quarantine")
            try? fm.removeItem(at: quarantine)
            do {
                try fm.moveItem(at: url, to: quarantine)
            } catch {
                // If the move fails, fall back to removal so the app can still recover.
                try? fm.removeItem(at: url)
            }
        }
    }

    // Fetch or create the current user
    func currentUser(in context: ModelContext) -> User? {
        let descriptor = FetchDescriptor<User>(sortBy: [SortDescriptor(\.createdAt)])
        return try? context.fetch(descriptor).first
    }
}
