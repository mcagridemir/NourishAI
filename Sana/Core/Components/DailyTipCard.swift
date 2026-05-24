// Sana — DailyTipCard.swift
// Rotating daily nutrition tip based on day-of-year.
import SwiftUI

struct DailyTipCard: View {

    private static let tips: [(icon: String, text: String, color: Color)] = [
        ("drop.fill",        "Drinking water before meals can reduce calorie intake by up to 13%.", .blue),
        ("bolt.fill",        "Spreading protein intake throughout the day improves muscle synthesis vs. eating it all at once.", .indigo),
        ("moon.zzz.fill",    "Poor sleep increases hunger hormones (ghrelin) by up to 24% the next day.", .purple),
        ("leaf.fill",        "Eating a rainbow of vegetables ensures a wide variety of antioxidants and micronutrients.", SanaTheme.Color.primary),
        ("flame.fill",       "Protein has a thermic effect of ~30%: your body burns more calories digesting it than carbs or fat.", .orange),
        ("clock.fill",       "Eating within an 8–10 hour window (time-restricted eating) can improve metabolic health.", .teal),
        ("heart.fill",       "Omega-3 fatty acids in fatty fish, walnuts, and flaxseed support heart and brain health.", .red),
        ("figure.walk",      "A 10-minute walk after meals can lower post-meal blood sugar by 22%.", SanaTheme.Color.primary),
        ("fork.knife",       "Eating slowly and mindfully can reduce total food intake by 10–20% per meal.", .orange),
        ("chart.bar.fill",   "Fiber feeds your gut microbiome — aim for 25–35g daily from whole grains, legumes, and vegetables.", .green),
        ("sun.max.fill",     "Your body produces vitamin D from sunlight. 15 minutes of sun exposure most days supports bone health.", .yellow),
        ("bed.double.fill",  "Magnesium-rich foods like spinach, almonds, and dark chocolate support quality sleep.", .indigo),
        ("scalemass.fill",   "Weight fluctuates 1–3 kg day-to-day due to water, food, and hormones — trend over weeks, not days.", .secondary),
        ("eye.fill",         "Vitamin A (from carrots, sweet potato, liver) is essential for night vision and immune function.", .orange),
        ("hand.raised.fill", "Processed foods high in ultra-processed ingredients can displace nutritious whole foods — aim for 80/20.", SanaTheme.Color.primary),
        ("snowflake",        "Cold-water immersion and cool showers may improve metabolism and mood via norepinephrine release.", .blue),
        ("arrow.up.heart.fill", "Zinc from meat, shellfish, and pumpkin seeds supports immune function and wound healing.", .red),
        ("wind",             "Deep nasal breathing activates the parasympathetic nervous system, reducing cortisol and cravings.", .teal),
        ("carrot",           "Chewing food thoroughly (20–30 chews per bite) improves digestion and satiety signalling.", .orange),
        ("sparkles",         "Polyphenols in berries, green tea, and olive oil are linked to longevity and reduced inflammation.", .purple),
        ("dumbbell.fill",    "Resistance training 2–3× per week increases resting metabolism and preserves lean muscle during fat loss.", .indigo),
        ("cup.and.saucer.fill", "Caffeine peaks in the bloodstream 30–60 minutes after consumption — time it before workouts for best effect.", .brown),
        ("globe.americas.fill", "Mediterranean and MIND diets consistently rank as the most evidence-backed eating patterns for longevity.", SanaTheme.Color.primary),
        ("exclamationmark.shield.fill", "Sodium in excess raises blood pressure. Most adults consume 2× the recommended 2,300 mg/day.", .orange),
        ("figure.strengthtraining.traditional", "Consuming 20–40g protein within 2 hours post-workout maximises muscle protein synthesis.", .indigo),
        ("sunset.fill",      "Limiting eating 2–3 hours before bed can improve sleep quality and overnight fat oxidation.", .purple),
        ("ant.fill",         "Your gut microbiome — 38 trillion bacteria — influences mood, immunity, and metabolism.", .green),
        ("pill.fill",        "Iron from meat (haem iron) is 2–3× more bioavailable than iron from plant sources.", .red),
        ("figure.yoga",      "Chronic stress elevates cortisol, which drives visceral fat storage — stress management is nutrition strategy.", .teal),
        ("waveform.path.ecg", "Your heart-rate variability (HRV) is a powerful proxy for recovery — track it alongside nutrition for best results.", .orange)
    ]

    private var todayTip: (icon: String, text: String, color: Color) {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1
        return Self.tips[dayOfYear % Self.tips.count]
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(todayTip.color.opacity(0.12)).frame(width: 48, height: 48)
                Image(systemName: todayTip.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(todayTip.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Label("Daily tip", systemImage: "lightbulb.fill")
                    .font(SanaTheme.Font.caption(11))
                    .foregroundStyle(todayTip.color)
                Text(todayTip.text)
                    .font(SanaTheme.Font.body(13))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .nourishCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily nutrition tip: \(todayTip.text)")
    }
}
