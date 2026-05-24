// Sana — DailyScoreCard.swift
// Composite daily nutrition score (0-100) with per-pillar breakdown.
import SwiftUI

struct DailyScoreCard: View {

    let user: User
    @EnvironmentObject private var healthKit: HealthKitService

    // MARK: - Score pillars

    /// Calorie adherence: 100 if within ±10%, drops to 0 at ±50%
    private var calorieScore: Int {
        let target = user.dailyCalorieTarget
        guard target > 0 else { return 50 }  // neutral if not configured yet
        let ratio = Double(user.todayCalories) / Double(target)
        let deviation = abs(1.0 - ratio)
        return max(0, Int(100 - deviation * 200))
    }

    /// Protein: percentage of daily target met, capped at 100
    private var proteinScore: Int {
        guard user.dailyProteinTarget > 0 else { return 0 }
        return min(100, Int(user.todayProtein / user.dailyProteinTarget * 100))
    }

    /// Hydration: percentage of water goal met, capped at 100
    private var hydrationScore: Int {
        guard user.dailyWaterGoalMl > 0 else { return 0 }
        return min(100, user.todayWaterMl * 100 / user.dailyWaterGoalMl)
    }

    /// Meal quality: average health score of today's meals
    private var qualityScore: Int {
        let meals = user.mealEntries.filter { Calendar.current.isDateInToday($0.loggedAt) }
        guard !meals.isEmpty else { return 0 }
        return meals.map { $0.healthScore }.reduce(0, +) / meals.count
    }

    /// Activity: steps contribution (8k steps = 100)
    private var activityScore: Int {
        guard healthKit.isAuthorized else { return 50 }   // neutral when unavailable
        return min(100, healthKit.todaySteps * 100 / 8000)
    }

    // Weighted composite: cal 25%, protein 25%, hydration 20%, quality 20%, activity 10%
    private var totalScore: Int {
        Int(Double(calorieScore) * 0.25 +
            Double(proteinScore) * 0.25 +
            Double(hydrationScore) * 0.20 +
            Double(qualityScore) * 0.20 +
            Double(activityScore) * 0.10)
    }

    private var scoreColor: Color {
        switch totalScore {
        case 80...100: return .green
        case 60..<80: return SanaTheme.Color.primary
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var scoreGrade: String {
        switch totalScore {
        case 90...100: return "Excellent"
        case 75..<90: return "Great"
        case 60..<75: return "Good"
        case 45..<60: return "Fair"
        default: return "Needs Work"
        }
    }

    private var pillars: [(label: String, icon: String, score: Int, color: Color)] {[
        ("Calories",   "flame.fill",         calorieScore,  .orange),
        ("Protein",    "bolt.fill",           proteinScore,  SanaTheme.Color.macro(.protein)),
        ("Hydration",  "drop.fill",           hydrationScore, .blue),
        ("Meal quality","heart.fill",          qualityScore,  .red),
        ("Activity",   "figure.walk",         activityScore, .teal),
    ]}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Daily Score", systemImage: "star.fill")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(.yellow)
                Spacer()
                Text(scoreGrade)
                    .font(SanaTheme.Font.caption(12))
                    .foregroundStyle(scoreColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(scoreColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(alignment: .center, spacing: SanaTheme.Spacing.lg) {
                // Big ring
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.15), lineWidth: 12)
                        .frame(width: 90, height: 90)
                    Circle()
                        .trim(from: 0, to: Double(totalScore) / 100.0)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 90, height: 90)
                        .animation(SanaTheme.Animation.slow, value: totalScore)
                    VStack(spacing: 0) {
                        Text("\(totalScore)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor)
                        Text("/ 100")
                            .font(SanaTheme.Font.caption(10))
                            .foregroundStyle(.secondary)
                    }
                }

                // Pillar bars
                VStack(spacing: 8) {
                    ForEach(pillars, id: \.label) { pillar in
                        pillarRow(pillar)
                    }
                }
            }
        }
        .padding()
        .nourishCard()
    }

    private func pillarRow(_ p: (label: String, icon: String, score: Int, color: Color)) -> some View {
        HStack(spacing: 8) {
            Image(systemName: p.icon)
                .font(.system(size: 11))
                .foregroundStyle(p.color)
                .frame(width: 14)
            Text(p.label)
                .font(SanaTheme.Font.caption(11))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(p.color.opacity(0.12))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(p.color)
                        .frame(width: geo.size.width * min(1, Double(p.score) / 100.0), height: 5)
                        .animation(SanaTheme.Animation.smooth, value: p.score)
                }
            }
            .frame(height: 5)
            Text("\(p.score)")
                .font(SanaTheme.Font.caption(11))
                .foregroundStyle(p.score >= 70 ? p.color : .secondary)
                .frame(width: 24, alignment: .trailing)
        }
    }
}
