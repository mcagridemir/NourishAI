// NourishAI — MacroRingView.swift
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
                .stroke(NourishTheme.Color.primaryLight, lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(NourishTheme.Color.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(NourishTheme.Animation.slow, value: progress)
            VStack(spacing: 2) {
                Text("\(calories)")
                    .font(NourishTheme.Font.numeric)
                    .foregroundStyle(NourishTheme.Color.primary)
                Text("kcal")
                    .font(NourishTheme.Font.caption())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 120, height: 120)
    }
}

struct MacroPillsView: View {
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double

    var body: some View {
        HStack(spacing: 12) {
            MacroPill(label: "Protein", value: protein, color: NourishTheme.Color.macro(.protein))
            MacroPill(label: "Carbs",   value: carbs,   color: NourishTheme.Color.macro(.carbs))
            MacroPill(label: "Fat",     value: fat,     color: NourishTheme.Color.macro(.fat))
            MacroPill(label: "Fiber",   value: fiber,   color: NourishTheme.Color.macro(.fiber))
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
                .font(NourishTheme.Font.headline(14))
                .foregroundStyle(color)
            Text(label)
                .font(NourishTheme.Font.caption(11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
    }
}

struct HealthScoreBadge: View {
    let score: Int
    var size: CGFloat = 44

    private var color: Color { NourishTheme.Color.healthScore(score) }
    private var label: String {
        switch score {
        case 80...100: return "Excellent"
        case 60..<80:  return "Good"
        case 40..<60:  return "Fair"
        default:       return "Poor"
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().fill(color.opacity(0.15))
                Text("\(score)")
                    .font(NourishTheme.Font.headline(13))
                    .foregroundStyle(color)
            }
            .frame(width: size, height: size)
            Text(label)
                .font(NourishTheme.Font.caption(10))
                .foregroundStyle(color)
        }
    }
}
