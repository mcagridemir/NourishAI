// Sana — UserModelTests.swift
import Testing
import SwiftData
import Foundation
@testable import Sana

// MARK: - Helpers

private func makeContainer() throws -> ModelContainer {
    let schema = Schema([
        User.self, MealEntry.self, MealPlan.self, MealPlanDay.self,
        PlannedMeal.self, ChatMessage.self, GroceryList.self,
        WaterEntry.self, WeightEntry.self, Supplement.self, SupplementLog.self
    ])
    return try ModelContainer(for: schema,
                              configurations: ModelConfiguration(isStoredInMemoryOnly: true))
}

private func meal(daysAgo: Int = 0, calories: Int = 500,
                  protein: Double = 30, fiber: Double = 10,
                  type: MealType = .lunch) -> MealEntry {
    let m = MealEntry(manual: "Test meal", calories: calories,
                      protein: protein, carbs: 50, fat: 15, mealType: type)
    if daysAgo != 0 {
        m.loggedAt = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
    }
    m.fiber = fiber
    return m
}

// MARK: - BMI

@Suite("BMI")
struct BMITests {

    @Test("standard case")
    func standard() {
        let user = User(name: "Test", heightCm: 175, weightKg: 70)
        #expect(abs(user.bmi - 22.857) < 0.001)
    }

    @Test("returns 0 for zero height")
    func zeroHeight() {
        let user = User(name: "Test", heightCm: 0, weightKg: 70)
        #expect(user.bmi == 0)
    }

    @Test("obese range (BMI > 30)")
    func obese() {
        let user = User(name: "Test", heightCm: 170, weightKg: 100)
        #expect(user.bmi > 30)
    }
}

// MARK: - Calorie & macro targets

@Suite("Calorie estimation")
struct CalorieEstimationTests {

    @Test("moderately active, maintain weight")
    func moderatelyActiveMaintain() {
        // (10*70 + 625) * 1.55 + 0 = 1325 * 1.55 = 2053.75 → 2053
        let cal = ActivityLevel.moderatelyActive.estimatedCalories(for: 70, goal: .eatHealthier)
        #expect(cal == 2053)
    }

    @Test("lose weight subtracts 500 kcal")
    func loseWeightDeficit() {
        let maintain = ActivityLevel.sedentary.estimatedCalories(for: 70, goal: .eatHealthier)
        let lose     = ActivityLevel.sedentary.estimatedCalories(for: 70, goal: .loseWeight)
        #expect(maintain - lose == 500)
    }

    @Test("build muscle adds 300 kcal")
    func buildMuscleSurplus() {
        let maintain = ActivityLevel.sedentary.estimatedCalories(for: 70, goal: .eatHealthier)
        let muscle   = ActivityLevel.sedentary.estimatedCalories(for: 70, goal: .buildMuscle)
        #expect(muscle - maintain == 300)
    }

    @Test("extra-active produces more than sedentary")
    func activityScaling() {
        let sedentary   = ActivityLevel.sedentary.estimatedCalories(for: 70, goal: .maintainWeight)
        let extraActive = ActivityLevel.extraActive.estimatedCalories(for: 70, goal: .maintainWeight)
        #expect(extraActive > sedentary)
    }
}

// MARK: - Streak

@Suite("Current streak")
@MainActor
struct StreakTests {

    @Test("no meals → 0")
    func noMeals() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test")
        ctx.insert(user)
        #expect(user.currentStreak == 0)
    }

    @Test("one meal today → 1")
    func todayOnly() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test")
        ctx.insert(user)
        let m = meal()
        ctx.insert(m)
        m.user = user
        #expect(user.currentStreak == 1)
    }

    @Test("5 consecutive days → 5")
    func fiveConsecutive() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test")
        ctx.insert(user)
        for d in 0...4 {
            let m = meal(daysAgo: d)
            ctx.insert(m)
            m.user = user
        }
        #expect(user.currentStreak == 5)
    }

    @Test("gap yesterday breaks streak to 1 (today only)")
    func gapYesterday() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test")
        ctx.insert(user)
        for d in [0, 2] {
            let m = meal(daysAgo: d)
            ctx.insert(m)
            m.user = user
        }
        #expect(user.currentStreak == 1)
    }

    @Test("only yesterday (no today) → 1")
    func onlyYesterday() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test")
        ctx.insert(user)
        let m = meal(daysAgo: 1)
        ctx.insert(m)
        m.user = user
        #expect(user.currentStreak == 1)
    }

    @Test("multiple meals on same day count as one streak day")
    func multipleSameDay() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test")
        ctx.insert(user)
        for _ in 0..<3 {
            let m = meal()
            ctx.insert(m)
            m.user = user
        }
        #expect(user.currentStreak == 1)
    }
}

// MARK: - Weight change

@Suite("Weight change")
@MainActor
struct WeightChangeTests {

    @Test("nil with zero entries")
    func zeroEntries() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test")
        ctx.insert(user)
        #expect(user.weightChangeSinceStart == nil)
    }

    @Test("nil with exactly one entry")
    func oneEntry() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test")
        ctx.insert(user)
        let e = WeightEntry(weightKg: 75)
        ctx.insert(e)
        e.user = user
        #expect(user.weightChangeSinceStart == nil)
    }

    @Test("weight loss is negative")
    func weightLoss() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test")
        ctx.insert(user)
        let first = WeightEntry(weightKg: 80)
        first.loggedAt = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let last = WeightEntry(weightKg: 75)
        for e in [first, last] { ctx.insert(e); e.user = user }
        #expect(user.weightChangeSinceStart == -5.0)
    }

    @Test("weight gain is positive")
    func weightGain() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test")
        ctx.insert(user)
        let first = WeightEntry(weightKg: 70)
        first.loggedAt = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let last = WeightEntry(weightKg: 73)
        for e in [first, last] { ctx.insert(e); e.user = user }
        #expect(user.weightChangeSinceStart == 3.0)
    }

    @Test("result is independent of insertion order")
    func arrayOrderIndependent() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test")
        ctx.insert(user)
        let older = WeightEntry(weightKg: 90)
        older.loggedAt = Calendar.current.date(byAdding: .day, value: -60, to: .now)!
        let newer = WeightEntry(weightKg: 85)
        // Insert in reversed chronological order deliberately
        for e in [newer, older] { ctx.insert(e); e.user = user }
        #expect(user.weightChangeSinceStart == -5.0)
    }
}

// MARK: - Deficiency detection

@Suite("Detected deficiencies")
@MainActor
struct DeficiencyTests {

    @Test("empty history → no deficiencies")
    func empty() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test", weightKg: 70)
        ctx.insert(user)
        #expect(user.detectedDeficiencies.isEmpty)
    }

    @Test("fewer than 3 meals → no deficiencies (not enough data)")
    func tooFewMeals() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test", weightKg: 70)
        ctx.insert(user)
        for _ in 0..<2 {
            let m = meal(protein: 5, fiber: 2)
            ctx.insert(m); m.user = user
        }
        #expect(user.detectedDeficiencies.isEmpty)
    }

    @Test("low fiber (avg < 20 g/day) flagged")
    func lowFiber() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test", weightKg: 70)
        ctx.insert(user)
        for _ in 0..<5 {
            let m = meal(protein: 80, fiber: 5)
            ctx.insert(m); m.user = user
        }
        #expect(user.detectedDeficiencies.contains("fiber"))
    }

    @Test("low protein (< 70% of target) flagged")
    func lowProtein() throws {
        let ctx = ModelContext(try makeContainer())
        // 70 kg → target = 112 g; log only 20 g avg → < 70%
        let user = User(name: "Test", weightKg: 70)
        ctx.insert(user)
        for _ in 0..<5 {
            let m = meal(protein: 20, fiber: 25)
            ctx.insert(m); m.user = user
        }
        #expect(user.detectedDeficiencies.contains("protein"))
    }

    @Test("adequate intake → no deficiencies")
    func adequate() throws {
        let ctx = ModelContext(try makeContainer())
        let user = User(name: "Test", weightKg: 70)
        ctx.insert(user)
        for _ in 0..<5 {
            let m = meal(protein: 120, fiber: 30)
            ctx.insert(m); m.user = user
        }
        #expect(user.detectedDeficiencies.isEmpty)
    }
}
