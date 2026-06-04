// Sana — WeekComparisonView.swift
// Side-by-side comparison of this week vs last week for key nutrition metrics.
import SwiftUI
import Charts

struct WeekComparisonView: View {

    let user: User

    private let cal = Calendar.current

    // This week: Mon→today
    private var thisWeek: [MealEntry] {
        user.mealEntries.filter {
            $0.loggedAt >= weekStart(offset: 0) && $0.loggedAt < weekStart(offset: 1)
        }
    }

    // Last week
    private var lastWeek: [MealEntry] {
        user.mealEntries.filter {
            $0.loggedAt >= weekStart(offset: -1) && $0.loggedAt < weekStart(offset: 0)
        }
    }

    private func weekStart(offset: Int) -> Date {
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        comps.weekday = 2  // Monday
        let monday = cal.date(from: comps) ?? .now
        return cal.date(byAdding: .weekOfYear, value: offset, to: monday) ?? monday
    }

    private func avg(_ entries: [MealEntry], _ keyPath: KeyPath<MealEntry, Double>) -> Double {
        let days = Set(entries.map { cal.startOfDay(for: $0.loggedAt) })
        guard !days.isEmpty else { return 0 }
        return entries.map { $0[keyPath: keyPath] }.reduce(0, +) / Double(days.count)
    }

    private func avgCal(_ entries: [MealEntry]) -> Double {
        let days = Set(entries.map { cal.startOfDay(for: $0.loggedAt) })
        guard !days.isEmpty else { return 0 }
        return Double(entries.map { $0.calories }.reduce(0, +)) / Double(days.count)
    }

    private func avgHealthScore(_ entries: [MealEntry]) -> Double {
        let days = Set(entries.map { cal.startOfDay(for: $0.loggedAt) })
        guard !days.isEmpty else { return 0 }
        return Double(entries.map { $0.healthScore }.reduce(0, +)) / Double(days.count)
    }

    // higherIsBetter: false for Calories (lower = more disciplined), true for all nutrition quality metrics
    private var metrics: [(label: String, icon: String, color: Color, this: Double, last: Double, unit: String, higherIsBetter: Bool)] {[
        ("Calories",     "flame.fill",  SanaTheme.Color.accent, avgCal(thisWeek), avgCal(lastWeek), "kcal", false),
        ("Protein",      "bolt.fill",   SanaTheme.Color.macro(.protein), avg(thisWeek, \.protein), avg(lastWeek, \.protein), "g", true),
        ("Carbs",        "leaf.fill",   SanaTheme.Color.macro(.carbs),   avg(thisWeek, \.carbohydrates), avg(lastWeek, \.carbohydrates), "g", true),
        ("Fat",          "drop.fill",   SanaTheme.Color.macro(.fat),     avg(thisWeek, \.fat), avg(lastWeek, \.fat), "g", true),
        ("Health score", "heart.fill",  SanaTheme.Color.danger,  avgHealthScore(thisWeek), avgHealthScore(lastWeek), "/100", true),
        ("Fiber",        "list.bullet.circle.fill", SanaTheme.Color.macro(.fiber), avg(thisWeek, \.fiber), avg(lastWeek, \.fiber), "g", true),
    ]}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Week on week", systemImage: "arrow.left.arrow.right")
                    .font(SanaTheme.Font.headline())
                Spacer()
                HStack(spacing: 12) {
                    legendDot(color: SanaTheme.Color.primary, label: "This week")
                    legendDot(color: .secondary, label: "Last week")
                }
            }

            if thisWeek.isEmpty && lastWeek.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(metrics, id: \.label) { metric in
                        comparisonRow(metric)
                    }
                }
            }
        }
        .padding()
        .nourishCard()
    }

    private func comparisonRow(_ m: (label: String, icon: String, color: Color, this: Double, last: Double, unit: String, higherIsBetter: Bool)) -> some View {
        let maxVal = max(m.this, m.last, 1)
        let diff = m.this - m.last
        let pct = m.last == 0 ? 0 : diff / m.last * 100
        let improved = m.higherIsBetter ? diff > 0 : diff < 0

        return VStack(spacing: 5) {
            HStack {
                Image(systemName: m.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(m.color)
                    .frame(width: 16)
                Text(m.label)
                    .font(SanaTheme.Font.caption(13))
                Spacer()
                // Delta badge
                if abs(pct) >= 1 {
                    HStack(spacing: 2) {
                        Image(systemName: improved ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9))
                        Text("\(Int(abs(pct)))%")
                            .font(SanaTheme.Font.caption(11))
                    }
                    .foregroundStyle(improved ? SanaTheme.Color.primary : .orange)
                }
                Text("\(Int(m.this))\(m.unit)")
                    .font(SanaTheme.Font.headline(13))
                    .frame(width: 56, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Last week bar (background)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: geo.size.width * min(1, m.last / maxVal), height: 6)
                    // This week bar (foreground)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(m.color)
                        .frame(width: geo.size.width * min(1, m.this / maxVal), height: 6)
                        .animation(SanaTheme.Animation.smooth, value: m.this)
                }
            }
            .frame(height: 6)
        }
    }

    private var emptyState: some View {
        Text("Log meals for at least 2 weeks to see the comparison.")
            .font(SanaTheme.Font.body(14))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(SanaTheme.Font.caption(11)).foregroundStyle(.secondary)
        }
    }
}

