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
        if !user.email.isEmpty {
            KeychainService.save(user.email, for: .userEmail)
            user.email = ""
            return KeychainService.load(for: .userEmail) ?? ""
        }
        return ""
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroCard

                statsGrid

                sectionLabel("Nutrition targets")
                nutritionCard

                if user.subscriptionTier == .free {
                    upgradeBanner
                }

                sectionLabel("Progress")
                progressCard

                sectionLabel("Settings")
                settingsCard

                signOutCard

                #if DEBUG
                debugCard
                #endif
            }
            .padding(.horizontal, SanaTheme.Spacing.lg)
            .padding(.bottom, SanaTheme.Spacing.xxxl)
        }
        .background(SanaTheme.Color.background.ignoresSafeArea())
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEditProfile = true }
                    .foregroundStyle(SanaTheme.Color.primary)
            }
        }
        .sheet(isPresented: $showingPaywall)       { PaywallView().environmentObject(subscription) }
        .sheet(isPresented: $showingNotifSettings) { NotificationSettingsView() }
        .sheet(isPresented: $showingEditProfile)   { EditProfileView(user: user) }
        .sheet(isPresented: $showingLogWeight)     { LogWeightSheet(user: user) }
        .sheet(isPresented: $showingExport) {
            if let url = exportURL { ShareSheet(items: [url]) }
        }
        .sheet(isPresented: $showingAchievements) { AchievementsView(user: user) }
        .sheet(isPresented: $showingBodyMetrics)  { BodyMetricsView(user: user) }
        .sheet(isPresented: $showingThemePicker)  { ThemePickerView() }
        .sheet(isPresented: $showingSupplements)  { SupplementTrackerView() }
    }

    // MARK: - Hero card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(SanaTheme.Color.primaryLight)
                        .frame(width: 72, height: 72)
                    Circle()
                        .stroke(SanaTheme.Color.primary.opacity(0.25), lineWidth: 2.5)
                        .frame(width: 78, height: 78)
                    Text(user.name.prefix(1).uppercased())
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(SanaTheme.Color.primary)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(user.name)
                        .font(SanaTheme.Font.title(20))
                    if !displayEmail.isEmpty {
                        Text(displayEmail)
                            .font(SanaTheme.Font.caption())
                            .foregroundStyle(.secondary)
                    }
                    if user.subscriptionTier == .premium {
                        Label("Premium", systemImage: "sparkles")
                            .font(SanaTheme.Font.caption(11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(SanaTheme.Color.primary).clipShape(Capsule())
                    }
                }
                Spacer()
            }

            if let change = user.weightChangeSinceStart {
                Label(
                    "\(change < 0 ? "−" : "+")\(user.formatWeight(abs(change))) since start",
                    systemImage: change < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
                )
                .font(SanaTheme.Font.caption(12))
                .foregroundStyle(change < 0 ? SanaTheme.Color.primary : .orange)
                .padding(.top, SanaTheme.Spacing.md)
            }
        }
        .nourishCard()
    }

    // MARK: - Stats grid (2×2)

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            weightCell
            MiniStatCell(icon: "ruler", color: .teal,
                         label: "Height", value: user.formattedHeight)
            MiniStatCell(icon: "waveform.path.ecg.rectangle.fill", color: .pink,
                         label: "BMI", value: String(format: "%.1f", user.bmi))
            MiniStatCell(icon: "figure.walk", color: SanaTheme.Color.primary,
                         label: "Activity", value: user.activityLevel.rawValue)
        }
    }

    private var weightCell: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.12)).frame(width: 32, height: 32)
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.blue)
                }
                Spacer()
                Button {
                    HapticService.selection()
                    showingLogWeight = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(SanaTheme.Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log weight")
            }
            Text(user.formattedCurrentWeight)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.8).lineLimit(1)
            Text("Weight")
                .font(SanaTheme.Font.caption(11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nourishCard()
    }

    // MARK: - Nutrition targets card

    private var nutritionCard: some View {
        VStack(spacing: 0) {
            iconValueRow(icon: "target", color: SanaTheme.Color.primary,
                         label: "Goal", value: user.primaryGoal.rawValue)
            cardDivider
            iconValueRow(icon: "flame.fill", color: .orange,
                         label: "Calories", value: "\(user.dailyCalorieTarget) kcal")
            cardDivider
            iconValueRow(icon: "bolt.fill", color: Color("MacroProtein"),
                         label: "Protein", value: "\(Int(user.dailyProteinTarget))g / day")
            cardDivider
            iconValueRow(icon: "leaf.fill", color: Color("MacroFiber"),
                         label: "Dietary style", value: user.dietaryStyle.rawValue)
        }
        .nourishCard()
    }

    // MARK: - Upgrade banner

    private var upgradeBanner: some View {
        Button { showingPaywall = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(SanaTheme.Color.primary.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SanaTheme.Color.primary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Upgrade to Premium")
                        .font(SanaTheme.Font.headline())
                        .foregroundStyle(SanaTheme.Color.primary)
                    Text("\(user.remainingFreeAnalyses) free analyses remaining today")
                        .font(SanaTheme.Font.caption(12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .nourishCard()
            .overlay(
                RoundedRectangle(cornerRadius: SanaTheme.Radius.lg)
                    .stroke(SanaTheme.Color.primary.opacity(0.2), lineWidth: 1)
            )
        }
        .accessibilityIdentifier("upgradeToPremium")
        .buttonStyle(.plain)
    }

    // MARK: - Progress card

    private var progressCard: some View {
        VStack(spacing: 0) {
            Button { showingAchievements = true } label: {
                let count = Achievement.all.filter { $0.checkUnlocked(user) }.count
                actionRow(icon: "trophy.fill", color: .yellow, title: "Achievements") {
                    Text("\(count)/\(Achievement.all.count)")
                        .font(SanaTheme.Font.caption())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            cardDivider
            Button { showingBodyMetrics = true } label: {
                actionRow(icon: "figure.stand", color: .teal, title: "Body metrics") { EmptyView() }
            }
            .buttonStyle(.plain)
            cardDivider
            Button { showingSupplements = true } label: {
                actionRow(icon: "pill.fill", color: .purple, title: "Supplements") { EmptyView() }
            }
            .buttonStyle(.plain)
        }
        .nourishCard()
    }

    // MARK: - Settings card

    private var settingsCard: some View {
        VStack(spacing: 0) {
            Button { showingNotifSettings = true } label: {
                actionRow(icon: "bell.fill", color: .orange, title: "Notification preferences") { EmptyView() }
            }
            .buttonStyle(.plain)

            cardDivider

            Button { showingThemePicker = true } label: {
                actionRow(icon: "paintpalette.fill", color: ThemeManager.shared.primaryColor, title: "App theme") {
                    Circle().fill(ThemeManager.shared.primaryColor).frame(width: 18, height: 18)
                }
            }
            .buttonStyle(.plain)

            cardDivider

            NavigationLink { AllergiesEditView(user: user) } label: {
                actionRow(icon: "exclamationmark.shield.fill", color: .red,
                          title: "Allergies & restrictions") { EmptyView() }
            }

            cardDivider

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                actionRow(icon: "globe", color: .blue, title: "Language") {
                    Text(Locale.current.localizedString(
                        forLanguageCode: Locale.current.language.languageCode?.identifier ?? "") ?? "")
                        .font(SanaTheme.Font.caption())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            cardDivider

            Button {
                if let url = ExportService.csvURL(for: user) {
                    exportURL = url
                    showingExport = true
                }
            } label: {
                actionRow(icon: "square.and.arrow.up", color: SanaTheme.Color.primary,
                          title: "Export meal data (CSV)") { EmptyView() }
            }
            .buttonStyle(.plain)
        }
        .nourishCard()
    }

    // MARK: - Sign out

    private var signOutCard: some View {
        Button(role: .destructive) {
            HapticService.destructive()
            AuthService.shared.signOut()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.10)).frame(width: 32, height: 32)
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.red)
                }
                Text("Sign out").font(SanaTheme.Font.body()).foregroundStyle(.red)
                Spacer()
            }
            .nourishCard()
        }
        .buttonStyle(.plain)
    }

    #if DEBUG
    private var debugCard: some View {
        Button(role: .destructive) {
            FirebaseService.shared.forceCrash()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.10)).frame(width: 32, height: 32)
                    Image(systemName: "ant.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Test Crashlytics crash").font(SanaTheme.Font.body()).foregroundStyle(.red)
                    Text("Debug only").font(SanaTheme.Font.caption(11)).foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .nourishCard()
            .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg)
                .stroke(Color.red.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    #endif

    // MARK: - Reusable row builders

    private func sectionLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .textCase(.uppercase)
            .font(SanaTheme.Font.caption(11))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(SanaTheme.Color.hairline)
            .frame(height: 0.5)
    }

    private func iconValueRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            }
            Text(label).font(SanaTheme.Font.body(15)).foregroundStyle(.primary)
            Spacer()
            Text(value).font(SanaTheme.Font.body(14)).foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }

    private func actionRow<Trailing: View>(
        icon: String, color: Color, title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            }
            Text(title).font(SanaTheme.Font.body(15)).foregroundStyle(.primary)
            Spacer()
            trailing()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Private sub-views

private struct MiniStatCell: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
                    .accessibilityHidden(true)
            }
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.75).lineLimit(2)
            Text(label)
                .font(SanaTheme.Font.caption(11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nourishCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct AllergiesEditView: View {
    @Bindable var user: User
    private let commonAllergens = ["Gluten", "Dairy", "Nuts", "Eggs", "Soy", "Shellfish", "Fish", "Sesame"]
    var body: some View {
        List(commonAllergens, id: \.self) { allergen in
            HStack {
                Text(allergen)
                Spacer()
                if user.allergies.contains(allergen) {
                    Image(systemName: "checkmark").foregroundStyle(SanaTheme.Color.primary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if user.allergies.contains(allergen) { user.allergies.removeAll { $0 == allergen } }
                else { user.allergies.append(allergen) }
            }
        }
        .navigationTitle("Allergies")
    }
}
