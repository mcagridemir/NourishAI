// NourishAI — FastingLiveActivity.swift
// Widget Extension target only.
import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Attributes

struct FastingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var targetSeconds: Double
        var isComplete: Bool
        var zone: String

        var endDate: Date { startDate.addingTimeInterval(targetSeconds) }
        var targetHours: Int { Int(targetSeconds / 3600) }
        var progress: Double {
            let elapsed = Date().timeIntervalSince(startDate)
            return min(1, max(0, elapsed / targetSeconds))
        }
    }
}

// MARK: - Shared colors

private extension Color {
    static let fastGreen      = Color(red: 0.176, green: 0.620, blue: 0.459)
    static let fastGreenLight = Color(red: 0.882, green: 0.961, blue: 0.933)
}

// MARK: - Compact Leading (progress ring + "h left" or "Done")

private struct FastingCompactLeading: View {
    let state: FastingActivityAttributes.ContentState

    var body: some View {
        ZStack {
            Circle().stroke(Color.fastGreenLight, lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: state.progress)
                .stroke(state.isComplete ? Color.orange : Color.fastGreen,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 20, height: 20)
    }
}

// MARK: - Compact Trailing (live timer)

private struct FastingCompactTrailing: View {
    let state: FastingActivityAttributes.ContentState

    var body: some View {
        if state.isComplete {
            Label("Done", systemImage: "flame.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
        } else {
            Text(timerInterval: Date()...state.endDate, countsDown: true)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.fastGreen)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Lock Screen view

private struct FastingLockScreen: View {
    let state: FastingActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle().stroke(Color.fastGreenLight, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: state.progress)
                    .stroke(state.isComplete ? Color.orange : Color.fastGreen,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(Int(state.progress * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(state.isComplete ? .orange : Color.fastGreen)
                    Text("done")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(state.isComplete ? .orange : Color.fastGreen)
                    Text(state.isComplete ? "Fast complete! 🎉" : "Fasting · \(state.targetHours)h")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(state.isComplete ? .orange : .primary)
                }

                if !state.isComplete {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(timerInterval: Date()...state.endDate, countsDown: true)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                    }
                }

                Text(state.zone)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
    }
}

// MARK: - Expanded Dynamic Island

private struct FastingExpanded: View {
    let context: ActivityViewContext<FastingActivityAttributes>
    var state: FastingActivityAttributes.ContentState { context.state }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Fasting Timer", systemImage: "moon.zzz.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.fastGreen)
                Spacer()
                Text(state.isComplete ? "Complete 🎉" : state.zone)
                    .font(.system(size: 11))
                    .foregroundStyle(state.isComplete ? .orange : .secondary)
            }

            HStack(spacing: 24) {
                // Big ring
                ZStack {
                    Circle().stroke(Color.fastGreenLight, lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: state.progress)
                        .stroke(state.isComplete ? Color.orange : Color.fastGreen,
                                style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(Int(state.progress * 100))%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(state.isComplete ? .orange : Color.fastGreen)
                        Text("fasted")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 10) {
                    statRow(icon: "timer",
                            label: state.isComplete ? "Completed!" : "Remaining",
                            value: state.isComplete ? "—" : nil,
                            timer: state.isComplete ? nil : (Date()...state.endDate))

                    statRow(icon: "flag.checkered",
                            label: "Target",
                            value: "\(state.targetHours) hours")

                    statRow(icon: "moon.stars.fill",
                            label: "Zone",
                            value: state.zone)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func statRow(icon: String, label: String, value: String?, timer: ClosedRange<Date>? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.fastGreen)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                if let timer = timer {
                    Text(timerInterval: timer, countsDown: true)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                } else {
                    Text(value ?? "—")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
        }
    }
}

// MARK: - Widget

struct FastingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FastingActivityAttributes.self) { context in
            FastingLockScreen(state: context.state)
                .activityBackgroundTint(Color(.systemBackground))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FastingCompactLeading(state: context.state).padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FastingCompactTrailing(state: context.state).padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    FastingExpanded(context: context)
                }
            } compactLeading: {
                FastingCompactLeading(state: context.state)
            } compactTrailing: {
                FastingCompactTrailing(state: context.state)
            } minimal: {
                FastingCompactLeading(state: context.state)
            }
        }
    }
}

// MARK: - Previews

#Preview("Lock Screen", as: .content,
         using: FastingActivityAttributes()) {
    FastingLiveActivity()
} contentStates: {
    FastingActivityAttributes.ContentState(
        startDate: Date().addingTimeInterval(-10 * 3600),
        targetSeconds: 16 * 3600,
        isComplete: false,
        zone: "Fat burning 🔥"
    )
}

#Preview("Done", as: .content, using: FastingActivityAttributes()) {
    FastingLiveActivity()
} contentStates: {
    FastingActivityAttributes.ContentState(
        startDate: Date().addingTimeInterval(-17 * 3600),
        targetSeconds: 16 * 3600,
        isComplete: true,
        zone: "Deep ketosis 🔥"
    )
}
