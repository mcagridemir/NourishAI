// Sana — NourishIntents.swift
// Siri & Shortcuts integration via App Intents (iOS 16+)
import AppIntents

// MARK: - Water amount enum (AppEnum required for @Parameter)

enum WaterAmountOption: Int, AppEnum {
    case small      = 150
    case medium     = 250
    case large      = 350
    case extraLarge = 500

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Water Amount"
    static let caseDisplayRepresentations: [WaterAmountOption: DisplayRepresentation] = [
        .small:      "150 ml",
        .medium:     "250 ml",
        .large:      "350 ml",
        .extraLarge: "500 ml"
    ]
}

// MARK: - Log Water Intent

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Log a water intake in Sana.")
    static let openAppWhenRun = false

    @Parameter(title: "Amount", default: WaterAmountOption.medium)
    var amount: WaterAmountOption

    func perform() async throws -> some ProvidesDialog {
        let ml = amount.rawValue
        await MainActor.run {
            let defaults = UserDefaults(suiteName: "group.com.cagri.Sana")
            let key = "siri.pendingWaterMl"
            let current = defaults?.integer(forKey: key) ?? 0
            defaults?.set(current + ml, forKey: key)
        }
        return .result(dialog: "Logged \(ml) ml of water in Sana. 💧")
    }
}

// MARK: - Check Today's Calories Intent

struct CheckCaloriesIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Today's Calories"
    static let description = IntentDescription("See how many calories you've logged today in Sana.")
    static let openAppWhenRun = false

    func perform() async throws -> some ProvidesDialog {
        let data = await MainActor.run { WidgetDataStore.load() }
        let pct = Int(data.calorieProgress * 100)
        return .result(dialog: "You've logged \(data.calories) of \(data.calorieTarget) calories today — that's \(pct)% of your goal.")
    }
}

// MARK: - Check Streak Intent

struct CheckStreakIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Logging Streak"
    static let description = IntentDescription("Check your current Sana logging streak.")
    static let openAppWhenRun = false

    func perform() async throws -> some ProvidesDialog {
        let data = await MainActor.run { WidgetDataStore.load() }
        if data.streak == 0 {
            return .result(dialog: "You don't have an active streak yet. Log a meal today to start one!")
        }
        return .result(dialog: "Your current Sana streak is \(data.streak) days. Keep it up! 🔥")
    }
}

// MARK: - App Shortcuts (appear automatically in Siri & Shortcuts app)

struct SanaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Log \(\.$amount) water in \(.applicationName)",
                "I drank water in \(.applicationName)"
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: CheckCaloriesIntent(),
            phrases: [
                "Check my calories in \(.applicationName)",
                "How many calories today in \(.applicationName)"
            ],
            shortTitle: "Today's Calories",
            systemImageName: "flame.fill"
        )
        AppShortcut(
            intent: CheckStreakIntent(),
            phrases: [
                "Check my streak in \(.applicationName)",
                "What's my \(.applicationName) streak"
            ],
            shortTitle: "My Streak",
            systemImageName: "flame.fill"
        )
    }
}
