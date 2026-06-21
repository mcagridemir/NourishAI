// Sana — AchievementsView.swift
// Gamified achievement badges tracking nutrition milestones.
import SwiftUI

// MARK: - Achievement model

struct Achievement: Identifiable {
    let id: String
    let icon: String
    let title: String
    let description: String
    let color: Color
    let checkUnlocked: (User) -> Bool

    static let all: [Achievement] = [
        Achievement(id: "first_meal",   icon: "fork.knife.circle.fill",
                    title: "First bite",
                    description: "Log your very first meal",
                    color: SanaTheme.Color.primary) { user in
            !(user.mealEntries ?? []).isEmpty
        },
        Achievement(id: "streak_7",    icon: "flame.fill",
                    title: "Week warrior",
                    description: "Maintain a 7-day logging streak",
                    color: .orange) { user in
            user.currentStreak >= 7
        },
        Achievement(id: "streak_30",   icon: "flame.fill",
                    title: "Monthly master",
                    description: "Maintain a 30-day logging streak",
                    color: .red) { user in
            user.currentStreak >= 30
        },
        Achievement(id: "meals_50",    icon: "number.circle.fill",
                    title: "Half century",
                    description: "Log 50 meals total",
                    color: .purple) { user in
            (user.mealEntries ?? []).count >= 50
        },
        Achievement(id: "meals_100",   icon: "100.circle.fill",
                    title: "Century club",
                    description: "Log 100 meals total",
                    color: .indigo) { user in
            (user.mealEntries ?? []).count >= 100
        },
        Achievement(id: "water_goal",  icon: "drop.fill",
                    title: "Hydration hero",
                    description: "Hit your water goal 7 days in a row",
                    color: .blue) { user in
            let cal = Calendar.current
            var streak = 0
            for i in 0..<7 {
                guard let day = cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: .now)),
                      let nextDay = cal.date(byAdding: .day, value: 1, to: day) else { break }
                let ml = (user.waterEntries ?? [])
                    .filter { $0.loggedAt >= day && $0.loggedAt < nextDay }
                    .map { $0.amountMl }.reduce(0, +)
                if ml >= user.dailyWaterGoalMl { streak += 1 } else { break }
            }
            return streak >= 7
        },
        Achievement(id: "protein_goal", icon: "bolt.fill",
                    title: "Protein power",
                    description: "Hit your protein goal 5 days in a row",
                    color: .indigo) { user in
            let cal = Calendar.current
            var streak = 0
            for i in 0..<5 {
                guard let day = cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: .now)),
                      let nextDay = cal.date(byAdding: .day, value: 1, to: day) else { break }
                let prot = (user.mealEntries ?? [])
                    .filter { $0.loggedAt >= day && $0.loggedAt < nextDay }
                    .map { $0.protein }.reduce(0, +)
                if prot >= user.dailyProteinTarget { streak += 1 } else { break }
            }
            return streak >= 5
        },
        Achievement(id: "health_score_80", icon: "heart.fill",
                    title: "Health star",
                    description: "Achieve an average health score of 80+",
                    color: .red) { user in
            let recent = (user.mealEntries ?? []).suffix(20)
            guard !recent.isEmpty else { return false }
            return recent.map { $0.healthScore }.reduce(0, +) / recent.count >= 80
        },
        Achievement(id: "barcode_5",   icon: "barcode",
                    title: "Label reader",
                    description: "Scan 5 food barcodes",
                    color: SanaTheme.Color.primary) { user in
            (user.mealEntries ?? []).filter { $0.logSource == "barcode" }.count >= 5
        },
        Achievement(id: "fasting_complete", icon: "moon.stars.fill",
                    title: "Fasting champion",
                    description: "Complete a 16h+ fast",
                    color: .purple) { user in
            UserDefaults.standard.bool(forKey: "achievement.fasting.completed")
        },
        Achievement(id: "calorie_goal_7", icon: "target",
                    title: "Goal crusher",
                    description: "Stay within calorie goal 7 days in a row",
                    color: .green) { user in
            let cal = Calendar.current
            var streak = 0
            for i in 0..<7 {
                guard let day = cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: .now)),
                      let nextDay = cal.date(byAdding: .day, value: 1, to: day) else { break }
                let cals = (user.mealEntries ?? [])
                    .filter { $0.loggedAt >= day && $0.loggedAt < nextDay }
                    .map { $0.calories }.reduce(0, +)
                let inRange = cals > 0 && cals <= Int(Double(user.dailyCalorieTarget) * 1.05)
                if inRange { streak += 1 } else { break }
            }
            return streak >= 7
        },
        Achievement(id: "plan_complete", icon: "calendar.badge.checkmark",
                    title: "Planner",
                    description: "Log all meals from a meal plan day",
                    color: .teal) { user in
            (user.mealPlans ?? []).flatMap { $0.days ?? [] }
                .contains { day in
                    let meals: [PlannedMeal?] = [day.breakfastMeal, day.lunchMeal, day.dinnerMeal]
                    return meals.compactMap { $0 }.allSatisfy { $0.isCompleted }
                }
        },
        Achievement(id: "variety_5",   icon: "rectangle.grid.2x2.fill",
                    title: "Foodie",
                    description: "Log 5 different meal types in one week",
                    color: .orange) { user in
            let lastWeek = Date().addingTimeInterval(-7 * 86400)
            let types = Set((user.mealEntries ?? []).filter { $0.loggedAt > lastWeek }.map { $0.mealType })
            return types.count >= 4
        },
        Achievement(id: "photo_10",    icon: "camera.fill",
                    title: "Snap & track",
                    description: "Analyse 10 meals via photo",
                    color: SanaTheme.Color.primary) { user in
            (user.mealEntries ?? []).filter { $0.photoData != nil }.count >= 10
        },
        Achievement(id: "perfect_day", icon: "star.fill",
                    title: "Perfect day",
                    description: "Hit calories, protein & water goals in one day",
                    color: .yellow) { user in
            let cal = Calendar.current
            let today = cal.startOfDay(for: .now)
            guard let tomorrow = cal.date(byAdding: .day, value: 1, to: today) else { return false }
            let meals = (user.mealEntries ?? []).filter { $0.loggedAt >= today && $0.loggedAt < tomorrow }
            let cals = meals.map { $0.calories }.reduce(0, +)
            let prot = meals.map { $0.protein }.reduce(0, +)
            let water = (user.waterEntries ?? []).filter { $0.loggedAt >= today && $0.loggedAt < tomorrow }.map { $0.amountMl }.reduce(0, +)
            return cals >= user.dailyCalorieTarget - 100 &&
                   prot >= user.dailyProteinTarget &&
                   water >= user.dailyWaterGoalMl
        }
    ]
}

// MARK: - AchievementsView

struct AchievementsView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss

    private var unlocked: [Achievement]   { Achievement.all.filter { $0.checkUnlocked(user) } }
    private var locked: [Achievement]     { Achievement.all.filter { !$0.checkUnlocked(user) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SanaTheme.Spacing.lg) {
                    // Progress header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().stroke(SanaTheme.Color.primaryLight, lineWidth: 10)
                            Circle()
                                .trim(from: 0, to: Double(unlocked.count) / Double(Achievement.all.count))
                                .stroke(SanaTheme.Color.primary,
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 2) {
                                Text("\(unlocked.count)")
                                    .font(SanaTheme.Font.numeric)
                                    .foregroundStyle(SanaTheme.Color.primary)
                                Text("/ \(Achievement.all.count)")
                                    .font(SanaTheme.Font.caption())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 100, height: 100)
                        Text("Achievements")
                            .font(SanaTheme.Font.headline(18))
                        Text(String(format: NSLocalizedString("%d of %d unlocked", comment: ""), unlocked.count, Achievement.all.count))
                            .font(SanaTheme.Font.body(13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, SanaTheme.Spacing.md)

                    if !unlocked.isEmpty {
                        achievementSection(title: "Unlocked 🏆", badges: unlocked, isUnlocked: true)
                    }
                    if !locked.isEmpty {
                        achievementSection(title: "Locked 🔒", badges: locked, isUnlocked: false)
                    }
                }
                .padding(SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func achievementSection(title: String, badges: [Achievement], isUnlocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(title)).font(SanaTheme.Font.headline())
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(badges) { badge in
                    BadgeCell(badge: badge, isUnlocked: isUnlocked)
                }
            }
        }
        .padding()
        .nourishCard()
    }
}

// MARK: - BadgeCell

private struct BadgeCell: View {
    let badge: Achievement
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? badge.color.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 56, height: 56)
                Image(systemName: badge.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isUnlocked ? badge.color : Color(.systemGray3))
            }
            Text(LocalizedStringKey(badge.title))
                .font(SanaTheme.Font.caption(11))
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(isUnlocked ? .primary : .secondary)
            Text(LocalizedStringKey(badge.description))
                .font(SanaTheme.Font.caption(9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge.title). \(badge.description). \(isUnlocked ? "Unlocked" : "Locked")")
    }
}
