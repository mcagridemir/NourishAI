// Sana — UITestSupport.swift
//
// Test-only launch hooks. This whole file is compiled out of release builds
// (`#if DEBUG`), so none of this scaffolding ships in the App Store binary.
#if DEBUG
import Foundation
import SwiftData

enum UITestSupport {

    /// Active when the XCUITest runner launches with "-uitest" (smoke tests,
    /// empty user) or "-uitest-demo" (screenshot runs, populated user).
    static var isActive: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-uitest") || args.contains("-uitest-demo")
    }

    private static var seedsDemoData: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitest-demo")
    }

    /// Seed a User so the app lands on the dashboard (skipping Firebase auth +
    /// onboarding). Smoke tests get an empty user; "-uitest-demo" gets a
    /// populated one so marketing screenshots aren't empty.
    @MainActor
    static func seedIfNeeded(context: ModelContext, existing: [User]) {
        guard isActive else { return }
        if seedsDemoData {
            // Reseed fresh on every launch: the screenshot test relaunches the
            // app per locale against the same store, so a stale user would pin
            // the first locale's units/data onto all the others.
            for user in existing { context.delete(user) }
            seedDemoUser(into: context)
        } else if existing.isEmpty {
            context.insert(User(name: "Test User"))
        }
    }

    @MainActor
    private static func seedDemoUser(into context: ModelContext) {
        let user = User(name: "Alex",
                        heightCm: 178, weightKg: 74,
                        country: "United States",
                        targetWeightKg: 70)
        // Screenshot runs pass "-demo-units metric|imperial" so each locale's
        // shots use the right units regardless of the simulator's setting.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-demo-units"), i + 1 < args.count {
            user.unitSystem = args[i + 1] == "imperial" ? .imperial : .metric
        }
        let meals = [
            MealEntry(manual: "Greek yogurt & berries", calories: 320, protein: 24, carbs: 38, fat: 8,  mealType: .breakfast),
            MealEntry(manual: "Grilled chicken salad",  calories: 480, protein: 42, carbs: 26, fat: 21, mealType: .lunch),
            MealEntry(manual: "Salmon, quinoa & greens", calories: 610, protein: 39, carbs: 48, fat: 27, mealType: .dinner),
            MealEntry(manual: "Almonds",                calories: 160, protein: 6,  carbs: 6,  fat: 14, mealType: .snack),
        ]
        user.mealEntries = meals
        context.insert(user)
        for meal in meals { context.insert(meal) }
    }
}
#endif
