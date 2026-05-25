// Sana — MealEntryTests.swift
import Testing
import Foundation
@testable import Sana

@Suite("MealEntry")
struct MealEntryTests {

    // MARK: - Macro breakdown

    @Test("zero macros → all percentages zero")
    func zeroMacros() {
        let meal = MealEntry(manual: "Water", calories: 0, protein: 0, carbs: 0, fat: 0, mealType: .drink)
        let b = meal.macroBreakdown
        #expect(b.proteinPct == 0)
        #expect(b.carbPct == 0)
        #expect(b.fatPct == 0)
    }

    @Test("protein-only meal → 100% protein")
    func proteinOnly() {
        let meal = MealEntry(manual: "Egg whites", calories: 120, protein: 30, carbs: 0, fat: 0, mealType: .breakfast)
        let b = meal.macroBreakdown
        #expect(abs(b.proteinPct - 1.0) < 0.001)
        #expect(b.carbPct == 0)
        #expect(b.fatPct == 0)
    }

    @Test("percentages sum to 1.0")
    func percentagesSumToOne() {
        let meal = MealEntry(manual: "Mixed", calories: 600, protein: 30, carbs: 50, fat: 15, mealType: .lunch)
        let b = meal.macroBreakdown
        let sum = b.proteinPct + b.carbPct + b.fatPct
        #expect(abs(sum - 1.0) < 0.001)
    }

    @Test("fat is 9 kcal/g (heavier caloric weight)")
    func fatCalDensity() {
        // 10g protein (40 cal), 10g carb (40 cal), 10g fat (90 cal) — fat should dominate
        let meal = MealEntry(manual: "Balanced", calories: 170, protein: 10, carbs: 10, fat: 10, mealType: .snack)
        let b = meal.macroBreakdown
        #expect(b.fatPct > b.proteinPct)
        #expect(b.fatPct > b.carbPct)
    }

    @Test("known ratios — 30/50/20 protein/carb/fat cal split")
    func knownRatios() {
        // protein: 30g→120cal, carb: 50g→200cal, fat: ~11.1g→100cal = 420cal total
        let meal = MealEntry(manual: "Macro test", calories: 420,
                             protein: 30, carbs: 50, fat: 100.0 / 9.0, mealType: .lunch)
        let b = meal.macroBreakdown
        #expect(abs(b.proteinPct - 120.0 / 420.0) < 0.01)
        #expect(abs(b.carbPct   - 200.0 / 420.0) < 0.01)
        #expect(abs(b.fatPct    - 100.0 / 420.0) < 0.01)
    }

    // MARK: - Health score colour

    @Test("score ≥ 75 is green")
    func greenScore() {
        let meal = MealEntry(manual: "Salad", calories: 300, protein: 20, carbs: 30, fat: 8, mealType: .lunch)
        meal.healthScore = 80
        #expect(meal.healthScoreColor == "green")
    }

    @Test("score 50-74 is yellow")
    func yellowScore() {
        let meal = MealEntry(manual: "Pasta", calories: 500, protein: 15, carbs: 80, fat: 10, mealType: .dinner)
        meal.healthScore = 60
        #expect(meal.healthScoreColor == "yellow")
    }

    @Test("score < 50 is red")
    func redScore() {
        let meal = MealEntry(manual: "Junk", calories: 800, protein: 10, carbs: 100, fat: 40, mealType: .snack)
        meal.healthScore = 30
        #expect(meal.healthScoreColor == "red")
    }

    // MARK: - Vitamins / Minerals JSON round-trip

    @Test("empty JSON returns empty dictionary")
    func emptyVitamins() {
        let meal = MealEntry(manual: "Plain", calories: 100, protein: 5, carbs: 15, fat: 2, mealType: .snack)
        #expect(meal.vitamins.isEmpty)
        #expect(meal.minerals.isEmpty)
    }

    @Test("vitamins round-trip through JSON")
    func vitaminsRoundTrip() {
        let meal = MealEntry(manual: "Veggie bowl", calories: 400, protein: 15, carbs: 50, fat: 10, mealType: .lunch)
        let input: [String: Double] = ["vitamin_c": 45.5, "vitamin_d": 10.0, "vitamin_b12": 2.4]
        meal.vitamins = input
        let output = meal.vitamins
        #expect(output["vitamin_c"] == 45.5)
        #expect(output["vitamin_d"] == 10.0)
        #expect(output["vitamin_b12"] == 2.4)
    }

    @Test("minerals round-trip through JSON")
    func mineralsRoundTrip() {
        let meal = MealEntry(manual: "Steak", calories: 500, protein: 40, carbs: 0, fat: 25, mealType: .dinner)
        let input: [String: Double] = ["iron": 4.8, "calcium": 30.0, "potassium": 420.0]
        meal.minerals = input
        let output = meal.minerals
        #expect(output["iron"] == 4.8)
        #expect(output["calcium"] == 30.0)
        #expect(output["potassium"] == 420.0)
    }

    @Test("writing vitamins updates mineralsJSON independently")
    func vitaminsAndMineralsIndependent() {
        let meal = MealEntry(manual: "Meal", calories: 300, protein: 20, carbs: 30, fat: 10, mealType: .snack)
        meal.vitamins = ["vitamin_c": 50]
        meal.minerals = ["iron": 3]
        #expect(meal.vitamins["vitamin_c"] == 50)
        #expect(meal.minerals["iron"] == 3)
    }

    // MARK: - Relog initialiser

    @Test("relogged meal copies all nutrition")
    func relogCopiesNutrition() {
        let source = MealEntry(manual: "Chicken rice", calories: 550, protein: 40, carbs: 60, fat: 12, mealType: .lunch)
        source.healthScore = 82
        source.fiber = 5
        source.sugar = 3
        source.sodium = 400
        source.aiInsights = ["Good protein source"]

        let relog = MealEntry(relogging: source, mealType: .dinner)
        #expect(relog.calories == 550)
        #expect(relog.protein == 40)
        #expect(relog.carbohydrates == 60)
        #expect(relog.fat == 12)
        #expect(relog.healthScore == 82)
        #expect(relog.fiber == 5)
        #expect(relog.logSource == "relog")
        #expect(relog.mealType == .dinner)
    }

    @Test("relogged meal gets a new id and timestamp")
    func relogNewIdentity() {
        let source = MealEntry(manual: "Oats", calories: 300, protein: 10, carbs: 50, fat: 5, mealType: .breakfast)
        let relog = MealEntry(relogging: source, mealType: .breakfast)
        #expect(relog.id != source.id)
    }

    // MARK: - MealType

    @Test("all meal types have non-empty icons")
    func mealTypeIcons() {
        for type_ in MealType.allCases {
            #expect(!type_.icon.isEmpty)
        }
    }

    @Test("all meal types have valid default times")
    func mealTypeDefaultTimes() {
        for type_ in MealType.allCases {
            let t = type_.defaultTime
            #expect(t > Date.distantPast)
        }
    }
}
