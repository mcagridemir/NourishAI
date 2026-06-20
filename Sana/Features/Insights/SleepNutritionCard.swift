// Sana — SleepNutritionCard.swift
// Correlates HealthKit sleep data with the next day's calorie / meal patterns.
import SwiftUI
import Charts

struct SleepNutritionCard: View {

    let user: User
    @EnvironmentObject private var healthKit: HealthKitService

    // Last-night sleep (hours) from HealthKit
    private var sleepHours: Double { healthKit.lastNightSleep }

    // How does the user typically eat after a short vs long sleep?
    // We compare today's meals vs the typical 7-day average.
    private var sevenDayAvgCalories: Int {
        let recent = (user.mealEntries ?? []).filter { $0.loggedAt > Date().addingTimeInterval(-7 * 86400) }
        guard !recent.isEmpty else { return user.dailyCalorieTarget }
        let byDay = Dictionary(grouping: recent) { Calendar.current.startOfDay(for: $0.loggedAt) }
        let totals = byDay.values.map { $0.map { $0.calories }.reduce(0, +) }
        return totals.isEmpty ? user.dailyCalorieTarget : totals.reduce(0, +) / totals.count
    }

    private var todayCalories: Int { user.todayCalories }
    private var sleepQuality: SleepQuality {
        switch sleepHours {
        case 7...: return .good
        case 5..<7: return .fair
        default: return sleepHours == 0 ? .noData : .poor
        }
    }

    private var insight: String {
        switch sleepQuality {
        case .noData:
            return NSLocalizedString("Connect Apple Health to see how your sleep affects eating habits.", comment: "")
        case .good:
            return NSLocalizedString("Great sleep! Well-rested nights are linked to better food choices and reduced cravings.", comment: "")
        case .fair:
            return NSLocalizedString("Slightly under 7 hours. Mild sleep debt can increase appetite by ~15%. Stay mindful of snacking.", comment: "")
        case .poor:
            return NSLocalizedString("Less than 5 hours detected. Poor sleep raises ghrelin (hunger hormone) — aim for nutrient-dense meals today.", comment: "")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Sleep & Nutrition", systemImage: "moon.stars.fill")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(.indigo)
                Spacer()
                if sleepQuality != .noData {
                    sleepQualityBadge
                }
            }

            if sleepQuality != .noData {
                HStack(spacing: 20) {
                    sleepStat(label: "Sleep", value: String(format: "%.1fh", sleepHours),
                              icon: "moon.fill", color: .indigo)
                    sleepStat(label: "7-day avg cal", value: "\(sevenDayAvgCalories)",
                              icon: "chart.bar.fill", color: .orange)
                    sleepStat(label: "Today cal", value: "\(todayCalories)",
                              icon: "flame.fill", color: SanaTheme.Color.primary)
                }

                // Mini bar comparison
                if todayCalories > 0 && sevenDayAvgCalories > 0 {
                    VStack(spacing: 6) {
                        comparisonBar(label: "7-day avg", value: sevenDayAvgCalories,
                                      max: max(sevenDayAvgCalories, todayCalories) + 200, color: .orange)
                        comparisonBar(label: "Today", value: todayCalories,
                                      max: max(sevenDayAvgCalories, todayCalories) + 200,
                                      color: todayCalories > sevenDayAvgCalories ? .orange : SanaTheme.Color.primary)
                    }
                }
            }

            // Insight text
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: sleepQuality.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(sleepQuality.color)
                Text(insight)
                    .font(SanaTheme.Font.body(13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(sleepQuality.color.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.sm))
        }
        .padding()
        .nourishCard()
    }

    private var sleepQualityBadge: some View {
        Text(sleepQuality.label)
            .font(SanaTheme.Font.caption(11))
            .foregroundStyle(sleepQuality.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(sleepQuality.color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func sleepStat(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(SanaTheme.Font.headline(14))
            Text(LocalizedStringKey(label))
                .font(SanaTheme.Font.caption(10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func comparisonBar(label: String, value: Int, max: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(LocalizedStringKey(label))
                .font(SanaTheme.Font.caption(11))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.12))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * min(1, Double(value) / Double(Swift.max(1, max))), height: 6)
                }
            }
            .frame(height: 6)
            Text("\(value) kcal")
                .font(SanaTheme.Font.caption(11))
                .foregroundStyle(color)
                .frame(width: 60, alignment: .trailing)
        }
    }

    // MARK: - Sleep quality enum
    enum SleepQuality: Equatable {
        case noData, poor, fair, good

        var label: String {
            switch self {
            case .good:   return NSLocalizedString("Good", comment: "")
            case .fair:   return NSLocalizedString("Fair", comment: "")
            case .poor:   return NSLocalizedString("Poor", comment: "")
            case .noData: return NSLocalizedString("No data", comment: "")
            }
        }
        var color: Color {
            switch self { case .good: return .green; case .fair: return .orange; case .poor: return .red; case .noData: return .secondary }
        }
        var icon: String {
            switch self { case .good: return "checkmark.circle.fill"; case .fair: return "exclamationmark.circle.fill"; case .poor: return "xmark.circle.fill"; case .noData: return "questionmark.circle.fill" }
        }
    }
}
