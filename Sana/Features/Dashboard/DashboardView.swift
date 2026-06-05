// Sana — DashboardView.swift
import SwiftUI
import SwiftData
import StoreKit

struct DashboardView: View {

    @Bindable var user: User
    @StateObject private var vm: DashboardViewModel
    @EnvironmentObject private var healthKit: HealthKitService
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @AppStorage("celebrated.streaks") private var celebratedStreaks: String = ""
    @State private var showingMilestone = false
    @State private var showingGoals = false
    @State private var showingPaywall = false
    @State private var showingMacroDetail: MacroType?
    @State private var shareImage: UIImage?
    @State private var showingShare = false

    private var isIPad: Bool { hSizeClass == .regular }

    init(user: User) {
        self.user = user
        _vm = StateObject(wrappedValue: DashboardViewModel(user: user))
    }

    private var adjustedCalorieTarget: Int {
        let bonus = Int(healthKit.todayActiveCalories * 0.5)
        return user.dailyCalorieTarget + bonus
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    dashboardHeader
                    heroDailySummaryCard
                    macroPillsSection
                    weightGoalSection
                    quickActionsRow
                    dailyScoreSection
                    aiInsightSection
                    smartSuggestionSection
                    todayMealsSection
                    hydrationFastingRow
                    healthMetricsSection
                    supplementSection
                    predictionSection
                    dailyTipSection
                    premiumNudge
                }
                .padding(.bottom, 32)
                .frame(maxWidth: isIPad ? 720 : .infinity)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .refreshable {
                await healthKit.refreshAll()
                await vm.retryInsights()
            }
            .background(SanaTheme.Color.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await vm.loadInsights() }
        .task(id: user.currentStreak) { checkStreakMilestone() }
        .sheet(isPresented: $showingGoals) { NutritionGoalsView(user: user) }
        .sheet(isPresented: $showingPaywall) { PaywallView() }
        .sheet(item: $showingMacroDetail) { macro in MacroDetailView(user: user, macro: macro) }
        .sheet(isPresented: $showingShare) {
            if let image = shareImage { ShareSheet(items: [image]) }
        }
        .overlay {
            if showingMilestone {
                StreakMilestoneView(streak: user.currentStreak) { showingMilestone = false }
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Sections

    private var dashboardHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.greeting)
                    .font(SanaTheme.Font.caption(13))
                    .foregroundStyle(.secondary)
                Text(user.name.components(separatedBy: " ").first ?? user.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .kerning(-0.6)
            }
            Spacer()
            HStack(spacing: 8) {
                if user.currentStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill").foregroundStyle(.orange).font(.caption2)
                        Text("\(user.currentStreak)d").font(SanaTheme.Font.caption(11)).foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                    .accessibilityLabel("\(user.currentStreak) day logging streak")
                }
                Button {
                    HapticService.impact(.light)
                    renderDailySummary()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(SanaTheme.Color.primary)
                }
                .accessibilityLabel("Share daily summary")
                NavigationLink(destination: ProfileView(user: user)) {
                    Circle()
                        .fill(SanaTheme.Color.primaryLight)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Text(user.name.prefix(1))
                                .font(SanaTheme.Font.headline())
                                .foregroundStyle(SanaTheme.Color.primary)
                        )
                }
                .accessibilityLabel("Open profile")
            }
        }
        .padding(.horizontal, SanaTheme.Spacing.lg)
        .padding(.top, isIPad ? 20 : 60)
        .padding(.bottom, SanaTheme.Spacing.sm)
    }

    // MARK: Hero Card — dark background, ring + macro bars

    private var heroDailySummaryCard: some View {
        Button { HapticService.impact(.light); showingGoals = true } label: {
            ZStack(alignment: .topTrailing) {
                // Subtle radial accent top-right
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [SanaTheme.Color.primary.opacity(0.3), .clear],
                            center: .center, startRadius: 0, endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(x: 40, y: -60)

                VStack(spacing: 20) {
                    // Ring + side stats
                    HStack(spacing: 20) {
                        calorieRing
                        heroSideStats
                    }
                    // Macro bars
                    heroMacroBars
                }
                .padding(24)
            }
            .background(Color.primary.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.xl))
            .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.xl).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, SanaTheme.Spacing.lg)
        .padding(.bottom, SanaTheme.Spacing.lg)
        .accessibilityLabel("Daily calorie summary. Tap to edit goals.")
    }

    private var calorieRing: some View {
        let eaten = Double(vm.todayCalories)
        let target = Double(adjustedCalorieTarget)
        let remaining = max(0, target - eaten)
        let progress = min(1, eaten / max(1, target))

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 12)
                .frame(width: 130, height: 130)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(SanaTheme.Color.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(-90))
                .animation(SanaTheme.Animation.bouncy, value: progress)
            VStack(spacing: 1) {
                Text("Left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .textCase(.uppercase)
                    .kerning(1)
                Text(Int(remaining).formatted())
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .kerning(-1)
                    .minimumScaleFactor(0.7)
                Text("kcal")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .frame(width: 130, height: 130)
    }

    private var heroSideStats: some View {
        let balance = adjustedCalorieTarget - vm.todayCalories
        let isDeficit = balance >= 0
        return VStack(alignment: .leading, spacing: 14) {
            HeroStatRow(label: "Eaten",  value: "\(vm.todayCalories.formatted())", unit: "kcal", dotColor: SanaTheme.Color.primary)
            HeroStatRow(label: "Burned", value: "\(Int(healthKit.todayActiveCalories).formatted())", unit: "kcal", dotColor: SanaTheme.Color.accent)
            HeroStatRow(label: isDeficit ? "Deficit" : "Surplus",
                        value: (isDeficit ? "−" : "+") + abs(balance).formatted(),
                        unit: "kcal",
                        dotColor: isDeficit ? SanaTheme.Color.primary : .orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Dark-mode color variants — always shown on the dark hero card regardless of system mode
    private static let heroProteinColor = Color(hex: "#7FB1FF") ?? Color("MacroProtein")
    private static let heroCarbsColor   = Color(hex: "#F0C36E") ?? Color("MacroCarbs")
    private static let heroFatColor     = Color(hex: "#FF9F8A") ?? Color("MacroFat")
    private static let heroFiberColor   = Color(hex: "#A8E1A0") ?? Color("MacroFiber")

    private var heroMacroBars: some View {
        HStack(spacing: 14) {
            DarkMacroBar(label: "Protein", value: vm.todayProtein,  target: user.dailyProteinTarget, color: Self.heroProteinColor)
            DarkMacroBar(label: "Carbs",   value: vm.todayCarbs,    target: user.dailyCarbTarget,    color: Self.heroCarbsColor)
            DarkMacroBar(label: "Fat",     value: vm.todayFat,      target: user.dailyFatTarget,     color: Self.heroFatColor)
            DarkMacroBar(label: "Fiber",   value: vm.todayFiber,    target: user.dailyFiberTarget,   color: Self.heroFiberColor)
        }
    }

    // MARK: Weight Goal / Calorie Deficit

    private var weightGoalSection: some View {
        WeightGoalCard(user: user, adjustedCalorieTarget: adjustedCalorieTarget)
            .padding(.horizontal, SanaTheme.Spacing.lg)
            .padding(.bottom, SanaTheme.Spacing.lg)
    }

    // MARK: Quick Actions

    @ViewBuilder
    private var quickActionsRow: some View {
        let snapCard = QuickActionCard(icon: "camera.fill", label: "Snap meal", sub: "AI estimates", color: SanaTheme.Color.primary) { router.selectedTab = .log }
        let coachCard = QuickActionCard(icon: "sparkles", label: "Ask Coach", sub: "Get advice", color: SanaTheme.Color.accent) { router.selectedTab = .coach }
        if isIPad {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                snapCard
                coachCard
                QuickActionCard(icon: "calendar", label: "Meal Plan", sub: "Weekly view", color: .indigo) { router.selectedTab = .plan }
                QuickActionCard(icon: "chart.bar.fill", label: "Insights", sub: "Your trends", color: .teal) { router.selectedTab = .insights }
            }
            .padding(.horizontal, SanaTheme.Spacing.lg)
            .padding(.bottom, SanaTheme.Spacing.lg)
        } else {
            HStack(spacing: 10) {
                snapCard
                coachCard
            }
            .padding(.horizontal, SanaTheme.Spacing.lg)
            .padding(.bottom, SanaTheme.Spacing.lg)
        }
    }

    // MARK: Daily Score (tappable → WeeklyReportView, per design spec)

    private var dailyScoreSection: some View {
        NavigationLink(destination: WeeklyReportView(user: user)) {
            DailyScoreCard(user: user)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, SanaTheme.Spacing.lg)
        .padding(.bottom, SanaTheme.Spacing.lg)
        .accessibilityHint("Opens your weekly nutrition report")
    }

    // MARK: AI Insight

    @ViewBuilder
    private var aiInsightSection: some View {
        if vm.isLoadingInsights {
            HStack(spacing: 12) {
                ProgressView().tint(SanaTheme.Color.primary)
                Text("Generating your weekly insight…")
                    .font(SanaTheme.Font.body(14))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SanaTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
            .padding(.horizontal, SanaTheme.Spacing.lg)
            .padding(.bottom, SanaTheme.Spacing.lg)
        } else if let errorMsg = vm.insightError {
            ErrorBanner(message: errorMsg, retry: { Task { await vm.retryInsights() } })
                .padding(.horizontal, SanaTheme.Spacing.lg)
                .padding(.bottom, SanaTheme.Spacing.lg)
        } else if let insight = vm.weeklyInsight {
            AIInsightCard(insight: insight, onAskCoach: { router.selectedTab = .coach })
                .padding(.horizontal, SanaTheme.Spacing.lg)
                .padding(.bottom, SanaTheme.Spacing.lg)
        }
    }

    // MARK: Smart Meal Suggestion (local, offline)

    private var smartSuggestionSection: some View {
        SmartSuggestionCard(user: user)
            .padding(.horizontal, SanaTheme.Spacing.lg)
            .padding(.bottom, SanaTheme.Spacing.lg)
    }

    // MARK: Today's Meals

    private var todayMealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's meals")
                    .font(SanaTheme.Font.headline())
                Spacer()
                NavigationLink("See all") { MealHistoryView(user: user) }
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(SanaTheme.Color.primary)
            }
            if vm.todayMeals.isEmpty {
                EmptyMealsPrompt()
            } else {
                ForEach(vm.todayMeals.prefix(isIPad ? 5 : 3)) { meal in
                    MealRowView(meal: meal)
                        .contextMenu {
                            Button(role: .destructive) {
                                HapticService.destructive()
                                user.mealEntries.removeAll { $0.id == meal.id }
                            } label: {
                                Label("Delete meal", systemImage: "trash")
                            }
                        }
                }
                // Design spec: dashed "Add meal" stub at bottom of list
                Button {
                    HapticService.impact(.light)
                    router.showingMealLog = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 15, weight: .medium))
                        Text("Add meal").font(SanaTheme.Font.headline(14))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: SanaTheme.Radius.md)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(SanaTheme.Color.hairlineStrong)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(SanaTheme.Spacing.lg)
        .background(SanaTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
        .padding(.horizontal, SanaTheme.Spacing.lg)
        .padding(.bottom, SanaTheme.Spacing.lg)
    }

    // MARK: Hydration + Fasting (2-column side-by-side — design spec)

    private var hydrationFastingRow: some View {
        HStack(alignment: .top, spacing: 10) {
            WaterTrackerView(user: user)
            FastingTrackerView()
        }
        .padding(.horizontal, SanaTheme.Spacing.lg)
        .padding(.bottom, SanaTheme.Spacing.lg)
    }

    // MARK: Apple Health Metrics

    private var healthMetricsSection: some View {
        Group {
            if healthKit.isAuthorized {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .accessibilityHidden(true)
                        Text("Apple Health")
                            .font(SanaTheme.Font.headline(13))
                        Spacer()
                        // Design spec: health metrics card navigates to BodyMetricsView
                        NavigationLink(destination: BodyMetricsView(user: user)) {
                            Text("Body metrics")
                                .font(SanaTheme.Font.caption(11))
                                .foregroundStyle(SanaTheme.Color.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(SanaTheme.Color.primaryLight)
                                .clipShape(Capsule())
                        }
                        .accessibilityLabel("Open body metrics")
                    }
                    HStack(spacing: 0) {
                        HealthMetricCell(label: "Steps",  value: healthKit.todaySteps.formatted(), unit: "/10k", color: SanaTheme.Color.primary)
                        Divider().frame(height: 36).opacity(0.2)
                        HealthMetricCell(label: "Active", value: "\(Int(healthKit.todayActiveCalories))", unit: "kcal", color: SanaTheme.Color.accent)
                        Divider().frame(height: 36).opacity(0.2)
                        HealthMetricCell(label: "Sleep",  value: String(format: "%.1f", healthKit.lastNightSleep), unit: "hrs", color: Color.indigo)
                        if isIPad && healthKit.heartRateResting > 0 {
                            Divider().frame(height: 36).opacity(0.2)
                            HealthMetricCell(label: "Resting HR", value: "\(Int(healthKit.heartRateResting))", unit: "bpm", color: .red)
                        }
                    }
                }
                .padding(SanaTheme.Spacing.lg)
                .background(SanaTheme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
                .padding(.horizontal, SanaTheme.Spacing.lg)
                .padding(.bottom, SanaTheme.Spacing.lg)
            }
        }
    }

    // MARK: Supplements

    private var supplementSection: some View {
        SupplementDashboardCard()
            .padding(.horizontal, SanaTheme.Spacing.lg)
            .padding(.bottom, SanaTheme.Spacing.lg)
    }

    // MARK: Macro Pills (tappable → MacroDetailView drill-down)

    private var macroPillsSection: some View {
        HStack(spacing: SanaTheme.Spacing.sm) {
            ForEach([MacroType.protein, .carbs, .fat, .fiber], id: \.self) { macro in
                let value: Double = {
                    switch macro {
                    case .protein: return vm.todayProtein
                    case .carbs:   return vm.todayCarbs
                    case .fat:     return vm.todayFat
                    case .fiber:   return vm.todayFiber
                    default:       return 0
                    }
                }()
                let target = macro.target(for: user)
                let progress = min(1, value / max(1, target))

                Button { HapticService.selection(); showingMacroDetail = macro } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .stroke(macro.color.opacity(0.15), lineWidth: 3)
                                .frame(width: 36, height: 36)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(macro.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 36, height: 36)
                                .animation(SanaTheme.Animation.bouncy, value: progress)
                            Image(systemName: macro.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(macro.color)
                        }
                        Text("\(Int(value))g")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                        Text(macro.localizedName)
                            .font(SanaTheme.Font.caption(10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(SanaTheme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.md).stroke(SanaTheme.Color.hairline, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(macro.localizedName): \(Int(value)) of \(Int(target)) grams. Tap to view details.")
            }
        }
        .padding(.horizontal, SanaTheme.Spacing.lg)
        .padding(.bottom, SanaTheme.Spacing.lg)
    }

    // MARK: Daily Tip

    private var dailyTipSection: some View {
        DailyTipCard()
            .padding(.horizontal, SanaTheme.Spacing.lg)
            .padding(.bottom, SanaTheme.Spacing.lg)
    }

    // MARK: Prediction

    private var predictionSection: some View {
        Group {
            CaloriePredictionCard(user: user)
                .padding(.horizontal, SanaTheme.Spacing.lg)
                .padding(.bottom, SanaTheme.Spacing.lg)
        }
    }

    // MARK: Premium Nudge

    @ViewBuilder
    private var premiumNudge: some View {
        if user.subscriptionTier == .free {
        Button { HapticService.impact(.light); showingPaywall = true } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(SanaTheme.Color.accent)
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "sparkles").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Try Sana Premium")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Unlimited scans · Meal plans · 7-day free trial")
                        .font(SanaTheme.Font.caption(12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(SanaTheme.Spacing.lg)
            .background(SanaTheme.Color.elevated)
            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg).stroke(SanaTheme.Color.accent.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, SanaTheme.Spacing.lg)
        .padding(.bottom, SanaTheme.Spacing.lg)
        } // end if user.subscriptionTier == .free
    }

    // MARK: - Helpers

    @MainActor
    private func renderDailySummary() {
        // Compute the daily score inline (mirrors DailyScoreCard logic)
        let target = user.dailyCalorieTarget
        let calScore = target > 0
            ? max(0, Int(100 - abs(1.0 - Double(vm.todayCalories) / Double(target)) * 200))
            : 50
        let protScore = user.dailyProteinTarget > 0
            ? min(100, Int(vm.todayProtein / user.dailyProteinTarget * 100))
            : 0
        let hydScore = user.dailyWaterGoalMl > 0
            ? min(100, user.todayWaterMl * 100 / user.dailyWaterGoalMl)
            : 0
        let todayMeals = vm.todayMeals
        let qualScore = todayMeals.isEmpty ? 0
            : todayMeals.map { $0.healthScore }.reduce(0, +) / todayMeals.count
        let actScore: Int = healthKit.isAuthorized
            ? min(100, healthKit.todaySteps * 100 / 8000)
            : 50
        let totalScore = Int(Double(calScore) * 0.25 + Double(protScore) * 0.25 +
                             Double(hydScore) * 0.20 + Double(qualScore) * 0.20 +
                             Double(actScore) * 0.10)

        let card = DailySummaryShareCard(
            caloriesEaten: vm.todayCalories,
            caloriesTarget: adjustedCalorieTarget,
            protein: vm.todayProtein,
            proteinTarget: user.dailyProteinTarget,
            carbs: vm.todayCarbs,
            carbsTarget: user.dailyCarbTarget,
            fat: vm.todayFat,
            fatTarget: user.dailyFatTarget,
            waterMl: user.todayWaterMl,
            waterGoalMl: user.dailyWaterGoalMl,
            steps: healthKit.todaySteps,
            dailyScore: totalScore,
            streak: user.currentStreak,
            userName: user.name,
            isImperial: user.unitSystem == .imperial
        )
        let renderer = ImageRenderer(content: card.padding(20).background(Color(red: 0.06, green: 0.06, blue: 0.06)))
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            shareImage = image
            showingShare = true
        }
    }

    private func checkStreakMilestone() {
        let streak = user.currentStreak
        guard StreakMilestoneView.milestone(for: streak) != nil else { return }
        let key = "\(streak)"
        guard !celebratedStreaks.components(separatedBy: ",").contains(key) else { return }
        celebratedStreaks = (celebratedStreaks.isEmpty ? key : celebratedStreaks + "," + key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(SanaTheme.Animation.smooth) { showingMilestone = true }
        }
        if streak == 7 || streak == 14 || streak == 30 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
}

// MARK: - Hero sub-views

private struct HeroStatRow: View {
    let label: String
    let value: String
    let unit: String
    let dotColor: Color
    var muted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle().fill(dotColor).frame(width: 6, height: 6).opacity(muted ? 0.5 : 1)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(muted ? 0.4 : 0.65))
                    .textCase(.uppercase)
                    .kerning(0.8)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(muted ? 0.65 : 1))
                    .kerning(-0.5)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }
}

private struct DarkMacroBar: View {
    let label: String
    let value: Double
    let target: Double
    let color: Color

    private var progress: Double { min(1, value / max(1, target)) }
    private var pct: Int { Int(progress * 100) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))
                .textCase(.uppercase)
                .kerning(0.4)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(Int(value))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("/\(Int(target))g")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.08)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(SanaTheme.Animation.smooth, value: progress)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(Int(value)) of \(Int(target)) grams, \(pct)%")
    }
}

private struct QuickActionCard: View {
    let icon: String
    let label: String
    let sub: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticService.impact(.light)
            action()
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(color)
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white))
                    .shadow(color: color.opacity(0.4), radius: 8, y: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(sub)
                        .font(SanaTheme.Font.caption(11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(SanaTheme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(SanaTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(sub)
    }
}

private struct AIInsightCard: View {
    let insight: String
    var onAskCoach: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "sparkles")
                .font(.system(size: 100, weight: .regular))
                .foregroundStyle(.white.opacity(0.12))
                .offset(x: 20, y: -10)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                    Text("AI Insight")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.1)
                        .textCase(.uppercase)
                }
                .foregroundStyle(.white.opacity(0.85))

                Text(insight)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
                    .kerning(-0.3)
                    .fixedSize(horizontal: false, vertical: true)

                // Design spec: action pill buttons
                HStack(spacing: 8) {
                    Button {
                        HapticService.selection()
                        onAskCoach?()
                    } label: {
                        Text("Show snack ideas")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.22))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        HapticService.selection()
                        onAskCoach?()
                    } label: {
                        Text("Ask coach")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(SanaTheme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            LinearGradient(
                colors: [SanaTheme.Color.accent, SanaTheme.Color.accent.opacity(0.8)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
    }
}

private struct HealthMetricCell: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .kerning(-0.4)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }
}

private struct EmptyMealsPrompt: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 36))
                .foregroundStyle(SanaTheme.Color.primary)
                .accessibilityHidden(true)
            Text("No meals logged yet")
                .font(SanaTheme.Font.headline())
                .foregroundStyle(.secondary)
            Text("Tap + to log your first meal")
                .font(SanaTheme.Font.body(13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct MealRowView: View {
    let meal: MealEntry
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14)
                .fill(SanaTheme.Color.primaryLight)
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: meal.mealType.icon).foregroundStyle(SanaTheme.Color.primary).font(.system(size: 22)))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(meal.mealType.rawValue.uppercased() + " · " + meal.loggedAt.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .kerning(0.4)
                }
                Text(meal.mealName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(meal.calories) kcal")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("P \(Int(meal.protein))g")
                        .font(SanaTheme.Font.caption(11))
                        .foregroundStyle(.secondary)
                    Text("C \(Int(meal.carbohydrates))g")
                        .font(SanaTheme.Font.caption(11))
                        .foregroundStyle(.secondary)
                    Text("F \(Int(meal.fat))g")
                        .font(SanaTheme.Font.caption(11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HealthScoreBadge(score: meal.healthScore, size: 42)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(meal.mealType.rawValue), \(meal.mealName), " +
            "\(meal.calories) calories, " +
            "protein \(Int(meal.protein))g, carbs \(Int(meal.carbohydrates))g, fat \(Int(meal.fat))g, " +
            "health score \(meal.healthScore)"
        )
    }
}
