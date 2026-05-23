// NourishAI — OnboardingFlowView.swift
import SwiftUI
import SwiftData

struct OnboardingFlowView: View {

    @Environment(\.modelContext) private var context
    @State private var step = 0
    @State private var name = ""
    @State private var email = ""
    @State private var goal: NutritionGoal = .eatHealthier
    @State private var dietStyle: DietaryStyle = .omnivore
    @State private var allergies: Set<String> = []
    @State private var sex: BiologicalSex = .preferNotToSay
    @State private var heightCm: Double = 170
    @State private var weightKg: Double = 70
    @State private var activityLevel: ActivityLevel = .moderatelyActive

    private let totalSteps = 5
    private let commonAllergens = ["Gluten", "Dairy", "Nuts", "Eggs", "Soy", "Shellfish", "Fish", "Sesame"]

    var body: some View {
        ZStack {
            NourishTheme.Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                progressBar
                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    profileStep.tag(1)
                    goalStep.tag(2)
                    dietStep.tag(3)
                    allergyStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(NourishTheme.Animation.smooth, value: step)
            }
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(NourishTheme.Color.primaryLight).frame(height: 3)
                Rectangle().fill(NourishTheme.Color.primary)
                    .frame(width: geo.size.width * Double(step + 1) / Double(totalSteps), height: 3)
                    .animation(NourishTheme.Animation.smooth, value: step)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        OnboardingStep(title: "Welcome to NourishAI", subtitle: "Your personal AI nutrition coach. Let's set up your profile.", icon: "leaf.fill", iconColor: NourishTheme.Color.primary) {
            VStack(spacing: 16) {
                NourishTextField(placeholder: "Your name", text: $name)
                NourishTextField(placeholder: "Email address", text: $email)
                    .keyboardType(.emailAddress).autocapitalization(.none)
            }
        } next: {
            step = 1
        } nextEnabled: { !name.isEmpty && email.contains("@") }
    }

    private var profileStep: some View {
        OnboardingStep(title: "About you", subtitle: "This helps us personalise your calorie and nutrition targets.", icon: "person.fill", iconColor: .blue) {
            VStack(spacing: 20) {
                Picker("Sex", selection: $sex) {
                    ForEach(BiologicalSex.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Height: \(Int(heightCm)) cm").font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
                    Slider(value: $heightCm, in: 140...220, step: 1).tint(NourishTheme.Color.primary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weight: \(Int(weightKg)) kg").font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
                    Slider(value: $weightKg, in: 40...160, step: 0.5).tint(NourishTheme.Color.primary)
                }
                Picker("Activity level", selection: $activityLevel) {
                    ForEach(ActivityLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.wheel).frame(height: 100).clipped()
            }
        } next: { step = 2 } nextEnabled: { true }
    }

    private var goalStep: some View {
        OnboardingStep(title: "What's your main goal?", subtitle: "We'll tailor your plan around this.", icon: "target", iconColor: .orange) {
            VStack(spacing: 10) {
                ForEach(NutritionGoal.allCases, id: \.self) { g in
                    SelectionRow(label: g.rawValue, isSelected: goal == g) { goal = g }
                }
            }
        } next: { step = 3 } nextEnabled: { true }
    }

    private var dietStep: some View {
        OnboardingStep(title: "Dietary style", subtitle: "How would you describe your eating habits?", icon: "fork.knife", iconColor: .green) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(DietaryStyle.allCases, id: \.self) { d in
                    SelectionTile(label: d.rawValue, isSelected: dietStyle == d) { dietStyle = d }
                }
            }
        } next: { step = 4 } nextEnabled: { true }
    }

    private var allergyStep: some View {
        OnboardingStep(title: "Any food allergies?", subtitle: "Select all that apply. You can change this later.", icon: "allergens", iconColor: .red) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(commonAllergens, id: \.self) { a in
                    SelectionTile(label: a, isSelected: allergies.contains(a)) {
                        if allergies.contains(a) { allergies.remove(a) } else { allergies.insert(a) }
                    }
                }
            }
        } next: {
                    createUser()
                } nextEnabled: { true }
    }

    // MARK: - Create user

    private func createUser() {
        let user = User(
            name: name, email: email, biologicalSex: sex,
            heightCm: heightCm, weightKg: weightKg,
            activityLevel: activityLevel, primaryGoal: goal,
            dietaryStyle: dietStyle, allergies: Array(allergies)
        )
        context.insert(user)

        // Schedule notifications
        Task {
            _ = try? await NotificationService.shared.requestAuthorization()
            NotificationService.shared.scheduleWeeklySummary()
            try? await HealthKitService.shared.requestAuthorization()
        }
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
            VStack(spacing: NourishTheme.Spacing.lg) {
                VStack(spacing: 12) {
                    Image(systemName: icon).font(.system(size: 44)).foregroundStyle(iconColor).padding(.top, 24)
                    Text(title).font(NourishTheme.Font.title(24)).multilineTextAlignment(.center)
                    Text(subtitle).font(NourishTheme.Font.body()).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                content()
                Spacer(minLength: 20)
                Button(nextLabel, action: next)
                    .buttonStyle(NourishButtonStyle())
                    .disabled(!nextEnabled())
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, NourishTheme.Spacing.md)
        }
    }
}

struct SelectionRow: View {
    let label: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(label).font(NourishTheme.Font.body()).foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? NourishTheme.Color.primary : .secondary)
            }
            .padding()
            .background(isSelected ? NourishTheme.Color.primaryLight : NourishTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: NourishTheme.Radius.md).stroke(isSelected ? NourishTheme.Color.primary : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

struct SelectionTile: View {
    let label: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(NourishTheme.Font.body(14)).foregroundStyle(isSelected ? NourishTheme.Color.primary : .primary)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(isSelected ? NourishTheme.Color.primaryLight : NourishTheme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: NourishTheme.Radius.md).stroke(isSelected ? NourishTheme.Color.primary : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

struct NourishTextField: View {
    let placeholder: String; @Binding var text: String
    var body: some View {
        TextField(placeholder, text: $text)
            .font(NourishTheme.Font.body())
            .padding()
            .background(NourishTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
    }
}
