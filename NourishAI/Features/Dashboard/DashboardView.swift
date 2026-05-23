// NourishAI — DashboardView.swift
import SwiftUI
import SwiftData

struct DashboardView: View {

    @Bindable var user: User
    @StateObject private var vm: DashboardViewModel
    @EnvironmentObject private var healthKit: HealthKitService

    init(user: User) {
        self.user = user
        _vm = StateObject(wrappedValue: DashboardViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NourishTheme.Spacing.lg) {
                    headerSection
                    calorieRingSection
                    macroSection
                    healthMetricsSection
                    recentMealsSection
                    insightsBannerSection
                }
                .padding(.horizontal, NourishTheme.Spacing.md)
                .padding(.bottom, 32)
            }
            .background(NourishTheme.Color.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("NourishAI")
                        .font(NourishTheme.Font.title(22))
                        .foregroundStyle(NourishTheme.Color.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: ProfileView(user: user)) {
                        AsyncImage(url: nil) { _ in
                            Circle().fill(NourishTheme.Color.primaryLight)
                                .overlay(Text(user.name.prefix(1)).font(NourishTheme.Font.headline()).foregroundStyle(NourishTheme.Color.primary))
                        } placeholder: {
                            Circle().fill(NourishTheme.Color.primaryLight)
                                .overlay(Text(user.name.prefix(1)).font(NourishTheme.Font.headline()).foregroundStyle(NourishTheme.Color.primary))
                        }
                        .frame(width: 36, height: 36)
                    }
                }
            }
        }
        .task { await vm.loadInsights() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.greeting)
                    .font(NourishTheme.Font.headline())
                    .foregroundStyle(.secondary)
                Text(user.name.components(separatedBy: " ").first ?? user.name)
                    .font(NourishTheme.Font.title(26))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide)))
                    .font(NourishTheme.Font.caption())
                    .foregroundStyle(.secondary)
                Text(Date.now.formatted(.dateTime.month().day()))
                    .font(NourishTheme.Font.headline())
            }
        }
        .padding(.top, 8)
    }

    private var calorieRingSection: some View {
        HStack(alignment: .center, spacing: NourishTheme.Spacing.xl) {
            MacroRingView(
                calories: vm.todayCalories,
                target: user.dailyCalorieTarget,
                protein: vm.todayProtein,
                carbs: vm.todayCarbs,
                fat: vm.todayFat
            )
            VStack(alignment: .leading, spacing: 12) {
                CalorieStat(label: "Goal",      value: "\(user.dailyCalorieTarget)", unit: "kcal")
                CalorieStat(label: "Eaten",     value: "\(vm.todayCalories)", unit: "kcal", accent: true)
                CalorieStat(label: "Remaining", value: "\(max(0, user.dailyCalorieTarget - vm.todayCalories))", unit: "kcal")
                if healthKit.todayActiveCalories > 0 {
                    CalorieStat(label: "Burned", value: "\(Int(healthKit.todayActiveCalories))", unit: "kcal")
                }
            }
        }
        .padding()
        .nourishCard()
    }

    private var macroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macros today")
                .font(NourishTheme.Font.headline())
            MacroPillsView(
                protein: vm.todayProtein,
                carbs: vm.todayCarbs,
                fat: vm.todayFat,
                fiber: vm.todayFiber
            )
            MacroProgressBars(
                protein: vm.todayProtein, proteinTarget: user.dailyProteinTarget,
                carbs: vm.todayCarbs, carbsTarget: user.dailyCarbTarget,
                fat: vm.todayFat, fatTarget: user.dailyFatTarget
            )
        }
        .padding()
        .nourishCard()
    }

    private var healthMetricsSection: some View {
        Group {
            if healthKit.isAuthorized {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricTile(icon: "figure.walk", label: "Steps", value: "\(healthKit.todaySteps.formatted())", color: .blue)
                    MetricTile(icon: "flame.fill", label: "Active", value: "\(Int(healthKit.todayActiveCalories)) kcal", color: .orange)
                    MetricTile(icon: "moon.zzz.fill", label: "Sleep", value: "\(String(format: "%.1f", healthKit.lastNightSleep))h", color: .indigo)
                    MetricTile(icon: "heart.fill", label: "Resting HR", value: "\(Int(healthKit.heartRateResting)) bpm", color: .red)
                }
            }
        }
    }

    private var recentMealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's meals")
                    .font(NourishTheme.Font.headline())
                Spacer()
                NavigationLink("See all") {
                    MealHistoryView(user: user)
                }
                .font(NourishTheme.Font.caption())
                .foregroundStyle(NourishTheme.Color.primary)
            }
            if vm.todayMeals.isEmpty {
                EmptyMealsPrompt()
            } else {
                ForEach(vm.todayMeals.prefix(3)) { meal in
                    MealRowView(meal: meal)
                }
            }
        }
        .padding()
        .nourishCard()
    }

    private var insightsBannerSection: some View {
        Group {
            if let insight = vm.weeklyInsight {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Weekly insight", systemImage: "sparkles")
                        .font(NourishTheme.Font.caption())
                        .foregroundStyle(NourishTheme.Color.primary)
                    Text(insight)
                        .font(NourishTheme.Font.body())
                        .foregroundStyle(.primary)
                }
                .padding()
                .background(NourishTheme.Color.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.lg))
            }
        }
    }
}

// MARK: - Sub-views

private struct CalorieStat: View {
    let label: String; let value: String; let unit: String; var accent = false
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value).font(NourishTheme.Font.headline(accent ? 22 : 16))
                .foregroundStyle(accent ? NourishTheme.Color.primary : .primary)
            Text(unit).font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
            Spacer()
            Text(label).font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
        }
    }
}

private struct MetricTile: View {
    let icon: String; let label: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.title3)
            Text(value).font(NourishTheme.Font.headline()).foregroundStyle(.primary)
            Text(label).font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
    }
}

private struct MacroProgressBars: View {
    let protein: Double; let proteinTarget: Double
    let carbs: Double;   let carbsTarget: Double
    let fat: Double;     let fatTarget: Double

    var body: some View {
        VStack(spacing: 8) {
            MacroBar(label: "Protein", value: protein, target: proteinTarget, color: NourishTheme.Color.macro(.protein))
            MacroBar(label: "Carbs",   value: carbs,   target: carbsTarget,   color: NourishTheme.Color.macro(.carbs))
            MacroBar(label: "Fat",     value: fat,     target: fatTarget,     color: NourishTheme.Color.macro(.fat))
        }
    }
}

private struct MacroBar: View {
    let label: String; let value: Double; let target: Double; let color: Color
    private var progress: Double { min(1, value / max(1, target)) }
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value))g / \(Int(target))g").font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.15)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(color)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(NourishTheme.Animation.smooth, value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

private struct EmptyMealsPrompt: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife.circle").font(.system(size: 36)).foregroundStyle(NourishTheme.Color.primaryLight)
            Text("No meals logged yet").font(NourishTheme.Font.headline()).foregroundStyle(.secondary)
            Text("Tap + to log your first meal").font(NourishTheme.Font.body(13)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct MealRowView: View {
    let meal: MealEntry
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 8).fill(NourishTheme.Color.primaryLight)
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: meal.mealType.icon).foregroundStyle(NourishTheme.Color.primary))
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.mealName).font(NourishTheme.Font.headline(14)).lineLimit(1)
                Text(meal.loggedAt.formatted(.dateTime.hour().minute())).font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(meal.calories) kcal").font(NourishTheme.Font.headline(14)).foregroundStyle(NourishTheme.Color.primary)
                HealthScoreBadge(score: meal.healthScore, size: 28)
            }
        }
    }
}
