// Sana — WeightGoalCard.swift
// Shows calorie deficit/surplus + optional weight-target progress on the Dashboard.
import SwiftUI

struct WeightGoalCard: View {

    @Bindable var user: User
    /// Calorie target adjusted for today's active burn (from HealthKit).
    let adjustedCalorieTarget: Int

    @State private var showingEdit = false

    // MARK: - Computed

    private var todayEaten: Int    { user.todayCalories }
    /// Positive = calorie deficit (eating less than goal). Negative = surplus.
    private var todayBalance: Int  { adjustedCalorieTarget - todayEaten }
    private var isDeficit: Bool    { todayBalance >= 0 }

    /// Weekly projected weight change based on recent averages.
    private var weeklyChangeLbs: Double {
        user.projectedWeeklyWeightChangeKg * 2.20462
    }
    private var weeklyChangeDisplay: LocalizedStringKey {
        let change = user.unitSystem == .metric
            ? user.projectedWeeklyWeightChangeKg
            : weeklyChangeLbs
        let unit = user.weightUnit
        let absChange = Swift.abs(change)
        guard absChange > 0.01 else { return "maintaining" }
        let valueStr = String(format: "%.2f", absChange)
        return change > 0
            ? "losing ~\(valueStr) \(unit)/wk"
            : "gaining ~\(valueStr) \(unit)/wk"
    }

    private var weeksToGoal: Int? {
        guard user.hasWeightTarget else { return nil }
        let weekly = user.projectedWeeklyWeightChangeKg
        guard Swift.abs(weekly) > 0.05 else { return nil }
        let remaining = user.latestWeightKg - user.targetWeightKg
        let result = remaining / weekly
        guard result > 0 else { return nil }
        return max(1, Int(ceil(result)))
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            deficitRow
            if user.hasWeightTarget {
                Divider().opacity(0.25)
                weightProgressSection
            }
        }
        .padding(SanaTheme.Spacing.lg)
        .background(SanaTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
        .sheet(isPresented: $showingEdit) { EditProfileView(user: user) }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Calorie balance", systemImage: "bolt.heart.fill")
                .font(SanaTheme.Font.headline())
            Spacer()
            Button {
                HapticService.impact(.light)
                showingEdit = true
            } label: {
                Text(user.hasWeightTarget ? "Edit goal" : "Set weight goal")
                    .font(SanaTheme.Font.caption(12))
                    .foregroundStyle(SanaTheme.Color.primary)
            }
        }
    }

    // MARK: - Deficit / Surplus row

    private var deficitRow: some View {
        let color: Color  = isDeficit ? SanaTheme.Color.primary : .orange
        let icon: String  = isDeficit ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
        let sign: String  = isDeficit ? "−" : "+"
        let label: LocalizedStringKey = isDeficit ? "Calorie deficit" : "Calorie surplus"

        return HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(SanaTheme.Font.body(14))
                Text(weeklyChangeDisplay)
                    .font(SanaTheme.Font.caption(11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(sign + abs(todayBalance).formatted())
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text("kcal")
                        .font(SanaTheme.Font.caption(11))
                        .foregroundStyle(.secondary)
                }
                Text("today")
                    .font(SanaTheme.Font.caption(10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Weight progress section

    @ViewBuilder
    private var weightProgressSection: some View {
        let current = user.latestWeightKg
        let target  = user.targetWeightKg
        let progress = user.weightGoalProgress

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Weight goal", systemImage: "scalemass.fill")
                    .font(SanaTheme.Font.body(13))
                    .foregroundStyle(.secondary)
                Spacer()
                if let weeks = weeksToGoal {
                    Text("~\(weeks) wk to go")
                        .font(SanaTheme.Font.caption(11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(SanaTheme.Color.primaryLight)
                        .clipShape(Capsule())
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text(user.formatWeight(current))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Image(systemName: target < current ? "arrow.down" : "arrow.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SanaTheme.Color.primary)
                Text(user.formatWeight(target))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(SanaTheme.Color.primary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(SanaTheme.Font.caption(11))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(SanaTheme.Color.primaryLight)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(SanaTheme.Color.primary)
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(SanaTheme.Animation.smooth, value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}
