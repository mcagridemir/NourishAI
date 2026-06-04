// Sana — InsightsView.swift
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
                VStack(spacing: SanaTheme.Spacing.lg) {
                    insightsHeader
                    rangePicker
                    summaryCards
                    if entries.isEmpty {
                        emptyInsightsCard
                    } else {
                        MealHeatmapView(mealEntries: user.mealEntries)
                        if !dailyCalories.isEmpty { calorieChart }
                        if !dailyCalories.isEmpty { calorieBalanceChart }
                        macroBreakdownChart
                        WeekComparisonView(user: user)
                        healthScoreChart
                        MealTimingView(mealEntries: user.mealEntries)
                        SleepNutritionCard(user: user)
                        HydrationTrendView(user: user)
                    }
                    weightSection
                    deficiencySection
                }
                .padding(SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingDiary = true
                        } label: {
                            Image(systemName: "calendar")
                                .foregroundStyle(SanaTheme.Color.primary)
                        }
                        .accessibilityLabel("Food diary")
                        Button {
                            showingWeeklyReport = true
                        } label: {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(SanaTheme.Color.primary)
                        }
                        .accessibilityLabel("Weekly report")
                        Button {
                            renderShareCard()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(SanaTheme.Color.primary)
                        }
                        .accessibilityLabel("Share insights")
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

    private var insightsHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Your trends")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.2)
            Text("Insights")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .kerning(-0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var rangePicker: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(InsightRange.allCases, id: \.self) { Text($0.localizedTitle).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(label: "Avg calories",     value: avgCalories,       unit: "kcal", icon: "flame.fill", color: SanaTheme.Color.accent)
            StatCard(label: "Meals logged",     value: "\(entries.count)", unit: "",     icon: "fork.knife", color: SanaTheme.Color.primary)
            StatCard(label: "Avg health score", value: "\(avgHealthScore)", unit: "/100", icon: "heart.fill", color: SanaTheme.Color.healthScore(avgHealthScore))
            StatCard(label: "Avg protein",      value: "\(Int(avgProtein))", unit: "g",  icon: "bolt.fill",  color: SanaTheme.Color.macro(.protein))
        }
    }

    private var calorieChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Daily calories", systemImage: "flame.fill")
                .font(SanaTheme.Font.headline())
                .foregroundStyle(.orange)
            Chart(dailyCalories, id: \.0) { day in
                BarMark(x: .value("Day", day.0, unit: .day), y: .value("Calories", day.1))
                    .foregroundStyle(SanaTheme.Color.primary.gradient)
                    .cornerRadius(4)
                RuleMark(y: .value("Target", user.dailyCalorieTarget))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal")
                            .font(SanaTheme.Font.caption(9))
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(height: 160)
            .accessibilityLabel("Daily calories bar chart. Target line at \(user.dailyCalorieTarget) kcal.")
        }
        .padding()
        .nourishCard()
    }

    private var calorieBalanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Calorie balance", systemImage: "scalemass.fill")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(.indigo)
                Spacer()
                HStack(spacing: 12) {
                    legendDot(color: SanaTheme.Color.primary, label: "Over")
                    legendDot(color: .orange, label: "Under")
                }
            }
            Chart(dailyCalories, id: \.0) { day in
                let balance = day.1 - user.dailyCalorieTarget
                BarMark(x: .value("Day", day.0, unit: .day),
                        y: .value("Balance", balance))
                    .foregroundStyle(balance >= 0 ? SanaTheme.Color.primary : Color.orange)
                    .cornerRadius(4)
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
            }
            .frame(height: 140)
            Text("vs. your \(user.dailyCalorieTarget) kcal goal · green = over · orange = under")
                .font(SanaTheme.Font.caption(11))
                .foregroundStyle(.secondary)
        }
        .padding()
        .nourishCard()
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(label).font(SanaTheme.Font.caption(11))
        }
        .accessibilityElement(children: .combine)
    }

    private var macroBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Macro split", systemImage: "chart.pie.fill")
                .font(SanaTheme.Font.headline())
                .foregroundStyle(SanaTheme.Color.primary)
            let data: [(String, Double, Color)] = [
                ("Protein", avgProtein, SanaTheme.Color.macro(.protein)),
                ("Carbs",   avgCarbs,   SanaTheme.Color.macro(.carbs)),
                ("Fat",     avgFat,     SanaTheme.Color.macro(.fat))
            ]
            Chart(data, id: \.0) { item in
                SectorMark(angle: .value("g", max(item.1, 1)), innerRadius: .ratio(0.58))
                    .foregroundStyle(item.2)
                    .cornerRadius(3)
            }
            .frame(height: 140)
            HStack(spacing: 16) {
                ForEach(data, id: \.0) { item in
                    HStack(spacing: 6) {
                        Circle().fill(item.2).frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.0).font(SanaTheme.Font.caption(11)).foregroundStyle(.primary)
                            Text("\(Int(item.1))g").font(SanaTheme.Font.caption(10)).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding()
        .nourishCard()
    }

    private var healthScoreChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Health score", systemImage: "heart.fill")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(.pink)
                Spacer()
                if avgHealthScore > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(avgHealthScore)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(SanaTheme.Color.healthScore(avgHealthScore))
                        Text("avg").font(SanaTheme.Font.caption(11)).foregroundStyle(.secondary)
                    }
                }
            }
            Chart(entries) { entry in
                LineMark(x: .value("Day", entry.loggedAt), y: .value("Score", entry.healthScore))
                    .foregroundStyle(Color.pink)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Day", entry.loggedAt), y: .value("Score", entry.healthScore))
                    .foregroundStyle(Color.pink.opacity(0.08))
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
                    HStack {
                        Label("Nutrient gaps", systemImage: "exclamationmark.triangle.fill")
                            .font(SanaTheme.Font.headline()).foregroundStyle(.orange)
                        Spacer()
                        Text("\(user.detectedDeficiencies.count)")
                            .font(SanaTheme.Font.caption(11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                    ForEach(user.detectedDeficiencies, id: \.self) { nutrient in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.1))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.orange)
                            }
                            Text("Low \(nutrient)").font(SanaTheme.Font.body(14))
                            Spacer()
                            Text("Below target").font(SanaTheme.Font.caption(11)).foregroundStyle(.orange)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: SanaTheme.Radius.lg)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 0.5)
                )
            }
        }
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Body weight", systemImage: "figure.stand")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(.teal)
                Spacer()
                Button {
                    HapticService.selection()
                    showingLogWeight = true
                } label: {
                    Label("Log", systemImage: "plus")
                        .font(SanaTheme.Font.caption())
                        .foregroundStyle(SanaTheme.Color.primary)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.formattedCurrentWeight)
                        .font(SanaTheme.Font.numeric)
                        .foregroundStyle(SanaTheme.Color.primary)
                    Text("Current").font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                }
                if let change = user.weightChangeSinceStart {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(change < 0 ? "−" : "+")\(user.formatWeight(abs(change)))")
                            .font(SanaTheme.Font.headline())
                            .foregroundStyle(change < 0 ? SanaTheme.Color.primary : .orange)
                        Text("Total change").font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
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
                    LineMark(
                        x: .value("Date", entry.loggedAt),
                        y: .value(user.weightUnit, chartWeight(entry.weightKg))
                    )
                    .foregroundStyle(SanaTheme.Color.primary)
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("Date", entry.loggedAt),
                        y: .value(user.weightUnit, chartWeight(entry.weightKg))
                    )
                    .foregroundStyle(SanaTheme.Color.primary.opacity(0.08))
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Date", entry.loggedAt),
                        y: .value(user.weightUnit, chartWeight(entry.weightKg))
                    )
                    .foregroundStyle(SanaTheme.Color.primary)
                    .symbolSize(30)
                }
                .chartYScale(domain: weightChartDomain)
                .chartYAxisLabel(user.weightUnit, position: .leading)
                .frame(height: 160)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 32))
                        .foregroundStyle(SanaTheme.Color.primaryLight)
                        .accessibilityHidden(true)
                    Text("Log your weight to see your trend")
                        .font(SanaTheme.Font.body(13))
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

    // Convert a kg value to the user's display unit for charting.
    private func chartWeight(_ kg: Double) -> Double {
        user.unitSystem == .imperial ? kg * 2.20462 : kg
    }

    private var weightChartDomain: ClosedRange<Double> {
        let isImperial = user.unitSystem == .imperial
        let margin  = isImperial ? 4.4 : 2.0
        let defLo   = isImperial ? 132.0 : 60.0
        let defHi   = isImperial ? 176.0 : 80.0
        let weights = weightEntries.map { chartWeight($0.weightKg) }
        return (weights.min() ?? defLo) - margin ... (weights.max() ?? defHi) + margin
    }

    // MARK: - Empty state
    private var emptyInsightsCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis.ascending.badge.clock")
                .font(.system(size: 38))
                .foregroundStyle(SanaTheme.Color.primaryLight)
                .accessibilityHidden(true)
            Text("No data yet")
                .font(SanaTheme.Font.headline())
            Text("Log meals to see calorie trends, macro breakdowns, and health score history.")
                .font(SanaTheme.Font.body(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .nourishCard()
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
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit).font(SanaTheme.Font.caption(11)).foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(SanaTheme.Font.caption(11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nourishCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)\(unit.isEmpty ? "" : " \(unit)")")
    }
}
