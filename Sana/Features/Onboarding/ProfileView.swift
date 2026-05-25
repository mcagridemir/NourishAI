// Sana — ProfileView.swift
import SwiftUI

struct ProfileView: View {
    @Bindable var user: User
    @EnvironmentObject private var subscription: SubscriptionService
    @State private var showingPaywall = false
    @State private var showingNotifSettings = false
    @State private var showingEditProfile = false
    @State private var showingLogWeight = false
    @State private var exportURL: URL?
    @State private var showingExport = false
    @State private var showingAchievements = false
    @State private var showingBodyMetrics = false
    @State private var showingThemePicker = false
    @State private var showingSupplements = false

    // Keychain is canonical; fall back to user.email for accounts created before this change.
    private var displayEmail: String {
        if let keychainEmail = KeychainService.load(for: .userEmail), !keychainEmail.isEmpty {
            return keychainEmail
        }
        // One-time migration: move existing SwiftData email into Keychain.
        if !user.email.isEmpty {
            KeychainService.save(user.email, for: .userEmail)
            user.email = ""
            return KeychainService.load(for: .userEmail) ?? ""
        }
        return ""
    }

    var body: some View {
        List {
            // Header
            Section {
                HStack(spacing: 14) {
                    Circle().fill(SanaTheme.Color.primaryLight).frame(width: 60, height: 60)
                        .overlay(Text(user.name.prefix(1)).font(SanaTheme.Font.title(24)).foregroundStyle(SanaTheme.Color.primary))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name).font(SanaTheme.Font.headline(18))
                        Text(displayEmail).font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                        if user.subscriptionTier == .premium {
                            Label("Premium", systemImage: "sparkles").font(SanaTheme.Font.caption(11))
                                .foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 3)
                                .background(SanaTheme.Color.primary).clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            // Physical stats
            Section("Physical profile") {
                ProfileRow(label: "Height", value: user.formattedHeight)
                HStack {
                    Text("Weight").foregroundStyle(.secondary)
                    Spacer()
                    Text(user.formattedCurrentWeight)
                    Button {
                        HapticService.selection()
                        showingLogWeight = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(SanaTheme.Color.primary)
                    }
                    .buttonStyle(.plain)
                }
                if let change = user.weightChangeSinceStart {
                    HStack {
                        Spacer()
                        Label(
                            "\(change < 0 ? "−" : "+")\(user.formatWeight(abs(change))) total",
                            systemImage: change < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
                        )
                        .font(SanaTheme.Font.caption())
                        .foregroundStyle(change < 0 ? SanaTheme.Color.primary : .orange)
                    }
                }
                ProfileRow(label: "BMI", value: String(format: "%.1f", user.bmi))
                if let age = user.age {
                    ProfileRow(label: "Age", value: "\(age)")
                }
                ProfileRow(label: "Activity level", value: user.activityLevel.rawValue)
            }

            // Nutrition goals
            Section("Nutrition targets") {
                ProfileRow(label: "Goal", value: user.primaryGoal.rawValue)
                ProfileRow(label: "Calories", value: "\(user.dailyCalorieTarget) kcal")
                ProfileRow(label: "Protein", value: "\(Int(user.dailyProteinTarget))g")
                ProfileRow(label: "Dietary style", value: user.dietaryStyle.rawValue)
            }

            // Subscription
            if user.subscriptionTier == .free {
                Section {
                    Button { showingPaywall = true } label: {
                        HStack {
                            Image(systemName: "sparkles").foregroundStyle(SanaTheme.Color.primary)
                            Text("Upgrade to Premium").foregroundStyle(SanaTheme.Color.primary)
                            Spacer()
                            Text("\(user.remainingFreeAnalyses) analyses left today")
                                .font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Achievements & metrics
            Section("Progress") {
                Button { showingAchievements = true } label: {
                    HStack {
                        Label("Achievements", systemImage: "trophy.fill").foregroundStyle(.primary)
                        Spacer()
                        let count = Achievement.all.filter { $0.checkUnlocked(user) }.count
                        Text("\(count)/\(Achievement.all.count)")
                            .font(SanaTheme.Font.caption())
                            .foregroundStyle(.secondary)
                    }
                }
                Button { showingBodyMetrics = true } label: {
                    Label("Body metrics", systemImage: "figure.stand").foregroundStyle(.primary)
                }
                Button { showingSupplements = true } label: {
                    Label("Supplements", systemImage: "pill.fill").foregroundStyle(.primary)
                }
            }

            // Settings
            Section("Settings") {
                Button { showingNotifSettings = true } label: {
                    Label("Notification preferences", systemImage: "bell").foregroundStyle(.primary)
                }
                Button { showingThemePicker = true } label: {
                    HStack {
                        Label("App theme", systemImage: "paintpalette.fill").foregroundStyle(.primary)
                        Spacer()
                        Circle()
                            .fill(ThemeManager.shared.primaryColor)
                            .frame(width: 18, height: 18)
                    }
                }
                NavigationLink(destination: AllergiesEditView(user: user)) {
                    Label("Allergies & restrictions", systemImage: "exclamationmark.shield")
                }
                // Opens iOS Settings → Sana → Language (per-app language, iOS 13+)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Label("Language", systemImage: "globe")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "") ?? "")
                            .font(SanaTheme.Font.caption())
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    if let url = ExportService.csvURL(for: user) {
                        exportURL = url
                        showingExport = true
                    }
                } label: {
                    Label("Export meal data (CSV)", systemImage: "square.and.arrow.up")
                        .foregroundStyle(.primary)
                }
            }

            Section {
                Button(role: .destructive) {
                    HapticService.destructive()
                    AuthService.shared.signOut()
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            #if DEBUG
            Section("Debug") {
                Button(role: .destructive) {
                    FirebaseService.shared.forceCrash()
                } label: {
                    Label("Test Crashlytics crash", systemImage: "ant.fill")
                }
            }
            #endif
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEditProfile = true }
                    .foregroundStyle(SanaTheme.Color.primary)
            }
        }
        .sheet(isPresented: $showingPaywall) { PaywallView().environmentObject(subscription) }
        .sheet(isPresented: $showingNotifSettings) { NotificationSettingsView() }
        .sheet(isPresented: $showingEditProfile) { EditProfileView(user: user) }
        .sheet(isPresented: $showingLogWeight) { LogWeightSheet(user: user) }
        .sheet(isPresented: $showingExport) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showingAchievements) {
            AchievementsView(user: user)
        }
        .sheet(isPresented: $showingBodyMetrics) {
            BodyMetricsView(user: user)
        }
        .sheet(isPresented: $showingThemePicker) {
            ThemePickerView()
        }
        .sheet(isPresented: $showingSupplements) {
            SupplementTrackerView()
        }
    }
}

private struct ProfileRow: View {
    let label: String; let value: String
    var body: some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value).foregroundStyle(.primary) }
    }
}

struct AllergiesEditView: View {
    @Bindable var user: User
    private let commonAllergens = ["Gluten", "Dairy", "Nuts", "Eggs", "Soy", "Shellfish", "Fish", "Sesame"]
    var body: some View {
        List(commonAllergens, id: \.self) { a in
            HStack {
                Text(a)
                Spacer()
                if user.allergies.contains(a) { Image(systemName: "checkmark").foregroundStyle(SanaTheme.Color.primary) }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if user.allergies.contains(a) { user.allergies.removeAll { $0 == a } }
                else { user.allergies.append(a) }
            }
        }
        .navigationTitle("Allergies")
    }
}
