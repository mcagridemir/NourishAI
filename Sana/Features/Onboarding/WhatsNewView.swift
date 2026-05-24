// Sana — WhatsNewView.swift
// Shown once per app version to highlight new features.
import SwiftUI

struct WhatsNewView: View {

    @Environment(\.dismiss) private var dismiss
    @AppStorage("whatsNew.lastSeenVersion") private var lastSeenVersion: String = ""

    private let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"

    static func shouldShow() -> Bool {
        let seen = UserDefaults.standard.string(forKey: "whatsNew.lastSeenVersion") ?? ""
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return seen != current
    }

    private let features: [(icon: String, color: Color, title: String, body: String)] = [
        ("moon.zzz.fill",        .purple,  "Fasting Dynamic Island",
         "Your fast countdown now lives in the Dynamic Island — glanceable without opening the app."),
        ("square.grid.3x3.fill", SanaTheme.Color.primary, "Contribution Heatmap",
         "See 17 weeks of meal-logging consistency at a glance, just like GitHub."),
        ("mic.fill",             .indigo,  "Voice Meal Logging",
         "Say the name of your meal and Sana pre-fills the entry form instantly."),
        ("pill.fill",            .teal,    "Supplement Tracker",
         "Log daily vitamins and supplements with streak monitoring and dashboard quick-check."),
        ("doc.viewfinder",       SanaTheme.Color.primary, "Nutrition Label Scanner",
         "Photograph any nutrition facts panel — Claude extracts all macros in seconds."),
        ("star.fill",            .yellow,  "Daily Score",
         "A composite 0–100 score across calories, protein, hydration, meal quality, and activity."),
        ("chart.line.uptrend.xyaxis", .orange, "Calorie Forecast",
         "Predicts your end-of-day calorie total based on historical meal timing patterns."),
        ("lightbulb.fill",       .yellow,  "Smart Meal Suggestions",
         "Personalised next-meal ideas based on remaining macros and time of day."),
        ("arrow.left.arrow.right", SanaTheme.Color.primary, "Week-on-Week Comparison",
         "Side-by-side view of this week vs last week for all key nutrition metrics."),
        ("moon.stars.fill",      .indigo,  "Sleep & Nutrition",
         "Correlates your sleep quality with next-day eating patterns using Apple Health."),
        ("drop.fill",            .blue,    "Hydration Trend",
         "7-day water intake chart with daily goal line and goal-hit streak."),
        ("trophy.fill",          .yellow,  "Achievement Badges",
         "Unlock 15 badges for streaks, hydration, photo analysis, perfect days, and more."),
        ("paintpalette.fill",    .orange,  "App Themes",
         "Choose from 8 colour presets to personalise your Sana experience."),
        ("figure.stand",         .blue,    "Body Metrics",
         "See your BMI, BMR, TDEE, ideal weight range and activity multiplier in one place.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(SanaTheme.Color.primary)
                        Text("What's new in Sana")
                            .font(SanaTheme.Font.title(26))
                            .multilineTextAlignment(.center)
                        Text("Version \(currentVersion)")
                            .font(SanaTheme.Font.caption())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 24)

                    // Feature list
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(features, id: \.title) { feature in
                            HStack(alignment: .top, spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(feature.color.opacity(0.15))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: feature.icon)
                                        .font(.system(size: 22))
                                        .foregroundStyle(feature.color)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(feature.title)
                                        .font(SanaTheme.Font.headline(15))
                                    Text(feature.body)
                                        .font(SanaTheme.Font.body(13))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, SanaTheme.Spacing.lg)
                            .padding(.vertical, 14)
                            if feature.title != features.last?.title {
                                Divider().padding(.leading, 68 + SanaTheme.Spacing.lg)
                            }
                        }
                    }
                    .padding(.bottom, 32)

                    // CTA
                    Button("Continue") {
                        lastSeenVersion = currentVersion
                        dismiss()
                    }
                    .buttonStyle(NourishButtonStyle())
                    .padding(.horizontal, 40)
                    .padding(.bottom, 48)
                }
            }
            .background(SanaTheme.Color.background)
            .navigationBarHidden(true)
        }
    }
}
