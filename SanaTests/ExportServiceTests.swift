// Sana — ExportServiceTests.swift
import Testing
import Foundation
@testable import Sana

@Suite("ExportService CSV")
@MainActor
struct ExportServiceTests {

    private func readCSV(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    @Test("CSV has header and one row per meal")
    func headerAndRows() throws {
        let user = User(name: "Test")
        user.mealEntries = [
            MealEntry(manual: "Oatmeal", calories: 300, protein: 10, carbs: 50, fat: 5, mealType: .breakfast),
            MealEntry(manual: "Chicken salad", calories: 450, protein: 40, carbs: 20, fat: 18, mealType: .lunch)
        ]
        let url = try #require(ExportService.csvURL(for: user))
        let csv = try readCSV(url)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)

        #expect(lines.count == 3)                                   // header + 2 meals
        #expect(lines[0].hasPrefix("Date,Time,Meal,Type,Calories")) // header
        #expect(csv.contains("Oatmeal"))
        #expect(csv.contains("Chicken salad"))
        #expect(csv.contains("Breakfast"))
        #expect(csv.contains("Lunch"))

        try? FileManager.default.removeItem(at: url)
    }

    @Test("meal name containing a comma is quoted (CSV-escaped)")
    func escapesComma() throws {
        let user = User(name: "Test")
        user.mealEntries = [
            MealEntry(manual: "Rice, beans & egg", calories: 500, protein: 25, carbs: 70, fat: 12, mealType: .dinner)
        ]
        let url = try #require(ExportService.csvURL(for: user))
        let csv = try readCSV(url)

        #expect(csv.contains("\"Rice, beans & egg\""))              // wrapped in quotes

        try? FileManager.default.removeItem(at: url)
    }

    @Test("meal name containing a quote has it doubled")
    func escapesQuote() throws {
        let user = User(name: "Test")
        user.mealEntries = [
            MealEntry(manual: "12\" pizza", calories: 800, protein: 30, carbs: 90, fat: 35, mealType: .dinner)
        ]
        let url = try #require(ExportService.csvURL(for: user))
        let csv = try readCSV(url)

        #expect(csv.contains("\"12\"\" pizza\""))                   // " → "" inside quoted field

        try? FileManager.default.removeItem(at: url)
    }

    @Test("rows are sorted chronologically by loggedAt")
    func sortedByDate() throws {
        let user = User(name: "Test")
        let older = MealEntry(manual: "First", calories: 100, protein: 1, carbs: 1, fat: 1, mealType: .breakfast)
        older.loggedAt = Date(timeIntervalSince1970: 1_000)
        let newer = MealEntry(manual: "Second", calories: 200, protein: 2, carbs: 2, fat: 2, mealType: .lunch)
        newer.loggedAt = Date(timeIntervalSince1970: 2_000)
        user.mealEntries = [newer, older]                           // intentionally out of order

        let url = try #require(ExportService.csvURL(for: user))
        let csv = try readCSV(url)
        let firstIdx = try #require(csv.range(of: "First"))
        let secondIdx = try #require(csv.range(of: "Second"))
        #expect(firstIdx.lowerBound < secondIdx.lowerBound)         // older row comes first

        try? FileManager.default.removeItem(at: url)
    }

    @Test("decimal macros formatted to one decimal place")
    func macroFormatting() throws {
        let user = User(name: "Test")
        user.mealEntries = [
            MealEntry(manual: "Precise", calories: 333, protein: 12.34, carbs: 56.78, fat: 9.01, mealType: .snack)
        ]
        let url = try #require(ExportService.csvURL(for: user))
        let csv = try readCSV(url)

        #expect(csv.contains("12.3"))
        #expect(csv.contains("56.8"))
        #expect(csv.contains("9.0"))

        try? FileManager.default.removeItem(at: url)
    }

    @Test("user with no meals still produces a header-only file")
    func emptyUser() throws {
        let user = User(name: "Test")
        user.mealEntries = []
        let url = try #require(ExportService.csvURL(for: user))
        let csv = try readCSV(url)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 1)                                   // header only

        try? FileManager.default.removeItem(at: url)
    }
}
