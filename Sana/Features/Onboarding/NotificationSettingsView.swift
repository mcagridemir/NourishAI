// Sana — NotificationSettingsView.swift
import SwiftUI

struct NotificationSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var hasPermission = false
    @State private var requestFailed = false

    @AppStorage("notif.meals.enabled")      private var mealsEnabled: Bool = true
    @AppStorage("notif.weekly.enabled")     private var weeklyEnabled: Bool = true
    @AppStorage("notif.hydration.enabled")  private var hydrationEnabled: Bool = false
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
                        applySettings()
                        dismiss()
                    }
                    .foregroundStyle(SanaTheme.Color.primary)
                }
            }
            .task { await checkPermission() }
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
                timeRow(label: "Breakfast", image: "sunrise.fill",   color: .orange, date: breakfastDate)
                timeRow(label: "Lunch",     image: "sun.max.fill",   color: .teal,   date: lunchDate)
                timeRow(label: "Dinner",    image: "moon.stars.fill", color: .indigo, date: dinnerDate)
            }
        } header: {
            Label("Meal reminders", systemImage: "fork.knife")
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
            Text(label).font(SanaTheme.Font.body())
            Spacer()
            DatePicker("", selection: date, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(SanaTheme.Color.primary)
        }
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
        if granted { applySettings() }
    }

    private func applySettings() {
        guard hasPermission else { return }
        if mealsEnabled {
            NotificationService.shared.scheduleMealReminders(
                breakfast: components(from: breakfastRef),
                lunch:     components(from: lunchRef),
                dinner:    components(from: dinnerRef)
            )
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
        let date = Date(timeIntervalSinceReferenceDate: ref)
        return Calendar.current.dateComponents([.hour, .minute], from: date)
    }

    private static func defaultRef(hour: Int) -> Double {
        var c = DateComponents(); c.hour = hour; c.minute = 0
        return Calendar.current.date(from: c)?.timeIntervalSinceReferenceDate ?? 0
    }
}

#Preview {
    NotificationSettingsView()
}
