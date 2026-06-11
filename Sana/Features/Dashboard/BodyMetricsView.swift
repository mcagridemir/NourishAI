// Sana — BodyMetricsView.swift
// Detailed body composition and metabolic rate estimates.
import SwiftUI

struct BodyMetricsView: View {

    let user: User
    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed metrics

    private var heightM: Double { user.heightCm / 100 }
    private var weightKg: Double { user.latestWeightKg }

    private var bmi: Double {
        guard heightM > 0 else { return 0 }
        return weightKg / (heightM * heightM)
    }

    private var bmiCategory: (label: String, color: Color) {
        switch bmi {
        case ..<18.5: return ("Underweight", .blue)
        case 18.5..<25: return ("Healthy weight", SanaTheme.Color.primary)
        case 25..<30: return ("Overweight", .orange)
        default: return ("Obese", .red)
        }
    }

    /// Mifflin-St Jeor BMR
    private var bmr: Double {
        let base = 10 * weightKg + 6.25 * user.heightCm - 5 * Double(user.age ?? 30)
        return user.biologicalSex == .female ? base - 161 : base + 5
    }

    /// TDEE (Total Daily Energy Expenditure)
    private var tdee: Double { bmr * user.activityLevel.tdeeMultiplier }

    /// Healthy weight range for height (BMI 18.5 – 24.9)
    private var idealWeightRange: (min: Double, max: Double) {
        (18.5 * heightM * heightM, 24.9 * heightM * heightM)
    }

    /// Rough body fat % estimate via US Navy formula approximation
    private var estimatedBodyFat: Double? {
        // Need waist measurement — use a rough BMI proxy instead
        guard bmi > 0 else { return nil }
        // Jackson & Pollock BMI-to-BF% approximation
        let sexFactor: Double = user.biologicalSex == .female ? 5.4 : 0.0
        let ageFactor = Double(user.age ?? 30) * 0.23
        return 1.2 * bmi + ageFactor - 5.4 - sexFactor
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SanaTheme.Spacing.lg) {

                    // BMI Card
                    bmiCard

                    // Metabolic rate
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(label: "BMR", value: "\(Int(bmr))", unit: "kcal/day",
                                   icon: "flame", color: .orange,
                                   note: "Calories burned at rest")
                        MetricCard(label: "TDEE", value: "\(Int(tdee))", unit: "kcal/day",
                                   icon: "figure.walk", color: SanaTheme.Color.primary,
                                   note: "Total daily expenditure")
                        MetricCard(label: "Calorie goal", value: "\(user.dailyCalorieTarget)", unit: "kcal/day",
                                   icon: "target", color: .indigo,
                                   note: "Based on your goal")
                        if let bf = estimatedBodyFat {
                            MetricCard(label: "Est. body fat", value: String(format: "%.1f", max(3, bf)), unit: "%",
                                       icon: "drop.fill", color: .blue,
                                       note: "BMI-based estimate")
                        }
                    }

                    // Ideal weight range
                    idealWeightRangeCard

                    // Activity level
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Activity level", systemImage: "figure.run")
                            .font(SanaTheme.Font.headline())
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            HStack(spacing: 10) {
                                Image(systemName: user.activityLevel == level ? "circle.fill" : "circle")
                                    .foregroundStyle(user.activityLevel == level ? SanaTheme.Color.primary : .secondary)
                                    .font(.system(size: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(level.rawValue)
                                        .font(SanaTheme.Font.body(14))
                                        .fontWeight(user.activityLevel == level ? .semibold : .regular)
                                    Text("TDEE ×\(String(format: "%.2f", level.tdeeMultiplier))")
                                        .font(SanaTheme.Font.caption(11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if user.activityLevel == level {
                                    Text("Current")
                                        .font(SanaTheme.Font.caption(11))
                                        .foregroundStyle(SanaTheme.Color.primary)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(SanaTheme.Color.primaryLight)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        Text("Change your activity level in Edit Profile to recalculate targets.")
                            .font(SanaTheme.Font.caption(11))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .nourishCard()

                    // Disclaimer
                    Text("These are statistical estimates based on population averages and may not reflect your individual metabolism. Consult a healthcare professional for personalised guidance.")
                        .font(SanaTheme.Font.caption(11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Body metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Unit helpers

    private func formatWeight(_ kg: Double) -> String {
        user.unitSystem == .imperial
            ? String(format: "%.1f lbs", kg * 2.20462)
            : String(format: "%.1f kg", kg)
    }

    private var heightDescription: String {
        if user.unitSystem == .imperial {
            let totalInches = user.heightCm / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            return "\(feet)'\(inches)\""
        } else {
            return "\(Int(user.heightCm)) cm"
        }
    }

    // MARK: - Ideal weight range card

    private var idealWeightRangeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Ideal weight range", systemImage: "scalemass.fill")
                .font(SanaTheme.Font.headline())
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(formatWeight(idealWeightRange.min))
                        .font(SanaTheme.Font.headline(14))
                    Text("Lower").font(SanaTheme.Font.caption(11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Text("–")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(.secondary)
                VStack(spacing: 4) {
                    Text(formatWeight(idealWeightRange.max))
                        .font(SanaTheme.Font.headline(14))
                    Text("Upper").font(SanaTheme.Font.caption(11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            Text(String(format: NSLocalizedString("Based on a healthy BMI of 18.5–24.9 for your height (%@)", comment: ""), heightDescription))
                .font(SanaTheme.Font.caption(11))
                .foregroundStyle(.secondary)

            let delta = weightKg - idealWeightRange.max
            if delta > 0 {
                Label("\(formatWeight(delta)) above healthy range", systemImage: "arrow.down.circle.fill")
                    .font(SanaTheme.Font.body(13))
                    .foregroundStyle(.orange)
            } else if weightKg < idealWeightRange.min {
                let below = idealWeightRange.min - weightKg
                Label("\(formatWeight(below)) below healthy range", systemImage: "arrow.up.circle.fill")
                    .font(SanaTheme.Font.body(13))
                    .foregroundStyle(.blue)
            } else {
                Label("You're within the healthy range", systemImage: "checkmark.circle.fill")
                    .font(SanaTheme.Font.body(13))
                    .foregroundStyle(SanaTheme.Color.primary)
            }
        }
        .padding()
        .nourishCard()
    }

    // MARK: - BMI card

    private var bmiCard: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Body Mass Index", systemImage: "figure.stand")
                    .font(SanaTheme.Font.headline())
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f", bmi))
                        .font(SanaTheme.Font.numeric)
                        .foregroundStyle(bmiCategory.color)
                    Text(bmiCategory.label)
                        .font(SanaTheme.Font.caption(11))
                        .foregroundStyle(bmiCategory.color)
                }
            }

            // BMI scale bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background gradient
                    LinearGradient(
                        colors: [.blue, SanaTheme.Color.primary, .yellow, .orange, .red],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    // Indicator
                    let clampedBMI = min(40, max(15, bmi))
                    let fraction = (clampedBMI - 15) / 25 // 15–40 range
                    Circle()
                        .fill(.white)
                        .shadow(radius: 2)
                        .frame(width: 18, height: 18)
                        .offset(x: geo.size.width * fraction - 9)
                }
            }
            .frame(height: 18)

            // Scale labels
            HStack {
                Text("15").font(SanaTheme.Font.caption(10)).foregroundStyle(.secondary)
                Spacer()
                Text("18.5").font(SanaTheme.Font.caption(10)).foregroundStyle(.secondary)
                Spacer()
                Text("25").font(SanaTheme.Font.caption(10)).foregroundStyle(.secondary)
                Spacer()
                Text("30").font(SanaTheme.Font.caption(10)).foregroundStyle(.secondary)
                Spacer()
                Text("40+").font(SanaTheme.Font.caption(10)).foregroundStyle(.secondary)
            }
        }
        .padding()
        .nourishCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BMI: \(String(format: "%.1f", bmi)). \(bmiCategory.label).")
    }
}

// MARK: - MetricCard

private struct MetricCard: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 16))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(SanaTheme.Font.numeric).foregroundStyle(.primary)
                Text(unit).font(SanaTheme.Font.caption(11)).foregroundStyle(.secondary)
            }
            Text(label).font(SanaTheme.Font.caption(11)).foregroundStyle(.secondary)
            Text(note).font(SanaTheme.Font.caption(10)).foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value) \(unit). \(note).")
    }
}

// MARK: - ActivityLevel TDEE multiplier extension

private extension ActivityLevel {
    var tdeeMultiplier: Double { multiplier }
}
