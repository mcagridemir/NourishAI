// Sana — CaloriePredictionCard.swift
// Predicts end-of-day calorie total based on today's meal timing and historical patterns.
import SwiftUI
import Charts

struct CaloriePredictionCard: View {

    let user: User

    // Today's meals so far
    private var todayMeals: [MealEntry] {
        (user.mealEntries ?? [])
            .filter { Calendar.current.isDateInToday($0.loggedAt) }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    private var todayCalories: Int { todayMeals.map { $0.calories }.reduce(0, +) }
    private var hourNow: Int { Calendar.current.component(.hour, from: .now) }

    // Average historical daily total (last 14 days, same weekday ± 3 days)
    private var historicalAvgCalories: Int {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: .now)
        let recent = (user.mealEntries ?? []).filter { $0.loggedAt > Date().addingTimeInterval(-14 * 86400) }
        let byDay = Dictionary(grouping: recent) { cal.startOfDay(for: $0.loggedAt) }
        let similar = byDay.filter { day, _ in
            let dw = cal.component(.weekday, from: day)
            let diff = abs(dw - weekday)
            return diff <= 2 || diff >= 5
        }
        let totals = similar.values.map { $0.map { $0.calories }.reduce(0, +) }
        guard !totals.isEmpty else { return user.dailyCalorieTarget }
        return totals.reduce(0, +) / totals.count
    }

    // How many calories are typically eaten after the current hour (using 14-day history)?
    private var predictedRemainingCalories: Int {
        let cal = Calendar.current
        let currentHour = hourNow
        let recent = (user.mealEntries ?? []).filter {
            $0.loggedAt > Date().addingTimeInterval(-14 * 86400)
            && !cal.isDateInToday($0.loggedAt)
        }
        guard !recent.isEmpty else {
            // Fallback: distribute remaining target linearly
            let fractionLeft = max(0, Double(22 - currentHour) / 22.0)
            return Int(Double(user.dailyCalorieTarget) * fractionLeft)
        }

        // Filter meals eaten after the current hour in historical data
        let afterNow = recent.filter { cal.component(.hour, from: $0.loggedAt) > currentHour }
        let byDay = Dictionary(grouping: afterNow) { cal.startOfDay(for: $0.loggedAt) }
        guard !byDay.isEmpty else { return 0 }
        let perDayTotals = byDay.values.map { $0.map { $0.calories }.reduce(0, +) }
        return perDayTotals.reduce(0, +) / perDayTotals.count
    }

    private var predictedTotal: Int { todayCalories + predictedRemainingCalories }
    private var delta: Int { predictedTotal - user.dailyCalorieTarget }
    private var isOverBudget: Bool { user.dailyCalorieTarget > 0 && delta > 50 }
    private var isOnTrack: Bool { user.dailyCalorieTarget == 0 || abs(delta) <= 100 }

    // Chart data: hourly cumulative today vs. historical average
    private var todayHourlyData: [(hour: Int, calories: Int)] {
        var cumulative = 0
        var result = [(Int, Int)]()
        for h in 0...hourNow {
            let hourCalories = todayMeals
                .filter { Calendar.current.component(.hour, from: $0.loggedAt) == h }
                .map { $0.calories }.reduce(0, +)
            cumulative += hourCalories
            result.append((h, cumulative))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Today's Forecast", systemImage: "chart.line.uptrend.xyaxis")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(SanaTheme.Color.primary)
                Spacer()
                forecastBadge
            }

            // Big prediction number
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(predictedTotal)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(isOverBudget ? .orange : SanaTheme.Color.primary)
                Text("kcal predicted")
                    .font(SanaTheme.Font.body(14))
                    .foregroundStyle(.secondary)
            }

            // Stats row
            HStack(spacing: 0) {
                predStat(label: "Eaten", value: "\(todayCalories)", unit: "kcal",
                          color: SanaTheme.Color.primary)
                Divider().frame(height: 32)
                predStat(label: "Predicted left", value: "\(predictedRemainingCalories)", unit: "kcal",
                          color: .secondary)
                Divider().frame(height: 32)
                predStat(label: "Target", value: "\(user.dailyCalorieTarget)", unit: "kcal",
                          color: .secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 8)
                    // Eaten portion
                    RoundedRectangle(cornerRadius: 4)
                        .fill(SanaTheme.Color.primary)
                        .frame(width: geo.size.width * min(1, Double(todayCalories) / Double(max(1, user.dailyCalorieTarget))), height: 8)
                    // Predicted additional portion
                    let eatenFrac = min(1, Double(todayCalories) / Double(max(1, user.dailyCalorieTarget)))
                    let predFrac  = min(1 - eatenFrac, Double(predictedRemainingCalories) / Double(max(1, user.dailyCalorieTarget)))
                    let predStart = geo.size.width * eatenFrac
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOverBudget ? Color.orange.opacity(0.5) : SanaTheme.Color.primary.opacity(0.3))
                        .frame(width: geo.size.width * predFrac, height: 8)
                        .offset(x: predStart)
                }
            }
            .frame(height: 8)
            .animation(SanaTheme.Animation.smooth, value: predictedTotal)

            // Cumulative calorie sparkline
            if !todayMeals.isEmpty {
                let lineColor: Color = isOverBudget ? .orange : SanaTheme.Color.primary
                Chart {
                    ForEach(todayHourlyData, id: \.hour) { point in
                        LineMark(
                            x: .value("Hour", point.hour),
                            y: .value("kcal", point.calories)
                        )
                        .foregroundStyle(lineColor)
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("Hour", point.hour),
                            y: .value("kcal", point.calories)
                        )
                        .foregroundStyle(lineColor.opacity(0.10))
                        .interpolationMethod(.catmullRom)
                    }
                    if user.dailyCalorieTarget > 0 {
                        RuleMark(y: .value("Goal", user.dailyCalorieTarget))
                            .foregroundStyle(Color.secondary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Goal \(user.dailyCalorieTarget) kcal")
                                    .font(SanaTheme.Font.caption(9))
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 72)
                .animation(SanaTheme.Animation.smooth, value: todayCalories)
            }

            // Forecast message
            Text(forecastMessage)
                .font(SanaTheme.Font.caption(12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .nourishCard()
    }

    private var forecastBadge: some View {
        let (label, color): (String, Color) = isOnTrack
            ? ("On track", SanaTheme.Color.primary)
            : isOverBudget
                ? ("Over budget", .orange)
                : ("Under budget", .blue)
        return Text(label)
            .font(SanaTheme.Font.caption(11))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var forecastMessage: String {
        if todayMeals.isEmpty {
            return "Log your first meal to enable daily forecasting based on your eating history."
        }
        if isOnTrack {
            return "You're trending within 100 kcal of your goal — keep it up!"
        }
        if isOverBudget {
            let over = delta
            return "Based on your usual pattern, you may exceed your goal by \(over) kcal. Consider a lighter dinner or skipping an extra snack."
        }
        let under = abs(delta)
        return "You're on track to end \(under) kcal under your goal. You have room for a nutritious snack."
    }

    private func predStat(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(SanaTheme.Font.headline(16)).foregroundStyle(color)
                Text(unit).font(SanaTheme.Font.caption(10)).foregroundStyle(.secondary)
            }
            Text(label).font(SanaTheme.Font.caption(10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
