// Sana — EditProfileView.swift
import SwiftUI
import SwiftData

struct EditProfileView: View {

    @Bindable var user: User
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var weightKg: Double
    @State private var heightCm: Double
    @State private var activityLevel: ActivityLevel
    @State private var primaryGoal: NutritionGoal
    @State private var dietaryStyle: DietaryStyle
    @State private var dailyWaterGoalMl: Int
    @State private var useCustomMacros: Bool
    @State private var customProtein: Double
    @State private var customCarbs: Double
    @State private var customFat: Double

    init(user: User) {
        self.user = user
        _name            = State(initialValue: user.name)
        _weightKg        = State(initialValue: user.weightKg)
        _heightCm        = State(initialValue: user.heightCm)
        _activityLevel   = State(initialValue: user.activityLevel)
        _primaryGoal     = State(initialValue: user.primaryGoal)
        _dietaryStyle    = State(initialValue: user.dietaryStyle)
        _dailyWaterGoalMl = State(initialValue: user.dailyWaterGoalMl)
        _useCustomMacros  = State(initialValue: user.useCustomMacros)
        _customProtein    = State(initialValue: user.dailyProteinTarget)
        _customCarbs      = State(initialValue: user.dailyCarbTarget)
        _customFat        = State(initialValue: user.dailyFatTarget)
    }

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                bodySection
                goalsSection
                macroTargetsSection
                waterSection
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(SanaTheme.Font.headline())
                        .foregroundStyle(SanaTheme.Color.primary)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section("Name") {
            TextField("Your name", text: $name)
                .font(SanaTheme.Font.body())
        }
    }

    private var bodySection: some View {
        Section("Body") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Height: \(Int(heightCm)) cm")
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(.secondary)
                Slider(value: $heightCm, in: 140...220, step: 1)
                    .tint(SanaTheme.Color.primary)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Weight: \(String(format: "%.1f", weightKg)) kg")
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(.secondary)
                Slider(value: $weightKg, in: 40...160, step: 0.5)
                    .tint(SanaTheme.Color.primary)
            }
            .padding(.vertical, 4)

            Picker("Activity level", selection: $activityLevel) {
                ForEach(ActivityLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .font(SanaTheme.Font.body())
        }
    }

    private var goalsSection: some View {
        Section("Goals") {
            Picker("Primary goal", selection: $primaryGoal) {
                ForEach(NutritionGoal.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .font(SanaTheme.Font.body())

            Picker("Dietary style", selection: $dietaryStyle) {
                ForEach(DietaryStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .font(SanaTheme.Font.body())

            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated calories")
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(.secondary)
                Text("\(estimatedCalories) kcal / day")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(SanaTheme.Color.primary)
            }
            .padding(.vertical, 4)
        }
    }

    private var macroTargetsSection: some View {
        Section {
            Toggle(isOn: $useCustomMacros) {
                Label("Custom macro targets", systemImage: "slider.horizontal.3")
                    .font(SanaTheme.Font.body())
            }
            .tint(SanaTheme.Color.primary)

            if useCustomMacros {
                macroSlider(label: "Protein", value: $customProtein, range: 50...300, unit: "g")
                macroSlider(label: "Carbs",   value: $customCarbs,   range: 50...500, unit: "g")
                macroSlider(label: "Fat",     value: $customFat,     range: 20...200, unit: "g")
            } else {
                let p = Int(estimatedCalories) > 0 ? Int(Double(weightKg) * 1.6) : 0
                let c = Int(Double(estimatedCalories) * 0.45 / 4)
                let f = Int(Double(estimatedCalories) * 0.30 / 9)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-calculated from your goals")
                        .font(SanaTheme.Font.caption())
                        .foregroundStyle(.secondary)
                    Text("Protein \(p)g · Carbs \(c)g · Fat \(f)g")
                        .font(SanaTheme.Font.body(14))
                        .foregroundStyle(SanaTheme.Color.primary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Nutrition targets")
        }
    }

    private func macroSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value.wrappedValue))\(unit)")
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(SanaTheme.Color.primary)
            }
            Slider(value: value, in: range, step: 5)
                .tint(SanaTheme.Color.primary)
        }
        .padding(.vertical, 2)
    }

    private var waterSection: some View {
        Section("Water goal") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily target: \(dailyWaterGoalMl) ml")
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { Double(dailyWaterGoalMl) },
                    set: { dailyWaterGoalMl = Int($0) }
                ), in: 1000...4000, step: 100)
                .tint(.blue)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Logic

    private var estimatedCalories: Int {
        activityLevel.estimatedCalories(for: weightKg, goal: primaryGoal)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        user.name = trimmed
        user.weightKg = weightKg
        user.heightCm = heightCm
        user.activityLevel = activityLevel
        user.primaryGoal = primaryGoal
        user.dietaryStyle = dietaryStyle
        user.dailyWaterGoalMl = dailyWaterGoalMl
        user.useCustomMacros = useCustomMacros
        let calories = estimatedCalories
        user.dailyCalorieTarget = calories
        if useCustomMacros {
            user.dailyProteinTarget = customProtein
            user.dailyCarbTarget = customCarbs
            user.dailyFatTarget = customFat
        } else {
            user.dailyProteinTarget = weightKg * 1.6
            user.dailyCarbTarget = Double(calories) * 0.45 / 4
            user.dailyFatTarget = Double(calories) * 0.30 / 9
        }
        dismiss()
    }
}

private struct EditProfilePreview: View {
    let container: ModelContainer
    let user: User
    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let c = try! ModelContainer(for: User.self, configurations: config)
        let u = User(name: "Preview User", email: "preview@test.com")
        c.mainContext.insert(u)
        container = c; user = u
    }
    var body: some View {
        EditProfileView(user: user)
            .modelContainer(container)
    }
}

#Preview { EditProfilePreview() }
