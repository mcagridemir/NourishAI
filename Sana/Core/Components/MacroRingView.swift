// Sana — MacroRingView.swift
import SwiftUI

struct MacroRingView: View {
    let calories: Int
    let target: Int
    let protein: Double
    let carbs: Double
    let fat: Double

    private var progress: Double { min(1.0, Double(calories) / Double(max(1, target))) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(SanaTheme.Color.primaryLight, lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(SanaTheme.Color.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                // Design spec: spring bounce so the arc slightly overshoots then settles
                .animation(SanaTheme.Animation.bouncy, value: progress)
            VStack(spacing: 2) {
                Text("\(calories)")
                    .font(SanaTheme.Font.numeric)
                    .monospacedDigit()          // tabular numerics per design spec
                    .foregroundStyle(SanaTheme.Color.primary)
                Text("kcal")
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 120, height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calories: \(calories) of \(target). \(Int(progress * 100)) percent of daily goal.")
    }
}

struct MacroPillsView: View {
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double

    var body: some View {
        HStack(spacing: 12) {
            MacroPill(label: "Protein", value: protein, color: SanaTheme.Color.macro(.protein))
            MacroPill(label: "Carbs",   value: carbs,   color: SanaTheme.Color.macro(.carbs))
            MacroPill(label: "Fat",     value: fat,     color: SanaTheme.Color.macro(.fat))
            MacroPill(label: "Fiber",   value: fiber,   color: SanaTheme.Color.macro(.fiber))
        }
    }
}

private struct MacroPill: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Int(value))g")
                .font(SanaTheme.Font.headline(14))
                .foregroundStyle(color)
            Text(LocalizedStringKey(label))
                .font(SanaTheme.Font.caption(11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(Int(value)) grams")
    }
}

struct HealthScoreBadge: View {
    let score: Int
    var size: CGFloat = 44

    private var color: Color { SanaTheme.Color.healthScore(score) }
    private var bgColor: Color { SanaTheme.Color.healthScoreBg(score) }

    // Labels aligned to design score thresholds (75 / 50)
    private var label: String {
        switch score {
        case 75...100: return "Excellent"
        case 50..<75:  return "Good"
        case 30..<50:  return "Fair"
        default:       return "Poor"
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().fill(bgColor)
                Text("\(score)")
                    .font(SanaTheme.Font.headline(13))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
            .frame(width: size, height: size)
            Text(LocalizedStringKey(label))
                .font(SanaTheme.Font.caption(10))
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Health score: \(score) out of 100. \(label).")
    }
}
