// Sana — ExportService.swift
import Foundation

struct ExportService {

    /// Generates a CSV string from meal entries and returns a temp file URL ready for sharing.
    static func csvURL(for user: User) -> URL? {
        var rows: [String] = [
            "Date,Time,Meal,Type,Calories,Protein(g),Carbs(g),Fat(g),Fiber(g),Health Score"
        ]

        let sorted = user.mealEntries?.sorted { $0.loggedAt < $1.loggedAt }
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"

        for entry in sorted ?? [] {
            let cols: [String] = [
                dateFmt.string(from: entry.loggedAt),
                timeFmt.string(from: entry.loggedAt),
                csvEscape(entry.mealName),
                entry.mealType.rawValue,
                "\(entry.calories)",
                String(format: "%.1f", entry.protein),
                String(format: "%.1f", entry.carbohydrates),
                String(format: "%.1f", entry.fat),
                String(format: "%.1f", entry.fiber),
                "\(entry.healthScore)"
            ]
            rows.append(cols.joined(separator: ","))
        }

        let csv = rows.joined(separator: "\n")
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sana_Export_\(dateFmt.string(from: .now)).csv")
        do {
            try csv.write(to: tmp, atomically: true, encoding: .utf8)
        } catch {
            return nil  // don't hand back a URL to a file that wasn't written
        }
        return tmp
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
