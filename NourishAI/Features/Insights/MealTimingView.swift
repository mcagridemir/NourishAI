// NourishAI — MealTimingView.swift
// Eating window and meal spacing analysis card for InsightsView.
import SwiftUI
import Charts

struct MealTimingView: View {

    let mealEntries: [MealEntry]
    private let calendar = Calendar.current

    // Today's meals sorted by time
    private var todayMeals: [MealEntry] {
        mealEntries
            .filter { calendar.isDateInToday($0.loggedAt) }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    // 7-day average eating window
    private var avgEatingWindowHours: Double {
        var windows: [Double] = []
        for i in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -i, to: calendar.startOfDay(for: .now)) else { continue }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
            let dayMeals = mealEntries.filter { $0.loggedAt >= day && $0.loggedAt < nextDay }.map { $0.loggedAt }
            guard dayMeals.count >= 2, let first = dayMeals.min(), let last = dayMeals.max() else { continue }
            windows.append(last.timeIntervalSince(first) / 3600)
        }
        return windows.isEmpty ? 0 : windows.reduce(0, +) / Double(windows.count)
    }

    // Today's first & last meal
    private var firstMealToday: Date? { todayMeals.first?.loggedAt }
    private var lastMealToday: Date?  { todayMeals.last?.loggedAt }
    private var eatingWindowToday: Double? {
        guard let f = firstMealToday, let l = lastMealToday, f != l else { return nil }
        return l.timeIntervalSince(f) / 3600
    }

    // Gaps between consecutive meals today
    private var gaps: [(String, Double)] {
        guard todayMeals.count >= 2 else { return [] }
        var result: [(String, Double)] = []
        for i in 1..<todayMeals.count {
            let gap = todayMeals[i].loggedAt.timeIntervalSince(todayMeals[i-1].loggedAt) / 3600
            let label = "\(todayMeals[i-1].mealName.prefix(8)) → \(todayMeals[i].mealName.prefix(8))"
            result.append((label, gap))
        }
        return result
    }

    // 7-day meal timing dots (hour of day per meal)
    private var weeklyDots: [(day: Int, hour: Double)] {
        var result: [(Int, Double)] = []
        for i in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -i, to: calendar.startOfDay(for: .now)) else { continue }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
            let dayMeals = mealEntries.filter { $0.loggedAt >= day && $0.loggedAt < nextDay }
            for meal in dayMeals {
                let hour = Double(calendar.component(.hour, from: meal.loggedAt)) +
                           Double(calendar.component(.minute, from: meal.loggedAt)) / 60
                result.append((i, hour))
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Meal timing", systemImage: "clock.fill")
                .font(NourishTheme.Font.headline())

            if todayMeals.isEmpty {
                Text("No meals logged today yet.")
                    .font(NourishTheme.Font.body(13))
                    .foregroundStyle(.secondary)
            } else {
                // Summary row
                HStack(spacing: 0) {
                    timingStat(label: "First meal",
                               value: firstMealToday?.formatted(.dateTime.hour().minute()) ?? "—")
                    Divider().frame(height: 36)
                    timingStat(label: "Last meal",
                               value: lastMealToday?.formatted(.dateTime.hour().minute()) ?? "—")
                    Divider().frame(height: 36)
                    timingStat(label: "Window",
                               value: eatingWindowToday.map { String(format: "%.1fh", $0) } ?? "—")
                    Divider().frame(height: 36)
                    timingStat(label: "7-day avg",
                               value: avgEatingWindowHours > 0 ? String(format: "%.1fh", avgEatingWindowHours) : "—")
                }

                // Weekly scatter plot
                if !weeklyDots.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Eating pattern (7 days)")
                            .font(NourishTheme.Font.caption(11))
                            .foregroundStyle(.secondary)
                        Chart(weeklyDots, id: \.day) { dot in
                            PointMark(
                                x: .value("Day", dot.day),
                                y: .value("Hour", dot.hour)
                            )
                            .foregroundStyle(NourishTheme.Color.primary)
                            .symbolSize(30)
                        }
                        .chartXAxis {
                            AxisMarks(values: Array(0..<7)) { value in
                                AxisValueLabel {
                                    if let d = value.as(Int.self),
                                       let day = Calendar.current.date(byAdding: .day, value: -d, to: .now) {
                                        Text(day.formatted(.dateTime.weekday(.short)))
                                            .font(NourishTheme.Font.caption(9))
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: [6, 9, 12, 15, 18, 21]) { value in
                                AxisValueLabel {
                                    if let h = value.as(Int.self) {
                                        Text("\(h):00").font(NourishTheme.Font.caption(9))
                                    }
                                }
                                AxisGridLine()
                            }
                        }
                        .chartYScale(domain: 5...23)
                        .frame(height: 130)
                    }
                }

                // Gap analysis
                if !gaps.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Time between meals")
                            .font(NourishTheme.Font.caption(11))
                            .foregroundStyle(.secondary)
                        ForEach(gaps, id: \.0) { gap in
                            HStack {
                                Text(gap.0)
                                    .font(NourishTheme.Font.caption(12))
                                    .lineLimit(1)
                                Spacer()
                                Text(String(format: "%.1fh", gap.1))
                                    .font(NourishTheme.Font.headline(12))
                                    .foregroundStyle(gap.1 > 5 ? .orange : NourishTheme.Color.primary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .nourishCard()
    }

    private func timingStat(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(NourishTheme.Font.headline(13))
            Text(label)
                .font(NourishTheme.Font.caption(10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
