// Sana — MealPlanView.swift
import SwiftUI
import SwiftData

struct MealPlanView: View {

    @Bindable var user: User
    @StateObject private var vm: MealPlanViewModel

    init(user: User) {
        self.user = user
        _vm = StateObject(wrappedValue: MealPlanViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isGenerating {
                    SanaLoadingView(
                        message: "Building your meal plan…",
                        subtitle: "Sana is personalising 3 days of meals around your goals"
                    )
                } else if let error = vm.error, vm.currentPlan == nil {
                    SanaErrorView(message: error, retryLabel: "Try again") {
                        HapticService.startAction()
                        Task { await vm.generatePlan() }
                    }
                } else if let plan = vm.currentPlan {
                    WeekPlanView(plan: plan, vm: vm)
                        .id(plan.id)   // reset @State when a new plan is generated
                } else {
                    EmptyPlanView(onGenerate: { HapticService.startAction(); Task { await vm.generatePlan() } })
                }
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Meal plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if vm.currentPlan != nil && !vm.isGenerating {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticService.startAction()
                            Task { await vm.generatePlan() }
                        } label: {
                            Label("Regenerate", systemImage: "arrow.clockwise")
                        }
                        .foregroundStyle(SanaTheme.Color.primary)
                        .accessibilityLabel("Regenerate meal plan")
                    }
                }
            }
        }
        .task { vm.loadExistingPlan() }
    }
}

private struct WeekPlanView: View {
    let plan: MealPlan
    @ObservedObject var vm: MealPlanViewModel
    @State private var selectedDayIndex = -1

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(plan.days.sorted(by: { $0.dayIndex < $1.dayIndex })) { day in
                        DayTab(day: day, isSelected: selectedDayIndex == day.dayIndex) {
                            withAnimation(SanaTheme.Animation.snappy) { selectedDayIndex = day.dayIndex }
                        }
                    }
                }
                .padding(.horizontal, SanaTheme.Spacing.md)
                .padding(.vertical, 12)
            }
            Divider()

            if let day = plan.days.first(where: { $0.dayIndex == selectedDayIndex }) {
                ScrollView {
                    VStack(spacing: SanaTheme.Spacing.md) {
                        DayCalorieSummary(day: day, target: vm.user.dailyCalorieTarget)
                        if let meal = day.breakfastMeal { PlannedMealCard(meal: meal, vm: vm) { vm.logPlannedMeal(meal) } }
                        if let meal = day.lunchMeal     { PlannedMealCard(meal: meal, vm: vm) { vm.logPlannedMeal(meal) } }
                        if let meal = day.dinnerMeal    { PlannedMealCard(meal: meal, vm: vm) { vm.logPlannedMeal(meal) } }
                        ForEach(day.snackMeals) { snack in PlannedMealCard(meal: snack, vm: vm) { vm.logPlannedMeal(snack) } }
                    }
                    .padding(SanaTheme.Spacing.md)
                }
            }
        }
        .onAppear {
            if selectedDayIndex == -1,
               let first = plan.days.sorted(by: { $0.dayIndex < $1.dayIndex }).first {
                selectedDayIndex = first.dayIndex
            }
        }
    }
}

private struct DayTab: View {
    let day: MealPlanDay; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button {
            HapticService.selection()
            action()
        } label: {
            VStack(spacing: 3) {
                Text(day.dayName.prefix(3))
                    .font(SanaTheme.Font.caption(11))
                    .foregroundStyle(isSelected ? SanaTheme.Color.primary : .secondary)
                Text(day.date.formatted(.dateTime.day()))
                    .font(SanaTheme.Font.headline(15))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? SanaTheme.Color.primary : Color.clear)
                    .clipShape(Circle())
            }
        }
    }
}

private struct DayCalorieSummary: View {
    let day: MealPlanDay; let target: Int
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.dayName).font(SanaTheme.Font.headline(18))
                Text("\(day.totalCalories) kcal planned")
                    .font(SanaTheme.Font.body(14)).foregroundStyle(.secondary)
            }
            Spacer()
            CircleProgress(value: Double(day.totalCalories), total: Double(target), color: SanaTheme.Color.primary)
        }
        .padding()
        .nourishCard()
    }
}

private struct CircleProgress: View {
    let value: Double; let total: Double; let color: Color
    private var pct: Double { min(1, value / max(1, total)) }
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 5)
            Circle().trim(from: 0, to: pct)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(pct * 100))%")
                .font(SanaTheme.Font.caption(10)).foregroundStyle(color)
        }
        .frame(width: 50, height: 50)
    }
}

private struct PlannedMealCard: View {
    @Bindable var meal: PlannedMeal
    @ObservedObject var vm: MealPlanViewModel
    let onLog: () -> Void
    @State private var isExpanded = false
    @State private var showingReplace = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(meal.mealType.localizedName)
                            .font(SanaTheme.Font.caption())
                            .foregroundStyle(SanaTheme.Color.primary)
                        if meal.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green).font(.caption)
                        }
                    }
                    Text(meal.name).font(SanaTheme.Font.headline())
                    Text("\(meal.calories) kcal · \(meal.prepTimeMinutes) min")
                        .font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    // Replace button
                    Button {
                        HapticService.selection()
                        showingReplace = true
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Replace \(meal.name)")
                    Button {
                        HapticService.toggle()
                        withAnimation(SanaTheme.Animation.snappy) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()

            if isExpanded {
                Divider().padding(.horizontal)
                VStack(alignment: .leading, spacing: 12) {
                    Text(meal.mealDescription)
                        .font(SanaTheme.Font.body(14)).foregroundStyle(.secondary)
                    if !meal.ingredients.isEmpty {
                        Text("Ingredients")
                            .font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                        FlowLayout(items: meal.ingredients) { ing in
                            Text(ing)
                                .font(SanaTheme.Font.caption(12))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(SanaTheme.Color.primaryLight)
                                .clipShape(Capsule())
                        }
                    }
                    if !meal.recipeSteps.isEmpty {
                        Text("Recipe")
                            .font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                        Text(meal.recipeSteps).font(SanaTheme.Font.body(13))
                    }
                    HStack {
                        Toggle("Mark as eaten", isOn: $meal.isCompleted)
                            .font(SanaTheme.Font.body(14))
                            .tint(SanaTheme.Color.primary)
                        Spacer()
                        if !meal.isCompleted {
                            Button { onLog() } label: {
                                Label("Log now", systemImage: "plus.circle.fill")
                                    .font(SanaTheme.Font.caption(13))
                                    .foregroundStyle(SanaTheme.Color.primary)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .nourishCard()
        .animation(SanaTheme.Animation.snappy, value: isExpanded)
        .sheet(isPresented: $showingReplace) {
            ReplaceMealSheet(meal: meal, vm: vm)
        }
    }
}

// MARK: - Replace Meal Sheet

private struct ReplaceMealSheet: View {
    let meal: PlannedMeal
    @ObservedObject var vm: MealPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var preference = ""
    @FocusState private var isFocused: Bool

    private let quickPrefs = [
        "Something lighter", "Higher protein", "Vegan option",
        "No cooking needed", "Something different"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SanaTheme.Spacing.lg) {

                    // Current meal pill
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Replacing")
                            .font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            Image(systemName: meal.mealType.icon)
                                .foregroundStyle(SanaTheme.Color.primary)
                            Text(meal.name)
                                .font(SanaTheme.Font.headline())
                            Spacer()
                            Text("\(meal.calories) kcal")
                                .font(SanaTheme.Font.caption())
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(SanaTheme.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
                    }

                    // Preference text field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What would you prefer? (optional)")
                            .font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                        TextField("e.g. something lighter, no dairy…", text: $preference, axis: .vertical)
                            .font(SanaTheme.Font.body())
                            .lineLimit(1...3)
                            .padding(12)
                            .background(SanaTheme.Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
                            .focused($isFocused)
                    }

                    // Quick preference chips
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick picks")
                            .font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                        FlowLayout(items: quickPrefs) { pref in
                            Button {
                                HapticService.selection()
                                preference = pref
                                isFocused = false
                            } label: {
                                Text(pref)
                                    .font(SanaTheme.Font.caption(12))
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(preference == pref
                                        ? SanaTheme.Color.primary
                                        : SanaTheme.Color.primaryLight)
                                    .foregroundStyle(preference == pref ? .white : SanaTheme.Color.primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    if let err = vm.error {
                        Text(err)
                            .font(SanaTheme.Font.caption())
                            .foregroundStyle(.red)
                            .padding()
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.sm))
                    }

                    // Replace button
                    Button {
                        isFocused = false
                        Task {
                            await vm.replaceMeal(meal, preference: preference)
                            if vm.error == nil { dismiss() }
                        }
                    } label: {
                        HStack {
                            if vm.isReplacingMeal {
                                ProgressView().tint(.white).scaleEffect(0.85)
                                Text("Finding a replacement…")
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Replace with something new")
                            }
                        }
                        .font(SanaTheme.Font.headline())
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NourishButtonStyle())
                    .disabled(vm.isReplacingMeal)
                }
                .padding(SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Change Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(vm.isReplacingMeal)
                }
            }
        }
    }
}

private struct EmptyPlanView: View {
    let onGenerate: () -> Void
    var body: some View {
        SanaEmptyView(
            icon: "calendar.badge.plus",
            title: "No meal plan yet",
            subtitle: "Get a personalised 3-day plan built around your calorie target, dietary style, and allergies.",
            features: [
                "Breakfast, lunch, dinner + snacks",
                "Prep times and ingredient lists",
                "One-tap to log any meal",
                "Swap any meal you don't like"
            ],
            actionLabel: "Generate my plan",
            action: onGenerate
        )
    }
}

struct FlowLayout<T: Hashable, Content: View>: View {
    let items: [T]; let content: (T) -> Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { content($0) }
        }
    }
}
