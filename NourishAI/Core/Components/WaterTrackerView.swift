// NourishAI — WaterTrackerView.swift
import SwiftUI
import SwiftData

struct WaterTrackerView: View {

    @Bindable var user: User
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var healthKit: HealthKitService

    private let quickAmounts = [150, 250, 350, 500]

    private var progress: Double {
        min(1.0, Double(user.todayWaterMl) / Double(max(1, user.dailyWaterGoalMl)))
    }

    private var progressColor: Color {
        switch progress {
        case 0.75...: return NourishTheme.Color.primary
        case 0.4...:  return .blue
        default:      return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NourishTheme.Spacing.sm) {
            headerRow
            progressBar
            quickAddRow
        }
        .padding()
        .nourishCard()
        .onAppear { flushSiriWaterLog() }
    }

    /// Picks up any water logged via Siri while the app was closed
    private func flushSiriWaterLog() {
        let defaults = UserDefaults(suiteName: "group.com.cagri.NourishAI")
        let pending = defaults?.integer(forKey: "siri.pendingWaterMl") ?? 0
        guard pending > 0 else { return }
        defaults?.removeObject(forKey: "siri.pendingWaterMl")
        addWater(pending)
    }

    private var headerRow: some View {
        HStack {
            Label("Water", systemImage: "drop.fill")
                .font(NourishTheme.Font.headline())
                .foregroundStyle(.blue)
            Spacer()
            Text("\(user.todayWaterMl) / \(user.dailyWaterGoalMl) ml")
                .font(NourishTheme.Font.caption())
                .foregroundStyle(.secondary)
            if progress >= 1.0 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(NourishTheme.Color.primary)
                    .font(.caption)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: NourishTheme.Radius.sm)
                    .fill(Color.blue.opacity(0.12))
                    .frame(height: 10)
                RoundedRectangle(cornerRadius: NourishTheme.Radius.sm)
                    .fill(progressColor)
                    .frame(width: geo.size.width * progress, height: 10)
                    .animation(NourishTheme.Animation.smooth, value: progress)
            }
        }
        .frame(height: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Water progress: \(user.todayWaterMl) of \(user.dailyWaterGoalMl) millilitres. \(Int(progress * 100)) percent.")
        .accessibilityValue("\(Int(progress * 100))%")
    }

    private var quickAddRow: some View {
        HStack(spacing: NourishTheme.Spacing.xs) {
            ForEach(quickAmounts, id: \.self) { amount in
                Button("+\(amount)") {
                    addWater(amount)
                }
                .accessibilityLabel("Add \(amount) millilitres of water")
                .font(NourishTheme.Font.caption(12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
            }
            Spacer()
            Text("ml")
                .font(NourishTheme.Font.caption(11))
                .foregroundStyle(.secondary)
        }
    }

    private func addWater(_ ml: Int) {
        HapticService.impact(.light)
        let entry = WaterEntry(amountMl: ml)
        entry.user = user
        user.waterEntries.append(entry)
        withAnimation(NourishTheme.Animation.smooth) { }
        Task { try? await HealthKitService.shared.logWater(ml: ml) }
        WidgetDataStore.save(user.widgetData)
        LiveActivityService.shared.startOrUpdate(user: user)
    }
}

private struct WaterTrackerPreview: View {
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
        WaterTrackerView(user: user)
            .environmentObject(HealthKitService.shared)
            .modelContainer(container)
            .padding()
            .background(NourishTheme.Color.background)
    }
}

#Preview { WaterTrackerPreview() }
