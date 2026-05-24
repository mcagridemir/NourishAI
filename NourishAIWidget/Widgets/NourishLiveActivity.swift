// NourishAI — NourishLiveActivity.swift
import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Shared activity attributes (widget-local copy)

struct NourishActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var calories: Int
        var calorieTarget: Int
        var waterMl: Int
        var waterGoalMl: Int
        var protein: Double
        var proteinTarget: Double
        var mealCount: Int
        var streak: Int

        var calorieProgress: Double { min(1.0, Double(calories) / Double(max(1, calorieTarget))) }
        var waterProgress: Double   { min(1.0, Double(waterMl) / Double(max(1, waterGoalMl))) }
        var proteinProgress: Double { min(1.0, protein / max(1, proteinTarget)) }
        var caloriesRemaining: Int  { max(0, calorieTarget - calories) }
    }
    var userName: String
}

// MARK: - Colors (hardcoded — asset catalog not in widget target)

private extension Color {
    static let nourishGreen      = Color(red: 0.176, green: 0.620, blue: 0.459)
    static let nourishGreenLight = Color(red: 0.882, green: 0.961, blue: 0.933)
}

// MARK: - Reusable ring

private struct CalorieRing: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.nourishGreenLight, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.nourishGreen,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Lock Screen / Notification Center view

private struct LockScreenView: View {
    let state: NourishActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            // Calorie ring
            ZStack {
                CalorieRing(progress: state.calorieProgress, size: 64, lineWidth: 6)
                VStack(spacing: 0) {
                    Text("\(state.caloriesRemaining)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.nourishGreen)
                    Text("left")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            // Right column
            VStack(alignment: .leading, spacing: 8) {
                // Calories row
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(.orange).font(.system(size: 11))
                    Text("\(state.calories) / \(state.calorieTarget) kcal")
                        .font(.system(size: 12, weight: .medium))
                }

                // Water
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill").foregroundStyle(.blue).font(.system(size: 11))
                        Text("\(state.waterMl) / \(state.waterGoalMl) ml")
                            .font(.system(size: 12, weight: .medium))
                    }
                    ProgressView(value: state.waterProgress).tint(.blue)
                        .scaleEffect(x: 1, y: 0.7, anchor: .leading)
                }

                // Protein
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").foregroundStyle(.indigo).font(.system(size: 11))
                        Text("\(Int(state.protein))g / \(Int(state.proteinTarget))g protein")
                            .font(.system(size: 12, weight: .medium))
                    }
                    ProgressView(value: state.proteinProgress).tint(.indigo)
                        .scaleEffect(x: 1, y: 0.7, anchor: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Streak badge
            if state.streak > 0 {
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 14))
                    Text("\(state.streak)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Dynamic Island — Compact Leading

private struct CompactLeadingView: View {
    let state: NourishActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 4) {
            CalorieRing(progress: state.calorieProgress, size: 20, lineWidth: 3)
            Text("\(state.calories)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.nourishGreen)
        }
    }
}

// MARK: - Dynamic Island — Compact Trailing

private struct CompactTrailingView: View {
    let state: NourishActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "drop.fill")
                .font(.system(size: 10))
                .foregroundStyle(.blue)
            Text("\(state.waterMl)ml")
                .font(.system(size: 12, weight: .medium))
        }
    }
}

// MARK: - Dynamic Island — Expanded

private struct ExpandedView: View {
    let context: ActivityViewContext<NourishActivityAttributes>

    var state: NourishActivityAttributes.ContentState { context.state }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Label("NourishAI", systemImage: "leaf.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.nourishGreen)
                Spacer()
                if state.streak > 0 {
                    Label("\(state.streak)d", systemImage: "flame.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                Text("\(state.mealCount) meals")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Center: big ring + stats
            HStack(spacing: 20) {
                ZStack {
                    CalorieRing(progress: state.calorieProgress, size: 80, lineWidth: 8)
                    VStack(spacing: 1) {
                        Text("\(state.caloriesRemaining)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.nourishGreen)
                        Text("kcal left")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    progressRow(icon: "drop.fill", color: .blue,
                                label: "\(state.waterMl)ml water",
                                progress: state.waterProgress)
                    progressRow(icon: "bolt.fill", color: .indigo,
                                label: "\(Int(state.protein))g protein",
                                progress: state.proteinProgress)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
    }

    private func progressRow(icon: String, color: Color, label: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon).foregroundStyle(color).font(.system(size: 10))
                Text(label).font(.system(size: 11, weight: .medium))
            }
            ProgressView(value: progress).tint(color)
                .scaleEffect(x: 1, y: 0.7, anchor: .leading)
        }
    }
}

// MARK: - Live Activity Widget

struct NourishLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NourishActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color(.systemBackground))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CompactLeadingView(state: context.state)
                        .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CompactTrailingView(state: context.state)
                        .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(state: context.state)
            } compactTrailing: {
                CompactTrailingView(state: context.state)
            } minimal: {
                CalorieRing(progress: context.state.calorieProgress, size: 20, lineWidth: 3)
            }
        }
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: NourishActivityAttributes(userName: "Alex")) {
    NourishLiveActivity()
} contentStates: {
    NourishActivityAttributes.ContentState(
        calories: 1240, calorieTarget: 2000,
        waterMl: 1200, waterGoalMl: 2000,
        protein: 78, proteinTarget: 120,
        mealCount: 3, streak: 5
    )
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: NourishActivityAttributes(userName: "Alex")) {
    NourishLiveActivity()
} contentStates: {
    NourishActivityAttributes.ContentState(
        calories: 1240, calorieTarget: 2000,
        waterMl: 1200, waterGoalMl: 2000,
        protein: 78, proteinTarget: 120,
        mealCount: 3, streak: 5
    )
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: NourishActivityAttributes(userName: "Alex")) {
    NourishLiveActivity()
} contentStates: {
    NourishActivityAttributes.ContentState(
        calories: 1240, calorieTarget: 2000,
        waterMl: 1200, waterGoalMl: 2000,
        protein: 78, proteinTarget: 120,
        mealCount: 3, streak: 5
    )
}
