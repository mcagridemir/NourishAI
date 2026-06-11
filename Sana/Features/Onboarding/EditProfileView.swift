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
    @State private var country: String
    @State private var healthConditions: Set<String>
    @State private var allergies: Set<String>
    @State private var unitSystem: UnitSystem
    @State private var enableWeightTarget: Bool
    @State private var targetWeightKg: Double
    @State private var biologicalSex: BiologicalSex
    @State private var hasDOB: Bool
    @State private var dateOfBirth: Date

    private static let defaultDOB: Date =
        Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now

    init(user: User) {
        self.user = user
        _name             = State(initialValue: user.name)
        _weightKg         = State(initialValue: user.weightKg)
        _heightCm         = State(initialValue: user.heightCm)
        _activityLevel    = State(initialValue: user.activityLevel)
        _primaryGoal      = State(initialValue: user.primaryGoal)
        _dietaryStyle     = State(initialValue: user.dietaryStyle)
        _dailyWaterGoalMl = State(initialValue: user.dailyWaterGoalMl)
        _useCustomMacros  = State(initialValue: user.useCustomMacros)
        _customProtein    = State(initialValue: user.dailyProteinTarget)
        _customCarbs      = State(initialValue: user.dailyCarbTarget)
        _customFat        = State(initialValue: user.dailyFatTarget)
        _country          = State(initialValue: user.country.isEmpty ? User.deviceCountry : user.country)
        _healthConditions = State(initialValue: Set(user.healthConditions))
        _allergies        = State(initialValue: Set(user.allergies))
        _unitSystem       = State(initialValue: user.unitSystem)
        _enableWeightTarget = State(initialValue: user.hasWeightTarget)
        _targetWeightKg   = State(initialValue: user.targetWeightKg > 0 ? user.targetWeightKg : user.latestWeightKg)
        _biologicalSex    = State(initialValue: user.biologicalSex)
        _hasDOB           = State(initialValue: user.dateOfBirth != nil)
        _dateOfBirth      = State(initialValue: user.dateOfBirth ?? Self.defaultDOB)
    }

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                bodySection
                weightGoalSection
                goalsSection
                macroTargetsSection
                waterSection
                healthSection
                allergiesSection
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
        Section("Profile") {
            TextField("Your name", text: $name)
                .font(SanaTheme.Font.body())
            HStack {
                Text("Country")
                    .font(SanaTheme.Font.body())
                Spacer()
                TextField("e.g. Turkey", text: $country)
                    .font(SanaTheme.Font.body())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Unit helpers

    private var imperialHeightLabel: String {
        let totalInches = heightCm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }

    private var heightLabel: String {
        unitSystem == .metric ? "\(Int(heightCm)) cm" : imperialHeightLabel
    }

    private func weightLabel(_ kg: Double) -> String {
        unitSystem == .metric
            ? String(format: "%.1f kg", kg)
            : String(format: "%.1f lbs", kg * 2.20462)
    }

    private var waterGoalLabel: String {
        unitSystem == .imperial
            ? String(format: "%.0f fl oz", Double(dailyWaterGoalMl) * 0.033814)
            : "\(dailyWaterGoalMl) ml"
    }

    // Slider bindings that convert between metric storage and display unit
    private var heightBinding: Binding<Double> {
        Binding(
            get: { unitSystem == .imperial ? heightCm / 2.54 : heightCm },
            set: { v in heightCm = unitSystem == .imperial ? v * 2.54 : v }
        )
    }
    private var weightBinding: Binding<Double> {
        Binding(
            get: { unitSystem == .imperial ? weightKg * 2.20462 : weightKg },
            set: { v in weightKg = unitSystem == .imperial ? v / 2.20462 : v }
        )
    }
    private var targetWeightBinding: Binding<Double> {
        Binding(
            get: { unitSystem == .imperial ? targetWeightKg * 2.20462 : targetWeightKg },
            set: { v in targetWeightKg = unitSystem == .imperial ? v / 2.20462 : v }
        )
    }
    private var heightRange: ClosedRange<Double>  { unitSystem == .imperial ? 55...87 : 140...220 }
    private var weightRange: ClosedRange<Double>  { unitSystem == .imperial ? 88...353 : 40...160 }
    private var weightStep:  Double               { unitSystem == .imperial ? 1.0 : 0.5 }

    private var dobAge: Int? {
        guard hasDOB else { return nil }
        return Calendar.current.dateComponents([.year], from: dateOfBirth, to: .now).year
    }

    private var bodySection: some View {
        Section("Body") {
            // Unit system toggle
            Picker("Units", selection: $unitSystem) {
                Text("Metric (kg, cm)").tag(UnitSystem.metric)
                Text("Imperial (lbs, ft)").tag(UnitSystem.imperial)
            }
            .pickerStyle(.segmented)

            // Sex
            Picker("Biological sex", selection: $biologicalSex) {
                ForEach(BiologicalSex.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .font(SanaTheme.Font.body())

            // Date of birth
            Toggle("Date of birth", isOn: $hasDOB)
                .font(SanaTheme.Font.body())
                .tint(SanaTheme.Color.primary)
            if hasDOB {
                DatePicker(
                    "Born",
                    selection: $dateOfBirth,
                    in: ...(Calendar.current.date(byAdding: .year, value: -10, to: .now) ?? .now),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .tint(SanaTheme.Color.primary)
                .font(SanaTheme.Font.body())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Height: \(heightLabel)")
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(.secondary)
                Slider(value: heightBinding, in: heightRange, step: 1)
                    .tint(SanaTheme.Color.primary)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Weight: \(weightLabel(weightKg))")
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(.secondary)
                Slider(value: weightBinding, in: weightRange, step: weightStep)
                    .tint(SanaTheme.Color.primary)
            }
            .padding(.vertical, 4)

            Picker("Activity level", selection: $activityLevel) {
                ForEach(ActivityLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .font(SanaTheme.Font.body())
        }
    }

    private var weightGoalSection: some View {
        Section {
            Toggle("Set a weight target", isOn: $enableWeightTarget)
                .tint(SanaTheme.Color.primary)
                .font(SanaTheme.Font.body())

            if enableWeightTarget {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target: \(weightLabel(targetWeightKg))")
                        .font(SanaTheme.Font.caption())
                        .foregroundStyle(.secondary)
                    Slider(value: targetWeightBinding, in: weightRange, step: weightStep)
                        .tint(SanaTheme.Color.primary)
                }
                .padding(.vertical, 4)

                let diff = targetWeightKg - weightKg
                if abs(diff) > 0.5 {
                    let arrow = diff < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
                    let diffColor: Color = diff < 0 ? SanaTheme.Color.primary : .orange
                    Label(
                        "\(diff < 0 ? "Lose" : "Gain") \(weightLabel(abs(diff)))",
                        systemImage: arrow
                    )
                    .font(SanaTheme.Font.caption(12))
                    .foregroundStyle(diffColor)
                }
            }
        } header: {
            Label("Weight goal", systemImage: "scalemass")
        } footer: {
            Text("Your projected weekly change is shown on the Dashboard once a few weight entries are logged.")
                .font(SanaTheme.Font.caption(12))
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

    private var healthSection: some View {
        Section {
            ForEach(HealthCondition.allCases, id: \.self) { condition in
                Toggle(isOn: Binding(
                    get: { healthConditions.contains(condition.rawValue) },
                    set: { on in
                        if on { healthConditions.insert(condition.rawValue) }
                        else  { healthConditions.remove(condition.rawValue) }
                    }
                )) {
                    Text(condition.rawValue)
                        .font(SanaTheme.Font.body())
                }
                .tint(SanaTheme.Color.primary)
            }
        } header: {
            Label("Health conditions", systemImage: "heart.text.square")
        } footer: {
            Text("Sana uses this to tailor meal suggestions and flag nutritional conflicts.")
                .font(SanaTheme.Font.caption(12))
        }
    }

    private var allergiesSection: some View {
        let allergens = ["Gluten", "Dairy", "Nuts", "Eggs", "Soy", "Shellfish", "Fish", "Sesame"]
        return Section {
            ForEach(allergens, id: \.self) { allergen in
                Toggle(isOn: Binding(
                    get: { allergies.contains(allergen) },
                    set: { on in
                        if on { allergies.insert(allergen) }
                        else  { allergies.remove(allergen) }
                    }
                )) {
                    Text(allergen)
                        .font(SanaTheme.Font.body())
                }
                .tint(.red)
            }
        } header: {
            Label("Food allergies", systemImage: "exclamationmark.circle")
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
                Text("Daily target: \(waterGoalLabel)")
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
        if let age = dobAge {
            return activityLevel.estimatedCalories(
                for: weightKg, heightCm: heightCm, age: age, sex: biologicalSex, goal: primaryGoal)
        }
        return activityLevel.estimatedCalories(for: weightKg, goal: primaryGoal)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        user.name = trimmed
        user.biologicalSex = biologicalSex
        user.dateOfBirth = hasDOB ? dateOfBirth : nil
        user.weightKg = weightKg
        user.heightCm = heightCm
        user.activityLevel = activityLevel
        user.primaryGoal = primaryGoal
        user.dietaryStyle = dietaryStyle
        user.dailyWaterGoalMl = dailyWaterGoalMl
        user.useCustomMacros = useCustomMacros
        user.country = country.trimmingCharacters(in: .whitespaces)
        user.healthConditions = Array(healthConditions).sorted()
        user.allergies = Array(allergies).sorted()
        user.unitSystem = unitSystem
        user.targetWeightKg = enableWeightTarget ? targetWeightKg : 0
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
