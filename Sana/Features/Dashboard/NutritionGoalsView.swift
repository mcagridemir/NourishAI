// Sana — NutritionGoalsView.swift
// Full-screen breakdown of all macro & micro goals for today.
import SwiftUI

struct NutritionGoalsView: View {

    let user: User
    @Environment(\.dismiss) private var dismiss

    private var today: [MealEntry] {
        user.mealEntries.filter { Calendar.current.isDateInToday($0.loggedAt) }
    }
    private var cal:    Int    { today.map { $0.calories }.reduce(0, +) }
    private var prot:   Double { today.map { $0.protein }.reduce(0, +) }
    private var carbs:  Double { today.map { $0.carbohydrates }.reduce(0, +) }
    private var fat:    Double { today.map { $0.fat }.reduce(0, +) }
    private var fiber:  Double { today.map { $0.fiber }.reduce(0, +) }
    private var water:  Int    { user.todayWaterMl }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SanaTheme.Spacing.lg) {
                    // Header ring
                    VStack(spacing: 8) {
                        MacroRingView(
                            calories: cal,
                            target: user.dailyCalorieTarget,
                            protein: prot, carbs: carbs, fat: fat
                        )
                        Text(calorieStatusText)
                            .font(SanaTheme.Font.body(13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, SanaTheme.Spacing.md)

                    // Macros
                    GoalSection(title: "Macronutrients", icon: "chart.pie.fill") {
                        GoalRow(label: "Calories",
                                value: Double(cal),
                                target: Double(user.dailyCalorieTarget),
                                unit: "kcal",
                                color: .orange)
                        GoalRow(label: "Protein",
                                value: prot,
                                target: user.dailyProteinTarget,
                                unit: "g",
                                color: SanaTheme.Color.macro(.protein))
                        GoalRow(label: "Carbohydrates",
                                value: carbs,
                                target: user.dailyCarbTarget,
                                unit: "g",
                                color: SanaTheme.Color.macro(.carbs))
                        GoalRow(label: "Fat",
                                value: fat,
                                target: user.dailyFatTarget,
                                unit: "g",
                                color: SanaTheme.Color.macro(.fat))
                        GoalRow(label: "Fiber",
                                value: fiber,
                                target: user.dailyFiberTarget,
                                unit: "g",
                                color: SanaTheme.Color.macro(.fiber))
                    }

                    // Hydration
                    GoalSection(title: "Hydration", icon: "drop.fill") {
                        let factor: Double = user.unitSystem == .imperial ? 0.033814 : 1.0
                        GoalRow(label: "Water",
                                value: Double(water) * factor,
                                target: Double(user.dailyWaterGoalMl) * factor,
                                unit: user.waterUnit,
                                color: .blue)
                    }

                    // Meal count info
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Today's activity", systemImage: "fork.knife")
                            .font(SanaTheme.Font.headline())
                        HStack(spacing: 16) {
                            InfoChip(label: "Meals", value: "\(today.count)")
                            InfoChip(label: "Streak", value: "\(user.currentStreak)d 🔥")
                            InfoChip(label: "Score", value: avgScore > 0 ? "\(avgScore)/100" : "—")
                        }
                    }
                    .padding()
                    .nourishCard()
                }
                .padding(SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Today's goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var calorieStatusText: String {
        let remaining = user.dailyCalorieTarget - cal
        if remaining > 0 {
            return "\(remaining) kcal remaining"
        } else if remaining == 0 {
            return "Daily goal reached! 🎉"
        } else {
            return "\(abs(remaining)) kcal over goal"
        }
    }

    private var avgScore: Int {
        guard !today.isEmpty else { return 0 }
        return today.map { $0.healthScore }.reduce(0, +) / today.count
    }
}

// MARK: - GoalSection

private struct GoalSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(SanaTheme.Font.headline())
            content
        }
        .padding()
        .nourishCard()
    }
}

// MARK: - GoalRow

private struct GoalRow: View {
    let label: String
    let value: Double
    let target: Double
    let unit: String
    let color: Color

    private var progress: Double { min(1, value / max(1, target)) }
    private var isOver: Bool { value > target }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(SanaTheme.Font.body(14))
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formatted(value))
                        .font(SanaTheme.Font.headline(14))
                        .foregroundStyle(isOver ? .orange : color)
                    Text("/ \(formatted(target)) \(unit)")
                        .font(SanaTheme.Font.caption(12))
                        .foregroundStyle(.secondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.12)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOver ? Color.orange : color)
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(SanaTheme.Animation.smooth, value: progress)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(formatted(value)) of \(formatted(target)) \(unit). \(Int(progress * 100)) percent.")
    }

    private func formatted(_ v: Double) -> String {
        v >= 100 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

// MARK: - InfoChip

private struct InfoChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(SanaTheme.Font.headline(15))
            Text(label)
                .font(SanaTheme.Font.caption(11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(SanaTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
    }
}
