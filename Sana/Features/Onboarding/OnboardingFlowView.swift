// Sana — OnboardingFlowView.swift
import SwiftUI
import SwiftData

struct OnboardingFlowView: View {

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var subscription: SubscriptionService
    @State private var step = 0
    @State private var showPaywall = false
    @State private var name = ""
    @State private var goal: NutritionGoal = .eatHealthier
    @State private var dietStyle: DietaryStyle = .noPreference
    @State private var allergies: Set<String> = []
    @State private var healthConditions: Set<String> = []
    @State private var sex: BiologicalSex = .preferNotToSay
    @State private var heightCm: Double = 170
    @State private var weightKg: Double = 70
    @State private var activityLevel: ActivityLevel = .moderatelyActive

    // Unit system from device locale — onboarding sliders work in display units;
    // the User model always stores metric internally.
    private let onboardingUnits = UnitSystem.deviceDefault

    private var heightBinding: Binding<Double> {
        Binding(
            get: { onboardingUnits == .imperial ? heightCm / 2.54 : heightCm },
            set: { v in heightCm = onboardingUnits == .imperial ? v * 2.54 : v }
        )
    }
    private var weightBinding: Binding<Double> {
        Binding(
            get: { onboardingUnits == .imperial ? weightKg * 2.20462 : weightKg },
            set: { v in weightKg = onboardingUnits == .imperial ? v / 2.20462 : v }
        )
    }
    private var heightDisplayLabel: String {
        if onboardingUnits == .imperial {
            let totalIn = Int(heightCm / 2.54)
            return "\(totalIn / 12)' \(totalIn % 12)\""
        }
        return "\(Int(heightCm)) cm"
    }
    private var weightDisplayLabel: String {
        onboardingUnits == .imperial
            ? String(format: "%.0f lbs", weightKg * 2.20462)
            : "\(Int(weightKg)) kg"
    }

    private let totalSteps = 7
    private let commonAllergens = ["Gluten", "Dairy", "Nuts", "Eggs", "Soy", "Shellfish", "Fish", "Sesame"]

    var body: some View {
        ZStack {
            SanaTheme.Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                progressBar
                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    profileStep.tag(1)
                    activityStep.tag(2)
                    goalStep.tag(3)
                    dietStep.tag(4)
                    allergyStep.tag(5)
                    healthConditionsStep.tag(6)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(SanaTheme.Animation.smooth, value: step)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(subscription)
        }
    }

    // MARK: - Progress bar (segmented pills)

    private var progressBar: some View {
        HStack(spacing: 8) {
            if step > 0 {
                Button {
                    HapticService.selection()
                    withAnimation(SanaTheme.Animation.smooth) { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                }
                .transition(.opacity)
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 999)
                        .fill(i <= step ? SanaTheme.Color.primary : SanaTheme.Color.primaryLight)
                        .frame(height: 4)
                        .animation(SanaTheme.Animation.smooth, value: step)
                }
            }
        }
        .padding(.horizontal, SanaTheme.Spacing.lg)
        .padding(.vertical, SanaTheme.Spacing.sm)
        .animation(SanaTheme.Animation.smooth, value: step > 0)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        OnboardingStep(title: "Welcome to Sana", subtitle: "Your personal AI nutrition coach. Let's set up your profile.", icon: "leaf.fill", iconColor: SanaTheme.Color.primary) {
            NourishTextField(placeholder: "Your name", text: $name)
                .submitLabel(.continue)
                .onSubmit { if !name.isEmpty { HapticService.stepForward(); step = 1 } }
        } next: {
            HapticService.stepForward()
            step = 1
        } nextEnabled: { !name.isEmpty }
        .onAppear {
            // Pre-fill name from Apple Sign In if available
            let pending = auth.consumePendingName()
            if !pending.isEmpty && name.isEmpty { name = pending }
        }
    }

    private var profileStep: some View {
        OnboardingStep(title: "About you", subtitle: "This helps us personalise your calorie and nutrition targets.", icon: "person.fill", iconColor: .blue) {
            VStack(spacing: 20) {
                Picker("Sex", selection: $sex) {
                    ForEach(BiologicalSex.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Height: \(heightDisplayLabel)")
                        .font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                    Slider(
                        value: heightBinding,
                        in: onboardingUnits == .imperial ? 55...87 : 140...220,
                        step: 1
                    ).tint(SanaTheme.Color.primary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weight: \(weightDisplayLabel)")
                        .font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                    Slider(
                        value: weightBinding,
                        in: onboardingUnits == .imperial ? 88...353 : 40...160,
                        step: onboardingUnits == .imperial ? 1 : 0.5
                    ).tint(SanaTheme.Color.primary)
                }
            }
        } next: { HapticService.stepForward(); step = 2 } nextEnabled: { true }
    }

    private var activityStep: some View {
        OnboardingStep(
            title: "How active are you?",
            subtitle: "This helps us calculate your daily calorie needs accurately.",
            icon: "figure.run",
            iconColor: .blue
        ) {
            VStack(spacing: 10) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Button {
                        HapticService.selection()
                        activityLevel = level
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(level.rawValue)
                                    .font(SanaTheme.Font.body())
                                    .foregroundStyle(.primary)
                                Text(activityLevelDescription(level))
                                    .font(SanaTheme.Font.caption(12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: activityLevel == level ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(activityLevel == level ? SanaTheme.Color.primary : .secondary)
                        }
                        .padding()
                        .background(activityLevel == level ? SanaTheme.Color.primaryLight : SanaTheme.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.md)
                            .stroke(activityLevel == level ? SanaTheme.Color.primary : Color.clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        } next: { HapticService.stepForward(); step = 3 } nextEnabled: { true }
    }

    private func activityLevelDescription(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary:        return "Desk job, little or no exercise"
        case .lightlyActive:    return "Light exercise 1–3 days/week"
        case .moderatelyActive: return "Moderate exercise 3–5 days/week"
        case .veryActive:       return "Hard exercise 6–7 days/week"
        case .extraActive:      return "Physical job or twice-daily training"
        }
    }

    private var goalStep: some View {
        OnboardingStep(title: "What's your main goal?", subtitle: "We'll tailor your plan around this.", icon: "target", iconColor: .orange) {
            VStack(spacing: 10) {
                ForEach(NutritionGoal.allCases, id: \.self) { g in
                    SelectionRow(label: g.rawValue, isSelected: goal == g) { goal = g }
                }
            }
        } next: { HapticService.stepForward(); step = 4 } nextEnabled: { true }
    }

    private var dietStep: some View {
        OnboardingStep(
            title: "Dietary style",
            subtitle: "How would you describe your eating habits? You can skip this.",
            icon: "fork.knife", iconColor: .green
        ) {
            VStack(spacing: 10) {
                // "No preference" skip tile — visually distinct
                Button {
                    HapticService.selection()
                    dietStyle = .noPreference
                } label: {
                    HStack {
                        Image(systemName: dietStyle == .noPreference ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(dietStyle == .noPreference ? SanaTheme.Color.primary : .secondary)
                        Text("No preference / Skip")
                            .font(SanaTheme.Font.body())
                            .foregroundStyle(dietStyle == .noPreference ? SanaTheme.Color.primary : .secondary)
                        Spacer()
                    }
                    .padding()
                    .background(dietStyle == .noPreference ? SanaTheme.Color.primaryLight : SanaTheme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.md)
                        .stroke(dietStyle == .noPreference ? SanaTheme.Color.primary : Color.clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(DietaryStyle.allCases.filter { $0 != .noPreference }, id: \.self) { d in
                        SelectionTile(label: d.rawValue, isSelected: dietStyle == d) { dietStyle = d }
                    }
                }
            }
        } next: { HapticService.stepForward(); step = 5 } nextEnabled: { true }
    }

    private var allergyStep: some View {
        OnboardingStep(title: "Any food allergies?", subtitle: "Select all that apply. You can change this later.", icon: "exclamationmark.circle.fill", iconColor: .red) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(commonAllergens, id: \.self) { a in
                    SelectionTile(label: a, isSelected: allergies.contains(a)) {
                        if allergies.contains(a) { allergies.remove(a) } else { allergies.insert(a) }
                    }
                }
            }
        } next: { HapticService.stepForward(); step = 6 } nextEnabled: { true }
    }

    private var healthConditionsStep: some View {
        OnboardingStep(
            title: "Any health conditions?",
            subtitle: "We'll tailor meals and advice around these. Select all that apply.",
            icon: "heart.text.square.fill",
            iconColor: .pink,
            content: {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(HealthCondition.allCases, id: \.self) { c in
                        SelectionTile(label: c.rawValue, isSelected: healthConditions.contains(c.rawValue)) {
                            if healthConditions.contains(c.rawValue) {
                                healthConditions.remove(c.rawValue)
                            } else {
                                healthConditions.insert(c.rawValue)
                            }
                        }
                    }
                }
            },
            next: {
                HapticService.notification(.success)
                createUser()
            },
            nextLabel: "Get started",
            nextEnabled: { true }
        )
    }

    // MARK: - Create user

    private func createUser() {
        let user = User(
            authID: auth.currentUserID ?? "",
            name: name,
            biologicalSex: sex,
            heightCm: heightCm, weightKg: weightKg,
            activityLevel: activityLevel, primaryGoal: goal,
            dietaryStyle: dietStyle,
            allergies: Array(allergies),
            healthConditions: Array(healthConditions),
            country: User.deviceCountry
        )
        context.insert(user)

        // Schedule notifications
        Task {
            _ = try? await NotificationService.shared.requestAuthorization()
            NotificationService.shared.scheduleWeeklySummary()
            try? await HealthKitService.shared.requestAuthorization()
        }

        // Show paywall immediately after onboarding (non-blocking — user can skip)
        showPaywall = true
    }
}

// MARK: - Reusable onboarding components

struct OnboardingStep<Content: View>: View {
    let title: String; let subtitle: String; let icon: String; let iconColor: Color
    @ViewBuilder let content: () -> Content
    let next: () -> Void
    var nextLabel: String = "Continue"
    let nextEnabled: () -> Bool

    var body: some View {
        ScrollView {
            VStack(spacing: SanaTheme.Spacing.lg) {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: icon)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }
                    .shadow(color: iconColor.opacity(0.18), radius: 14, y: 6)
                    .padding(.top, 24)
                    Text(title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .kerning(-0.5)
                    Text(subtitle)
                        .font(SanaTheme.Font.body())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                content()
                Spacer(minLength: 20)
                Button(nextLabel, action: next)
                    .buttonStyle(NourishButtonStyle())
                    .disabled(!nextEnabled())
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, SanaTheme.Spacing.lg)
        }
    }
}

struct SelectionRow: View {
    let label: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button {
            HapticService.selection()
            action()
        } label: {
            HStack {
                Text(label).font(SanaTheme.Font.body()).foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? SanaTheme.Color.primary : .secondary)
            }
            .padding()
            .background(isSelected ? SanaTheme.Color.primaryLight : SanaTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.md).stroke(isSelected ? SanaTheme.Color.primary : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

struct SelectionTile: View {
    let label: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button {
            HapticService.selection()
            action()
        } label: {
            Text(label).font(SanaTheme.Font.body(14)).foregroundStyle(isSelected ? SanaTheme.Color.primary : .primary)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(isSelected ? SanaTheme.Color.primaryLight : SanaTheme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.md).stroke(isSelected ? SanaTheme.Color.primary : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

struct NourishTextField: View {
    let placeholder: String; @Binding var text: String
    var body: some View {
        TextField(placeholder, text: $text)
            .font(SanaTheme.Font.body())
            .padding()
            .background(SanaTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
    }
}
