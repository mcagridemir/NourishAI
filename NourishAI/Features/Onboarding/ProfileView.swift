// NourishAI — ProfileView.swift
import SwiftUI

struct ProfileView: View {
    @Bindable var user: User
    @EnvironmentObject private var subscription: SubscriptionService
    @State private var showingPaywall = false
    @State private var showingNotifSettings = false

    var body: some View {
        List {
            // Header
            Section {
                HStack(spacing: 14) {
                    Circle().fill(NourishTheme.Color.primaryLight).frame(width: 60, height: 60)
                        .overlay(Text(user.name.prefix(1)).font(NourishTheme.Font.title(24)).foregroundStyle(NourishTheme.Color.primary))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name).font(NourishTheme.Font.headline(18))
                        Text(user.email).font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
                        if user.subscriptionTier == .premium {
                            Label("Premium", systemImage: "sparkles").font(NourishTheme.Font.caption(11))
                                .foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 3)
                                .background(NourishTheme.Color.primary).clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            // Physical stats
            Section("Physical profile") {
                ProfileRow(label: "Height", value: "\(Int(user.heightCm)) cm")
                ProfileRow(label: "Weight", value: "\(String(format: "%.1f", user.weightKg)) kg")
                ProfileRow(label: "BMI", value: String(format: "%.1f", user.bmi))
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
                            Image(systemName: "sparkles").foregroundStyle(NourishTheme.Color.primary)
                            Text("Upgrade to Premium").foregroundStyle(NourishTheme.Color.primary)
                            Spacer()
                            Text("\(user.remainingFreeAnalyses) analyses left today")
                                .font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Settings
            Section("Settings") {
                Button { showingNotifSettings = true } label: {
                    Label("Notification preferences", systemImage: "bell").foregroundStyle(.primary)
                }
                NavigationLink(destination: AllergiesEditView(user: user)) {
                    Label("Allergies & restrictions", systemImage: "exclamationmark.shield")
                }
            }
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showingPaywall) { PaywallView().environmentObject(subscription) }
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
                if user.allergies.contains(a) { Image(systemName: "checkmark").foregroundStyle(NourishTheme.Color.primary) }
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
