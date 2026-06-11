// Sana — MacroDetailView.swift
// Breakdown of which meals contributed to a selected macro today.
import SwiftUI
import Charts

struct MacroDetailView: View {

    let user: User
    @State var macro: MacroType
    @Environment(\.dismiss) private var dismiss

    private var todayMeals: [MealEntry] {
        (user.mealEntries ?? [])
            .filter { Calendar.current.isDateInToday($0.loggedAt) }
            .filter { macro.value(of: $0) > 0 }
            .sorted { macro.value(of: $0) > macro.value(of: $1) }
    }

    private var total: Double { todayMeals.map { macro.value(of: $0) }.reduce(0, +) }
    private var target: Double { macro.target(for: user) }
    private var progress: Double { min(1, total / max(1, target)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SanaTheme.Spacing.lg) {

                    // Macro picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(MacroType.allCases, id: \.self) { m in
                                Button {
                                    withAnimation(SanaTheme.Animation.snappy) { macro = m }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: m.icon).font(.system(size: 11))
                                        Text(m.localizedName).font(SanaTheme.Font.caption(12))
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(macro == m ? m.color : SanaTheme.Color.surface)
                                    .foregroundStyle(macro == m ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, SanaTheme.Spacing.md)
                    }

                    // Summary card
                    VStack(spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(macro.localizedName, systemImage: macro.icon)
                                    .font(SanaTheme.Font.headline())
                                    .foregroundStyle(macro.color)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(formatted(total))
                                        .font(SanaTheme.Font.numeric)
                                        .foregroundStyle(progress > 1 ? .orange : macro.color)
                                    Text("/ \(formatted(target)) \(macro.unit)")
                                        .font(SanaTheme.Font.caption())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            ZStack {
                                Circle().stroke(macro.color.opacity(0.15), lineWidth: 8)
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(progress > 1 ? Color.orange : macro.color,
                                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Text("\(Int(progress * 100))%")
                                    .font(SanaTheme.Font.caption(11))
                                    .foregroundStyle(macro.color)
                            }
                            .frame(width: 60, height: 60)
                        }

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(macro.color.opacity(0.12)).frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(progress > 1 ? Color.orange : macro.color)
                                    .frame(width: geo.size.width * min(1, progress), height: 8)
                                    .animation(SanaTheme.Animation.smooth, value: progress)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding()
                    .nourishCard()

                    // Bar chart
                    if !todayMeals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Breakdown by meal")
                                .font(SanaTheme.Font.headline())
                            Chart(todayMeals) { meal in
                                BarMark(
                                    x: .value("Amount", macro.value(of: meal)),
                                    y: .value("Meal", meal.mealName)
                                )
                                .foregroundStyle(macro.color.gradient)
                                .cornerRadius(4)
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic) { value in
                                    AxisValueLabel {
                                        if let d = value.as(Double.self) {
                                            Text("\(Int(d))\(macro.unit)")
                                                .font(SanaTheme.Font.caption(10))
                                        }
                                    }
                                    AxisGridLine()
                                }
                            }
                            .frame(height: CGFloat(todayMeals.count) * 44 + 30)
                        }
                        .padding()
                        .nourishCard()
                    }

                    // Meal list
                    if !todayMeals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Meals today")
                                .font(SanaTheme.Font.headline())
                            ForEach(todayMeals) { meal in
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(macro.color.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Image(systemName: meal.mealType.icon)
                                                .foregroundStyle(macro.color)
                                                .font(.system(size: 13))
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(meal.mealName)
                                            .font(SanaTheme.Font.body(14))
                                            .lineLimit(1)
                                        Text(meal.mealType.localizedName)
                                            .font(SanaTheme.Font.caption(11))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(formatted(macro.value(of: meal))) \(macro.unit)")
                                            .font(SanaTheme.Font.headline(13))
                                            .foregroundStyle(macro.color)
                                        if total > 0 {
                                            Text("\(Int(macro.value(of: meal) / total * 100))%")
                                                .font(SanaTheme.Font.caption(11))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(meal.mealName): \(formatted(macro.value(of: meal))) \(macro.unit)")
                                if meal.id != todayMeals.last?.id { Divider().padding(.leading, 48) }
                            }
                        }
                        .padding()
                        .nourishCard()
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: macro.icon)
                                .font(.system(size: 40))
                                .foregroundStyle(macro.color.opacity(0.4))
                            Text(String(format: NSLocalizedString("No %@ logged today", comment: ""), macro.localizedName.lowercased()))
                                .font(SanaTheme.Font.body())
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle(String(format: NSLocalizedString("%@ today", comment: "Macro detail title"), macro.localizedName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formatted(_ v: Double) -> String {
        v >= 100 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}
