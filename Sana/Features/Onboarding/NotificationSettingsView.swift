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
                Label("Notifications are enabled", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(SanaTheme.Color.primary)
                    .font(SanaTheme.Font.body())
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enable notifications to get meal reminders and weekly nutrition summaries.")
                        .font(SanaTheme.Font.body(14))
                        .foregroundStyle(.secondary)
                    Button("Enable notifications") {
                        Task { await requestPermission() }
                    }
                    .buttonStyle(NourishButtonStyle())
                    if requestFailed {
                        Text("Go to Settings > Sana to enable notifications.")
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
                timeRow(label: "Breakfast", image: "sunrise", date: breakfastDate)
                timeRow(label: "Lunch",     image: "sun.max",  date: lunchDate)
                timeRow(label: "Dinner",    image: "moon.stars", date: dinnerDate)
            }
        } header: {
            Text("Meal reminders")
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
                Text("Reminds you every 2 hours from 8 AM to 9 PM")
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Hydration")
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
                Text("Sent every Sunday at 7:00 PM")
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Weekly summary")
        }
    }

    private func timeRow(label: String, image: String, date: Binding<Date>) -> some View {
        HStack {
            Label(label, systemImage: image)
                .font(SanaTheme.Font.body())
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
