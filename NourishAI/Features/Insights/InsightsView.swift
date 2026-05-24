// NourishAI — InsightsView.swift
import SwiftUI
import Charts

struct InsightsView: View {

    @Bindable var user: User
    @State private var selectedRange: InsightRange = .week
    @State private var weightRange: WeightRange = .month
    @State private var showingLogWeight = false
    @State private var shareImage: UIImage?
    @State private var showingShare = false
    @State private var showingWeeklyReport = false
    @State private var showingDiary = false

    enum InsightRange: String, CaseIterable {
        case week = "7 days"; case month = "30 days"
        var localizedTitle: String { NSLocalizedString(rawValue, comment: "") }
    }
    enum WeightRange: String, CaseIterable {
        case week = "7d"; case month = "30d"; case threeMonths = "90d"
        var localizedTitle: String { NSLocalizedString(rawValue, comment: "") }
    }

    private var weightDays: Int {
        switch weightRange { case .week: return 7; case .month: return 30; case .threeMonths: return 90 }
    }

    private var weightEntries: [WeightEntry] {
        user.weightEntries
            .filter { $0.loggedAt > Date().addingTimeInterval(-Double(weightDays) * 86400) }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

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
                    MealHeatmapView(mealEntries: user.mealEntries)
                    if !dailyCalories.isEmpty { calorieChart }
                    if !dailyCalories.isEmpty { calorieBalanceChart }
                    macroBreakdownChart
                    WeekComparisonView(user: user)
                    healthScoreChart
                    MealTimingView(mealEntries: user.mealEntries)
                    SleepNutritionCard(user: user)
                    HydrationTrendView(user: user)
                    weightSection
                    deficiencySection
                }
                .padding(NourishTheme.Spacing.md)
            }
            .background(NourishTheme.Color.background)
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingDiary = true
                        } label: {
                            Image(systemName: "calendar")
                                .foregroundStyle(NourishTheme.Color.primary)
                        }
                        Button {
                            showingWeeklyReport = true
                        } label: {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(NourishTheme.Color.primary)
                        }
                        Button {
                            renderShareCard()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(NourishTheme.Color.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDiary) {
                FoodDiaryCalendarView(user: user)
            }
            .sheet(isPresented: $showingWeeklyReport) {
                WeeklyReportView(user: user)
            }
            .sheet(isPresented: $showingShare) {
                if let image = shareImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    @MainActor
    private func renderShareCard() {
        let days = selectedRange == .week ? 7 : 30
        let card = NutritionShareCard(
            user: user,
            avgCalories: entries.isEmpty ? 0 : entries.map { $0.calories }.reduce(0, +) / entries.count,
            avgProtein: Int(avgProtein),
            avgCarbs: Int(avgCarbs),
            avgFat: Int(avgFat),
            streak: user.currentStreak,
            days: days
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            shareImage = image
            showingShare = true
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(InsightRange.allCases, id: \.self) { Text($0.localizedTitle).tag($0) }
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

    private var calorieBalanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Calorie balance").font(NourishTheme.Font.headline())
                Spacer()
                HStack(spacing: 12) {
                    legendDot(color: NourishTheme.Color.primary, label: "Surplus")
                    legendDot(color: .orange, label: "Deficit")
                }
            }
            Chart(dailyCalories, id: \.0) { day in
                let balance = day.1 - user.dailyCalorieTarget
                BarMark(x: .value("Day", day.0, unit: .day),
                        y: .value("Balance", balance))
                    .foregroundStyle(balance >= 0 ? NourishTheme.Color.primary : Color.orange)
                    .cornerRadius(4)
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
            }
            .frame(height: 140)
            Text("Positive = ate more than target · Negative = deficit")
                .font(NourishTheme.Font.caption(11))
                .foregroundStyle(.secondary)
        }
        .padding()
        .nourishCard()
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(NourishTheme.Font.caption(11))
        }
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

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weight").font(NourishTheme.Font.headline())
                Spacer()
                Button {
                    HapticService.selection()
                    showingLogWeight = true
                } label: {
                    Label("Log", systemImage: "plus")
                        .font(NourishTheme.Font.caption())
                        .foregroundStyle(NourishTheme.Color.primary)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.1f kg", user.latestWeightKg))
                        .font(NourishTheme.Font.numeric)
                        .foregroundStyle(NourishTheme.Color.primary)
                    Text("Current").font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
                }
                if let change = user.weightChangeSinceStart {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(change < 0 ? "" : "+")\(String(format: "%.1f", change)) kg")
                            .font(NourishTheme.Font.headline())
                            .foregroundStyle(change < 0 ? NourishTheme.Color.primary : .orange)
                        Text("Total change").font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Picker("", selection: $weightRange) {
                    ForEach(WeightRange.allCases, id: \.self) { Text($0.localizedTitle).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            if weightEntries.count >= 2 {
                Chart(weightEntries) { entry in
                    LineMark(x: .value("Date", entry.loggedAt), y: .value("kg", entry.weightKg))
                        .foregroundStyle(NourishTheme.Color.primary)
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Date", entry.loggedAt), y: .value("kg", entry.weightKg))
                        .foregroundStyle(NourishTheme.Color.primary.opacity(0.08))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", entry.loggedAt), y: .value("kg", entry.weightKg))
                        .foregroundStyle(NourishTheme.Color.primary)
                        .symbolSize(30)
                }
                .chartYScale(domain: weightChartDomain)
                .frame(height: 160)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 32))
                        .foregroundStyle(NourishTheme.Color.primaryLight)
                    Text("Log your weight to see your trend")
                        .font(NourishTheme.Font.body(13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .padding()
        .nourishCard()
        .sheet(isPresented: $showingLogWeight) { LogWeightSheet(user: user) }
    }

    private var weightChartDomain: ClosedRange<Double> {
        let weights = weightEntries.map { $0.weightKg }
        let min = (weights.min() ?? 60) - 2
        let max = (weights.max() ?? 80) + 2
        return min...max
    }

    // MARK: - Computed stats
    private var avgCalories: String { entries.isEmpty ? "–" : "\(entries.map { $0.calories }.reduce(0, +) / entries.count)" }
    private var avgHealthScore: Int { entries.isEmpty ? 0 : entries.map { $0.healthScore }.reduce(0, +) / entries.count }
    private var avgProtein: Double { entries.isEmpty ? 0 : entries.map { $0.protein }.reduce(0, +) / Double(entries.count) }
    private var avgCarbs: Double { entries.isEmpty ? 0 : entries.map { $0.carbohydrates }.reduce(0, +) / Double(entries.count) }
    private var avgFat: Double { entries.isEmpty ? 0 : entries.map { $0.fat }.reduce(0, +) / Double(entries.count) }
}

// ShareSheet is defined in Core/Extensions/Extensions.swift

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
