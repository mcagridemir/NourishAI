// Sana — HydrationTrendView.swift
// 7-day water intake trend with daily goal line.
import SwiftUI
import Charts

struct HydrationTrendView: View {

    let user: User

    // (date, total ml that day, goal ml)
    private var dailyData: [(day: Date, ml: Int, goal: Int)] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap { offset -> (Date, Int, Int)? in
            guard let date = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: .now)) else { return nil }
            let dayEnd = cal.date(byAdding: .day, value: 1, to: date) ?? date
            let total = (user.waterEntries ?? [])
                .filter { $0.loggedAt >= date && $0.loggedAt < dayEnd }
                .reduce(0) { $0 + $1.amountMl }
            return (date, total, user.dailyWaterGoalMl)
        }
    }

    private var isImperial: Bool { user.unitSystem == .imperial }
    private let flOzFactor: Double = 0.033814

    /// Convert ml to chart display unit (ml or fl oz).
    private func chartWater(_ ml: Int) -> Double {
        isImperial ? Double(ml) * flOzFactor : Double(ml)
    }

    /// Format a chart axis value that is already in display units.
    private func waterAxisLabel(_ v: Double) -> String {
        if isImperial {
            return String(format: "%.0f fl oz", v)
        } else {
            let ml = Int(v)
            return ml >= 1000 ? "\(ml / 1000)L" : "\(ml)ml"
        }
    }

    private var goalHitDays: Int { dailyData.filter { $0.ml >= $0.goal }.count }
    private var avgMl: Int {
        let filled = dailyData.filter { $0.ml > 0 }
        guard !filled.isEmpty else { return 0 }
        return filled.map { $0.ml }.reduce(0, +) / filled.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Hydration trend", systemImage: "drop.fill")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(.blue)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(goalHitDays)/7 days")
                        .font(SanaTheme.Font.headline(13))
                        .foregroundStyle(goalHitDays >= 5 ? SanaTheme.Color.primary : .orange)
                    Text("goal reached")
                        .font(SanaTheme.Font.caption(10))
                        .foregroundStyle(.secondary)
                }
            }

            Chart(dailyData, id: \.day) { item in
                BarMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value(isImperial ? "fl oz" : "ml", chartWater(item.ml))
                )
                .foregroundStyle(item.ml >= item.goal ? Color.blue : Color.blue.opacity(0.35))
                .cornerRadius(4)

                RuleMark(y: .value("Goal", chartWater(item.goal)))
                    .foregroundStyle(.blue.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal \(user.formatWater(item.goal))")
                            .font(SanaTheme.Font.caption(9))
                            .foregroundStyle(.blue.opacity(0.7))
                    }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(waterAxisLabel(v))
                                .font(SanaTheme.Font.caption(10))
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .font(SanaTheme.Font.caption(10))
                }
            }
            .frame(height: 140)

            // Summary row
            HStack(spacing: 0) {
                summaryChip(label: "Avg/day",
                            value: user.formatWater(avgMl),
                            color: .blue)
                Spacer()
                summaryChip(label: "Today",
                            value: user.formatWater(user.todayWaterMl),
                            color: user.todayWaterMl >= user.dailyWaterGoalMl ? SanaTheme.Color.primary : .orange)
                Spacer()
                summaryChip(label: "Remaining",
                            value: user.formatWater(max(0, user.dailyWaterGoalMl - user.todayWaterMl)),
                            color: Color.secondary)
            }
        }
        .padding()
        .nourishCard()
    }

    private func summaryChip(label: String, value: String, color: some ShapeStyle) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SanaTheme.Font.headline(15))
                .foregroundStyle(color)
            Text(label)
                .font(SanaTheme.Font.caption(10))
                .foregroundStyle(.secondary)
        }
    }
}
