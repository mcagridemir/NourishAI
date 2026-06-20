// Sana — DailySummaryShareCard.swift
// Rendered off-screen with ImageRenderer and shared as a PNG.
import SwiftUI

struct DailySummaryShareCard: View {

    // Nutrition
    let caloriesEaten: Int
    let caloriesTarget: Int
    let protein: Double
    let proteinTarget: Double
    let carbs: Double
    let carbsTarget: Double
    let fat: Double
    let fatTarget: Double
    // Hydration
    let waterMl: Int
    let waterGoalMl: Int
    // Context
    let steps: Int
    let dailyScore: Int
    let streak: Int
    let userName: String
    let isImperial: Bool

    private var calorieProgress: Double { min(1, Double(caloriesEaten) / Double(max(1, caloriesTarget))) }
    private var caloriesLeft: Int { max(0, caloriesTarget - caloriesEaten) }

    private static let green = Color(red: 0.176, green: 0.620, blue: 0.459)
    private static let cardBg = Color(red: 0.09, green: 0.09, blue: 0.09)

    var body: some View {
        VStack(spacing: 0) {
            topSection
            Divider().overlay(Color.white.opacity(0.1))
            macroSection
            Divider().overlay(Color.white.opacity(0.1))
            bottomRow
        }
        .background(Self.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .frame(width: 360)
    }

    // MARK: - Top — ring + hero stats

    private var topSection: some View {
        HStack(spacing: 20) {
            calorieRing
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(brandHeader)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .kerning(1.2)
                        .textCase(.uppercase)
                    Text("Today's summary")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                VStack(alignment: .leading, spacing: 8) {
                    statLine(label: "Eaten",  value: "\(caloriesEaten.formatted()) kcal", color: Self.green)
                    statLine(label: "Left",   value: "\(caloriesLeft.formatted()) kcal",  color: .white.opacity(0.7))
                    if steps > 0 {
                        statLine(label: "Steps",  value: steps.formatted(), color: .white.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .overlay(alignment: .topTrailing) {
            if streak >= 2 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(.orange).font(.system(size: 11))
                    Text("\(streak)d").font(.system(size: 11, weight: .semibold)).foregroundStyle(.orange)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
                .padding(14)
            }
        }
    }

    private var calorieRing: some View {
        ZStack {
            Circle().stroke(Self.green.opacity(0.15), lineWidth: 10).frame(width: 110, height: 110)
            Circle()
                .trim(from: 0, to: calorieProgress)
                .stroke(Self.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 110, height: 110)
            VStack(spacing: 1) {
                Text("\(Int(calorieProgress * 100))%")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("of goal")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: 110, height: 110)
    }

    private func statLine(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(LocalizedStringKey(label)).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
        }
    }

    // MARK: - Macro bars

    private var macroSection: some View {
        HStack(spacing: 0) {
            macroCell(label: "Protein", value: protein, target: proteinTarget, color: Color(hex: "#7FB1FF") ?? .blue)
            macroCell(label: "Carbs",   value: carbs,   target: carbsTarget,   color: Color(hex: "#F0C36E") ?? .yellow)
            macroCell(label: "Fat",     value: fat,     target: fatTarget,     color: Color(hex: "#FF9F8A") ?? .orange)
            waterCell
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
    }

    private func macroCell(label: String, value: Double, target: Double, color: Color) -> some View {
        let pct = min(1, value / max(1, target))
        return VStack(spacing: 6) {
            Text(LocalizedStringKey(label))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .kerning(0.4)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.12))
                    .frame(width: 6, height: 48)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 6, height: 48 * pct)
            }
            Text("\(Int(value))g")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var waterCell: some View {
        let pct = min(1.0, Double(waterMl) / Double(max(1, waterGoalMl)))
        let waterDisplay: String = {
            if isImperial {
                return String(format: "%.0f fl oz", Double(waterMl) * 0.033814)
            } else {
                return waterMl >= 1000 ? String(format: "%.1fL", Double(waterMl) / 1000) : "\(waterMl)ml"
            }
        }()
        return VStack(spacing: 6) {
            Text("Water")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .kerning(0.4)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 6, height: 48)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.blue)
                    .frame(width: 6, height: 48 * pct)
            }
            Text(waterDisplay)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom row — score + branding

    private var bottomRow: some View {
        HStack {
            HStack(spacing: 6) {
                ZStack {
                    Circle().stroke(scoreColor.opacity(0.2), lineWidth: 3).frame(width: 28, height: 28)
                    Circle()
                        .trim(from: 0, to: Double(dailyScore) / 100.0)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 28, height: 28)
                    Text("\(dailyScore)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(scoreColor)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Daily score").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                    Text(scoreGrade).font(.system(size: 11, weight: .bold)).foregroundStyle(scoreColor)
                }
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Self.green)
                    .font(.system(size: 10, weight: .semibold))
                Text("Sana")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // Share card uses explicit hex colors so it renders correctly off-screen (ImageRenderer).
    // Deliberately not using SanaTheme here since the card always renders on a dark bg.
    private var scoreColor: Color {
        switch dailyScore {
        case 75...100: return Self.green                           // #2D9E75
        case 50..<75:  return Color(hex: "#F0853A") ?? .orange    // accent
        default:       return Color(hex: "#E66B5C") ?? .red       // danger coral
        }
    }

    private var scoreGrade: String {
        switch dailyScore {
        case 90...100: return "Excellent"
        case 75..<90:  return "Great"
        case 60..<75:  return "Good"
        case 45..<60:  return "Fair"
        default:       return "Needs Work"
        }
    }

    private var brandHeader: String {
        let first = userName.components(separatedBy: " ").first ?? userName
        return first.isEmpty ? "Sana" : "\(first)'s day"
    }
}
