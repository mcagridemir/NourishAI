// NourishAI — InsightsView.swift
import SwiftUI
import Charts

struct InsightsView: View {

    @Bindable var user: User
    @State private var selectedRange: InsightRange = .week

    enum InsightRange: String, CaseIterable { case week = "7 days"; case month = "30 days" }

    private var entries: [MealEntry] {
        let days = selectedRange == .week ? 7 : 30
        return user.mealEntries
            .filter { $0.loggedAt > Date().addingTimeInterval(-Double(days) * 86400) }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    private var dailyCalories: [(Date, Int)] {
        Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.loggedAt) }
            .map { ($0.key, $0.value.map { $0.calories }.reduce(0, +)) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NourishTheme.Spacing.lg) {
                    rangePicker
                    summaryCards
                    if !dailyCalories.isEmpty { calorieChart }
                    macroBreakdownChart
                    healthScoreChart
                    deficiencySection
                }
                .padding(NourishTheme.Spacing.md)
            }
            .background(NourishTheme.Color.background)
            .navigationTitle("Insights")
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(InsightRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(label: "Avg calories", value: avgCalories, unit: "kcal", icon: "flame.fill", color: .orange)
            StatCard(label: "Meals logged", value: "\(entries.count)", unit: "", icon: "fork.knife", color: NourishTheme.Color.primary)
            StatCard(label: "Avg health score", value: "\(avgHealthScore)", unit: "/100", icon: "heart.fill", color: .red)
            StatCard(label: "Avg protein", value: "\(Int(avgProtein))", unit: "g", icon: "bolt.fill", color: .blue)
        }
    }

    private var calorieChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily calories").font(NourishTheme.Font.headline())
            Chart(dailyCalories, id: \.0) { day in
                BarMark(x: .value("Day", day.0, unit: .day), y: .value("Calories", day.1))
                    .foregroundStyle(NourishTheme.Color.primary.gradient)
                    .cornerRadius(4)
                RuleMark(y: .value("Target", user.dailyCalorieTarget))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
            }
            .frame(height: 160)
        }
        .padding()
        .nourishCard()
    }

    private var macroBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macro average").font(NourishTheme.Font.headline())
            let data: [(String, Double, Color)] = [
                ("Protein", avgProtein, NourishTheme.Color.macro(.protein)),
                ("Carbs",   avgCarbs,   NourishTheme.Color.macro(.carbs)),
                ("Fat",     avgFat,     NourishTheme.Color.macro(.fat))
            ]
            Chart(data, id: \.0) { item in
                SectorMark(angle: .value("g", item.1), innerRadius: .ratio(0.6))
                    .foregroundStyle(item.2)
            }
            .frame(height: 140)
            HStack {
                ForEach(data, id: \.0) { item in
                    HStack(spacing: 4) {
                        Circle().fill(item.2).frame(width: 8, height: 8)
                        Text(item.0).font(NourishTheme.Font.caption(11))
                    }
                }
            }
        }
        .padding()
        .nourishCard()
    }

    private var healthScoreChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health score trend").font(NourishTheme.Font.headline())
            Chart(entries) { entry in
                LineMark(x: .value("Day", entry.loggedAt), y: .value("Score", entry.healthScore))
                    .foregroundStyle(NourishTheme.Color.primary)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Day", entry.loggedAt), y: .value("Score", entry.healthScore))
                    .foregroundStyle(NourishTheme.Color.primary.opacity(0.1))
                    .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 120)
        }
        .padding()
        .nourishCard()
    }

    private var deficiencySection: some View {
        Group {
            if !user.detectedDeficiencies.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Detected deficiencies", systemImage: "exclamationmark.triangle.fill")
                        .font(NourishTheme.Font.headline()).foregroundStyle(.orange)
                    ForEach(user.detectedDeficiencies, id: \.self) { nutrient in
                        HStack {
                            Image(systemName: "arrow.down.circle.fill").foregroundStyle(.orange)
                            Text("Low \(nutrient)").font(NourishTheme.Font.body(14))
                            Spacer()
                            Text("Below target").font(NourishTheme.Font.caption()).foregroundStyle(.orange)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.lg))
            }
        }
    }

    // MARK: - Computed stats
    private var avgCalories: String { entries.isEmpty ? "–" : "\(entries.map { $0.calories }.reduce(0, +) / entries.count)" }
    private var avgHealthScore: Int { entries.isEmpty ? 0 : entries.map { $0.healthScore }.reduce(0, +) / entries.count }
    private var avgProtein: Double { entries.isEmpty ? 0 : entries.map { $0.protein }.reduce(0, +) / Double(entries.count) }
    private var avgCarbs: Double { entries.isEmpty ? 0 : entries.map { $0.carbohydrates }.reduce(0, +) / Double(entries.count) }
    private var avgFat: Double { entries.isEmpty ? 0 : entries.map { $0.fat }.reduce(0, +) / Double(entries.count) }
}

private struct StatCard: View {
    let label: String; let value: String; let unit: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(NourishTheme.Font.numeric).foregroundStyle(.primary)
                Text(unit).font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
            }
            Text(label).font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
    }
}
