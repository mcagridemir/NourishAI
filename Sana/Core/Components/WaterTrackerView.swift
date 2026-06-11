// Sana — WaterTrackerView.swift
import SwiftUI
import SwiftData

struct WaterTrackerView: View {

    @Bindable var user: User

    private var progress: Double {
        min(1.0, Double(user.todayWaterMl) / Double(max(1, user.dailyWaterGoalMl)))
    }

    // MARK: - Design spec: glass-segment layout

    /// Blue used for hydration — same hex as macro protein (#4A7CFF)
    private static let hydrationBlue = Color(hex: "#4A7CFF") ?? Color("MacroProtein")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Self.hydrationBlue.opacity(0.12))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "drop.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Self.hydrationBlue)
                    )
                Text("Hydration")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if progress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SanaTheme.Color.primary)
                        .font(.caption)
                        .padding(.trailing, 4)
                }
                // Trend link (design spec: hydration card navigates to HydrationTrendView)
                NavigationLink(destination: HydrationTrendView(user: user)) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Self.hydrationBlue.opacity(0.7))
                }
                .accessibilityLabel("View hydration trend")
            }

            // Big number display
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(user.formatWater(user.todayWaterMl))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .kerning(-0.6)
                Text("/ \(user.formatWater(user.dailyWaterGoalMl))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.top, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Water: \(user.formatWater(user.todayWaterMl)) of \(user.formatWater(user.dailyWaterGoalMl)). \(Int(progress * 100)) percent.")

            // Glass segments (8 cells)
            HStack(spacing: 4) {
                ForEach(0..<8, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Double(i) < progress * 8 ? Self.hydrationBlue : SanaTheme.Color.hairline)
                        .frame(height: 16)
                        .animation(SanaTheme.Animation.smooth, value: progress)
                }
            }
            .padding(.top, 8)

            // Add glass CTA
            Button {
                addWater(250)
            } label: {
                Text("+ Add glass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Self.hydrationBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Self.hydrationBlue.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Add one glass of water (250 ml)")
            .padding(.top, 10)
        }
        .padding()
        .nourishCard()
        .onAppear { flushSiriWaterLog() }
    }

    /// Picks up any water logged via Siri while the app was closed
    private func flushSiriWaterLog() {
        let defaults = UserDefaults(suiteName: "group.com.cagri.Sana")
        let pending = defaults?.integer(forKey: "siri.pendingWaterMl") ?? 0
        guard pending > 0 else { return }
        defaults?.removeObject(forKey: "siri.pendingWaterMl")
        addWater(pending)
    }

    private func addWater(_ ml: Int) {
        HapticService.impact(.light)
        let entry = WaterEntry(amountMl: ml)
        entry.user = user
        // inverse set above; SwiftData manages the collection
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
            .modelContainer(container)
            .padding()
            .background(SanaTheme.Color.background)
    }
}

#Preview { WaterTrackerPreview() }
