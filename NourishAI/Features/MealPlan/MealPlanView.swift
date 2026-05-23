// NourishAI — MealPlanView.swift
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
                    GeneratingPlanView()
                } else if let plan = vm.currentPlan {
                    WeekPlanView(plan: plan, vm: vm)
                } else {
                    EmptyPlanView(onGenerate: { Task { await vm.generatePlan() } })
                }
            }
            .background(NourishTheme.Color.background)
            .navigationTitle("Meal plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if vm.currentPlan != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { Task { await vm.generatePlan() } } label: {
                            Label("Regenerate", systemImage: "arrow.clockwise")
                        }
                        .foregroundStyle(NourishTheme.Color.primary)
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
                            withAnimation(NourishTheme.Animation.snappy) { selectedDayIndex = day.dayIndex }
                        }
                    }
                }
                .padding(.horizontal, NourishTheme.Spacing.md)
                .padding(.vertical, 12)
            }
            Divider()

            if let day = plan.days.first(where: { $0.dayIndex == selectedDayIndex }) {
                ScrollView {
                    VStack(spacing: NourishTheme.Spacing.md) {
                        DayCalorieSummary(day: day, target: vm.user.dailyCalorieTarget)
                        if let meal = day.breakfastMeal { PlannedMealCard(meal: meal) }
                        if let meal = day.lunchMeal     { PlannedMealCard(meal: meal) }
                        if let meal = day.dinnerMeal    { PlannedMealCard(meal: meal) }
                        ForEach(day.snackMeals) { PlannedMealCard(meal: $0) }
                    }
                    .padding(NourishTheme.Spacing.md)
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
        Button(action: action) {
            VStack(spacing: 3) {
                Text(day.dayName.prefix(3))
                    .font(NourishTheme.Font.caption(11))
                    .foregroundStyle(isSelected ? NourishTheme.Color.primary : .secondary)
                Text(day.date.formatted(.dateTime.day()))
                    .font(NourishTheme.Font.headline(15))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? NourishTheme.Color.primary : Color.clear)
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
                Text(day.dayName).font(NourishTheme.Font.headline(18))
                Text("\(day.totalCalories) kcal planned")
                    .font(NourishTheme.Font.body(14)).foregroundStyle(.secondary)
            }
            Spacer()
            CircleProgress(value: Double(day.totalCalories), total: Double(target), color: NourishTheme.Color.primary)
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
                .font(NourishTheme.Font.caption(10)).foregroundStyle(color)
        }
        .frame(width: 50, height: 50)
    }
}

private struct PlannedMealCard: View {
    @Bindable var meal: PlannedMeal
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(meal.mealType.rawValue)
                            .font(NourishTheme.Font.caption())
                            .foregroundStyle(NourishTheme.Color.primary)
                        if meal.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green).font(.caption)
                        }
                    }
                    Text(meal.name).font(NourishTheme.Font.headline())
                    Text("\(meal.calories) kcal · \(meal.prepTimeMinutes) min")
                        .font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(NourishTheme.Animation.snappy) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            if isExpanded {
                Divider().padding(.horizontal)
                VStack(alignment: .leading, spacing: 12) {
                    Text(meal.mealDescription)
                        .font(NourishTheme.Font.body(14)).foregroundStyle(.secondary)
                    if !meal.ingredients.isEmpty {
                        Text("Ingredients")
                            .font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
                        FlowLayout(items: meal.ingredients) { ing in
                            Text(ing)
                                .font(NourishTheme.Font.caption(12))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(NourishTheme.Color.primaryLight)
                                .clipShape(Capsule())
                        }
                    }
                    if !meal.recipeSteps.isEmpty {
                        Text("Recipe")
                            .font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
                        Text(meal.recipeSteps).font(NourishTheme.Font.body(13))
                    }
                    Toggle("Mark as eaten", isOn: $meal.isCompleted)
                        .font(NourishTheme.Font.body(14))
                        .tint(NourishTheme.Color.primary)
                }
                .padding()
            }
        }
        .nourishCard()
        .animation(NourishTheme.Animation.snappy, value: isExpanded)
    }
}

private struct EmptyPlanView: View {
    let onGenerate: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60)).foregroundStyle(NourishTheme.Color.primaryLight)
            Text("No meal plan yet").font(NourishTheme.Font.headline(22))
            Text("Generate a personalised 3-day meal plan tailored to your goals, preferences, and nutritional needs.")
                .font(NourishTheme.Font.body()).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Button("Generate my plan", action: onGenerate)
                .buttonStyle(NourishButtonStyle()).padding(.horizontal, 40)
        }
    }
}

private struct GeneratingPlanView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.5).tint(NourishTheme.Color.primary)
            Text("Building your meal plan…")
                .font(NourishTheme.Font.headline()).foregroundStyle(NourishTheme.Color.primary)
            Text("Claude is personalising 3 days of meals for you")
                .font(NourishTheme.Font.body(14)).foregroundStyle(.secondary)
        }
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
