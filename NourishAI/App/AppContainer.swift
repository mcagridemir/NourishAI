// NourishAI — AppContainer.swift
// Dependency injection & SwiftData model container setup

import Foundation
import SwiftData

@MainActor
final class AppContainer {

    static let shared = AppContainer()

    let modelContainer: ModelContainer
    let claude = ClaudeService.shared
    let healthKit = HealthKitService.shared
    let subscription = SubscriptionService.shared
    let notifications = NotificationService.shared

    private init() {
        let schema = Schema([User.self, MealEntry.self, MealPlan.self,
                             MealPlanDay.self, PlannedMeal.self,
                             ChatMessage.self, GroceryList.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    // Fetch or create the current user
    func currentUser(in context: ModelContext) -> User? {
        let descriptor = FetchDescriptor<User>(sortBy: [SortDescriptor(\.createdAt)])
        return try? context.fetch(descriptor).first
    }
}
