// NourishAI — PreviewBootstrap.swift
// Seeds realistic demo data for App Store screenshots and Simulator previews.
// Usage: call `PreviewBootstrap.seed(in: context)` from any debug menu or launch argument.
#if DEBUG
import Foundation
import SwiftData

enum PreviewBootstrap {

    static func seed(in context: ModelContext) {
        // Guard: don't double-seed
        let descriptor = FetchDescriptor<User>()
        guard (try? context.fetch(descriptor))?.isEmpty == true else { return }

        // Create user
        let user = User(name: "Alex Johnson", email: "alex@example.com",
                        biologicalSex: .male, heightCm: 178, weightKg: 82,
                        activityLevel: .moderatelyActive,
                        primaryGoal: .buildMuscle, dietaryStyle: .omnivore)
        user.dailyCalorieTarget = 2400
        user.dailyProteinTarget = 150
        user.dailyCarbTarget = 250
        user.dailyFatTarget = 80
        user.dailyFiberTarget = 30
        user.dailyWaterGoalMl = 2500
        context.insert(user)

        // ---- Meal entries (today + last 14 days) ----
        let sampleMeals: [(String, Int, Double, Double, Double, Double, Int, MealType)] = [
            ("Greek Yoghurt & Granola", 340, 20, 45, 8, 4, 82, .breakfast),
            ("Grilled Chicken Salad",   480, 42, 18, 14, 6, 91, .lunch),
            ("Protein Shake",           220, 30, 12, 5, 1, 74, .snack),
            ("Salmon & Quinoa Bowl",    520, 38, 40, 16, 5, 95, .dinner),
            ("Scrambled Eggs & Toast",  380, 22, 30, 14, 3, 78, .breakfast),
            ("Turkey Wrap",             440, 35, 38, 12, 4, 86, .lunch),
            ("Apple & Almond Butter",   190, 5, 22, 9, 3, 72, .snack),
            ("Pasta Bolognese",         580, 28, 72, 14, 6, 70, .dinner),
            ("Overnight Oats",          360, 14, 58, 8, 7, 79, .breakfast),
            ("Tuna Rice Bowl",          460, 36, 50, 8, 3, 88, .lunch),
        ]

        let cal = Calendar.current
        for dayOffset in 0..<14 {
            guard let baseDate = cal.date(byAdding: .day, value: -dayOffset, to: .now) else { continue }
            let mealsToday = dayOffset == 0 ? Array(sampleMeals.prefix(4)) : Array(sampleMeals.prefix(Int.random(in: 3...5)))

            for (i, m) in mealsToday.enumerated() {
                let mealHour: Int
                switch m.7 {
                case .breakfast: mealHour = 8
                case .lunch:     mealHour = 13
                case .snack:     mealHour = 16
                case .dinner:    mealHour = 19
                default:         mealHour = 12
                }
                var comps = cal.dateComponents([.year, .month, .day], from: baseDate)
                comps.hour   = mealHour
                comps.minute = i * 5
                let logDate  = cal.date(from: comps) ?? baseDate

                let entry = MealEntry(manual: m.0, calories: m.1, protein: m.2,
                                      carbs: m.3, fat: m.4, mealType: m.7)
                entry.fiber       = m.5
                entry.healthScore = m.6
                entry.loggedAt    = logDate
                entry.logSource   = dayOffset == 0 ? "photo" : ["photo", "manual", "barcode"].randomElement()!
                entry.confidence  = Double.random(in: 0.82...0.98)
                entry.user        = user
                user.mealEntries.append(entry)
            }
        }

        // ---- Water entries ----
        for dayOffset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -dayOffset, to: .now) else { continue }
            let amounts = [300, 400, 300, 250, 350, 200, 350, 300]
            for (i, amount) in amounts.enumerated() {
                var comps = cal.dateComponents([.year, .month, .day], from: day)
                comps.hour   = 8 + i * 2
                comps.minute = 0
                let waterDate = cal.date(from: comps) ?? day
//                let entry = WaterEntry(amountMl: amount, source: "manual")
                let entry = WaterEntry(amountMl: amount)
                entry.loggedAt = waterDate
                entry.user     = user
                user.waterEntries.append(entry)
                context.insert(entry)
            }
        }

        // ---- Weight entries ----
        let weights: [(Int, Double)] = [(30, 85.2), (21, 84.0), (14, 83.1), (7, 82.5), (0, 82.0)]
        for (daysAgo, kg) in weights {
            guard let date = cal.date(byAdding: .day, value: -daysAgo, to: .now) else { continue }
            let entry = WeightEntry(weightKg: kg)
            entry.loggedAt = date
            entry.user     = user
            user.weightEntries.append(entry)
            context.insert(entry)
        }

        // ---- Supplements ----
        let supps: [(String, Double, String, String, String)] = [
            ("Vitamin D3", 4000, "IU",  "Morning", "#FF9500"),
            ("Omega-3",    1000, "mg",  "Morning", "#007AFF"),
            ("Magnesium",  400,  "mg",  "Before bed", "#5856D6"),
            ("Vitamin C",  1000, "mg",  "With meals", "#2D9E75"),
        ]
        for s in supps {
            let supp = Supplement(name: s.0, dosage: s.1, unit: s.2,
                                  frequency: "Daily", timeOfDay: s.3,
                                  notes: "", color: s.4)
            context.insert(supp)
            // Log the first two as taken today
            if s.0 == "Vitamin D3" || s.0 == "Omega-3" {
                let log = SupplementLog()
                supp.logs.append(log)
                context.insert(log)
            }
        }

        try? context.save()
    }
}
#endif
