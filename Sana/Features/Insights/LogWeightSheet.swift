// Sana — LogWeightSheet.swift
import SwiftUI
import SwiftData

struct LogWeightSheet: View {

    @Bindable var user: User
    @Environment(\.dismiss) private var dismiss
    @State private var weightKg: Double

    init(user: User) {
        self.user = user
        _weightKg = State(initialValue: user.latestWeightKg)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: SanaTheme.Spacing.xl) {
                Spacer()

                weightDisplay
                controls
                changeIndicator

                Spacer()

                Button("Save") { save() }
                    .buttonStyle(NourishButtonStyle())
                    .padding(.bottom, SanaTheme.Spacing.lg)
            }
            .padding(.horizontal, SanaTheme.Spacing.md)
            .background(SanaTheme.Color.background)
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Unit helpers

    /// Step size in kg: 0.1 kg for metric, ≈0.1 lbs for imperial
    private var weightStep: Double { user.unitSystem == .imperial ? 0.04536 : 0.1 }

    private var displayWeight: Double {
        user.unitSystem == .imperial ? weightKg * 2.20462 : weightKg
    }

    private var weightUnit: String { user.unitSystem == .imperial ? "lbs" : "kg" }

    // MARK: - Sub-views

    private var weightDisplay: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1f", displayWeight))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(SanaTheme.Color.primary)
                .contentTransition(.numericText())
                .animation(SanaTheme.Animation.smooth, value: weightKg)
            Text(weightUnit)
                .font(SanaTheme.Font.headline(20))
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        let step = weightStep
        return VStack(spacing: SanaTheme.Spacing.md) {
            HStack(spacing: SanaTheme.Spacing.lg) {
                Button {
                    HapticService.impact(.light)
                    weightKg = max(30, weightKg - step)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(SanaTheme.Color.primary)
                }
                Spacer()
                Button {
                    HapticService.impact(.light)
                    weightKg = min(300, weightKg + step)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(SanaTheme.Color.primary)
                }
            }

            Slider(value: $weightKg, in: max(30, weightKg - 30)...min(300, weightKg + 30), step: step)
                .tint(SanaTheme.Color.primary)
        }
        .padding()
        .nourishCard()
    }

    @ViewBuilder
    private var changeIndicator: some View {
        let diff = weightKg - user.latestWeightKg
        let threshold = weightStep
        if abs(diff) >= threshold {
            let diffDisplay: String = user.unitSystem == .imperial
                ? String(format: "%.1f lbs", diff * 2.20462)
                : String(format: "%.1f kg", diff)
            HStack(spacing: 6) {
                Image(systemName: diff < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundStyle(diff < 0 ? SanaTheme.Color.primary : .orange)
                Text("\(diff < 0 ? "" : "+")\(diffDisplay) ") + Text("from last entry")
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Save

    private func save() {
        HapticService.notification(.success)
        let entry = WeightEntry(weightKg: weightKg)
        entry.user = user
        user.weightKg = weightKg
        Task { try? await HealthKitService.shared.writeWeight(kg: weightKg) }
        dismiss()
    }
}

private struct LogWeightPreview: View {
    let container: ModelContainer
    let user: User
    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let c = try! ModelContainer(for: User.self, configurations: config)
        let u = User(name: "Preview", email: "preview@test.com")
        c.mainContext.insert(u)
        container = c; user = u
    }
    var body: some View {
        LogWeightSheet(user: user).modelContainer(container)
    }
}

#Preview { LogWeightPreview() }
