// Sana — NotificationSettingsView.swift
import SwiftUI

struct NotificationSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var hasPermission = false
    @State private var requestFailed = false
    @State private var estimatedWakeTime: Date? = nil

    @AppStorage("notif.meals.enabled")      private var mealsEnabled: Bool = true
    @AppStorage("notif.weekly.enabled")     private var weeklyEnabled: Bool = true
    @AppStorage("notif.hydration.enabled")  private var hydrationEnabled: Bool = false
    @AppStorage("notif.smart.enabled")      private var smartEnabled: Bool = false
    @AppStorage("notif.breakfast.ref")   private var breakfastRef: Double = NotificationSettingsView.defaultRef(hour: 8)
    @AppStorage("notif.lunch.ref")       private var lunchRef: Double = NotificationSettingsView.defaultRef(hour: 12)
    @AppStorage("notif.dinner.ref")      private var dinnerRef: Double = NotificationSettingsView.defaultRef(hour: 19)

    private var breakfastDate: Binding<Date> { refBinding($breakfastRef) }
    private var lunchDate: Binding<Date>     { refBinding($lunchRef) }
    private var dinnerDate: Binding<Date>    { refBinding($dinnerRef) }

    var body: some View {
        NavigationStack {
            List {
                permissionSection
                if hasPermission {
                    mealReminderSection
                    hydrationReminderSection
                    weeklySummarySection
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Task {
                            await applySettings()
                            dismiss()
                        }
                    }
                    .foregroundStyle(SanaTheme.Color.primary)
                }
            }
            .task {
                await checkPermission()
                if smartEnabled && hasPermission {
                    estimatedWakeTime = await HealthKitService.shared.fetchWakeTime()
                }
            }
            .onChange(of: smartEnabled) { _, enabled in
                guard enabled else { return }
                Task { estimatedWakeTime = await HealthKitService.shared.fetchWakeTime() }
            }
        }
    }

    // MARK: - Sections

    private var permissionSection: some View {
        Section {
            if hasPermission {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(SanaTheme.Color.primaryLight).frame(width: 32, height: 32)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SanaTheme.Color.primary)
                    }
                    Text("Notifications are enabled")
                        .font(SanaTheme.Font.body())
                        .foregroundStyle(SanaTheme.Color.primary)
                }
                .padding(.vertical, 2)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enable notifications to get meal reminders and weekly nutrition summaries.")
                        .font(SanaTheme.Font.body(14))
                        .foregroundStyle(.secondary)
                    Button("Enable notifications") {
                        Task { await requestPermission() }
                    }
                    .buttonStyle(NourishButtonStyle())
                    if requestFailed {
                        Label("Open Settings > Sana to enable notifications.", systemImage: "gear")
                            .font(SanaTheme.Font.caption())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var mealReminderSection: some View {
        Section {
            Toggle(isOn: $mealsEnabled) {
                Label("Meal reminders", systemImage: "fork.knife")
                    .font(SanaTheme.Font.body())
            }
            .tint(SanaTheme.Color.primary)

            if mealsEnabled {
                Toggle(isOn: $smartEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart timing")
                            .font(SanaTheme.Font.body())
                        Text("Adapts reminders to your wake time via Health")
                            .font(SanaTheme.Font.caption(11))
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(SanaTheme.Color.primary)
                .disabled(!HealthKitService.shared.isAuthorized)

                if smartEnabled {
                    smartTimingPreview
                } else {
                    timeRow(label: "Breakfast", image: "sunrise.fill",    color: .orange, date: breakfastDate)
                    timeRow(label: "Lunch",     image: "sun.max.fill",    color: .teal,   date: lunchDate)
                    timeRow(label: "Dinner",    image: "moon.stars.fill", color: .indigo, date: dinnerDate)
                }
            }
        } header: {
            Label("Meal reminders", systemImage: "fork.knife")
        } footer: {
            if smartEnabled && !HealthKitService.shared.isAuthorized {
                Text("Grant Health access to enable smart timing.")
            }
        }
    }

    private var smartTimingPreview: some View {
        Group {
            if let wake = estimatedWakeTime {
                let cal = Calendar.current
                let breakfast = cal.date(byAdding: .minute, value: 60,  to: wake) ?? wake
                let lunch     = cal.date(byAdding: .minute, value: 270, to: wake) ?? wake
                let dinner    = cal.date(byAdding: .minute, value: 600, to: wake) ?? wake

                VStack(alignment: .leading, spacing: 10) {
                    Label("Based on last wake at \(shortTime(wake))", systemImage: "bed.double.fill")
                        .font(SanaTheme.Font.caption(12))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 0) {
                        smartTimePill(label: "Breakfast", time: shortTime(breakfast), color: .orange)
                        Divider().frame(height: 28).opacity(0.3)
                        smartTimePill(label: "Lunch",     time: shortTime(lunch),     color: .teal)
                        Divider().frame(height: 28).opacity(0.3)
                        smartTimePill(label: "Dinner",    time: shortTime(dinner),    color: .indigo)
                    }
                }
                .padding(.vertical, 4)
            } else {
                Label("No recent sleep data — using manual times as fallback.", systemImage: "exclamationmark.circle")
                    .font(SanaTheme.Font.caption(12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        }
    }

    private var hydrationReminderSection: some View {
        Section {
            Toggle(isOn: $hydrationEnabled) {
                Label("Hydration reminders", systemImage: "drop.fill")
                    .font(SanaTheme.Font.body())
            }
            .tint(.blue)
            .onChange(of: hydrationEnabled) { _, enabled in
                if enabled {
                    NotificationService.shared.scheduleHydrationReminders()
                } else {
                    NotificationService.shared.cancelHydrationReminders()
                }
            }
            if hydrationEnabled {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7).fill(Color.blue.opacity(0.10)).frame(width: 28, height: 28)
                        Image(systemName: "clock.fill").font(.system(size: 11, weight: .medium)).foregroundStyle(.blue)
                    }
                    Text("Every 2 hours, 8 AM – 9 PM")
                        .font(SanaTheme.Font.caption())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Label("Hydration", systemImage: "drop.fill")
        }
    }

    private var weeklySummarySection: some View {
        Section {
            Toggle(isOn: $weeklyEnabled) {
                Label("Weekly nutrition recap", systemImage: "chart.bar.fill")
                    .font(SanaTheme.Font.body())
            }
            .tint(SanaTheme.Color.primary)
            if weeklyEnabled {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7).fill(SanaTheme.Color.primaryLight).frame(width: 28, height: 28)
                        Image(systemName: "calendar").font(.system(size: 11, weight: .medium))
                            .foregroundStyle(SanaTheme.Color.primary)
                    }
                    Text("Every Sunday at 7:00 PM")
                        .font(SanaTheme.Font.caption())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Label("Weekly summary", systemImage: "chart.bar.fill")
        }
    }

    private func timeRow(label: String, image: String, color: Color, date: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: image).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            }
            Text(LocalizedStringKey(label)).font(SanaTheme.Font.body())
            Spacer()
            DatePicker("", selection: date, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(SanaTheme.Color.primary)
        }
    }

    private func smartTimePill(label: String, time: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(time)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(LocalizedStringKey(label))
                .font(SanaTheme.Font.caption(10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: - Logic

    private func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        hasPermission = settings.authorizationStatus == .authorized
    }

    private func requestPermission() async {
        let granted = (try? await NotificationService.shared.requestAuthorization()) ?? false
        hasPermission = granted
        requestFailed = !granted
        if granted { await applySettings() }
    }

    private func applySettings() async {
        guard hasPermission else { return }
        if mealsEnabled {
            if smartEnabled, let wake = await HealthKitService.shared.fetchWakeTime() {
                NotificationService.shared.scheduleSmartMealReminders(wakeTime: wake)
            } else {
                NotificationService.shared.scheduleMealReminders(
                    breakfast: components(from: breakfastRef),
                    lunch:     components(from: lunchRef),
                    dinner:    components(from: dinnerRef)
                )
            }
        } else {
            NotificationService.shared.cancelAll(withPrefix: "meal_")
        }
        if weeklyEnabled {
            NotificationService.shared.scheduleWeeklySummary()
        } else {
            NotificationService.shared.cancelAll(withPrefix: "weekly_")
        }
        if hydrationEnabled {
            NotificationService.shared.scheduleHydrationReminders()
        } else {
            NotificationService.shared.cancelHydrationReminders()
        }
    }

    // MARK: - Helpers

    private func refBinding(_ ref: Binding<Double>) -> Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: ref.wrappedValue) },
            set: { ref.wrappedValue = $0.timeIntervalSinceReferenceDate }
        )
    }

    private func components(from ref: Double) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: Date(timeIntervalSinceReferenceDate: ref))
    }

    private func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    private static func defaultRef(hour: Int) -> Double {
        var c = DateComponents(); c.hour = hour; c.minute = 0
        return Calendar.current.date(from: c)?.timeIntervalSinceReferenceDate ?? 0
    }
}

#Preview {
    NotificationSettingsView()
}
