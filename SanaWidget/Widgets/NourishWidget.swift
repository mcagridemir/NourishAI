// Sana — SanaWidget.swift
import WidgetKit
import SwiftUI

// MARK: - Shared data types (widget-local — reads from App Group UserDefaults)

struct SanaWidgetData: Codable {
    var calories: Int
    var calorieTarget: Int
    var waterMl: Int
    var waterGoalMl: Int
    var streak: Int
    var protein: Double
    var proteinTarget: Double
    // v1.1 additions — defaults keep old stored JSON decodable.
    var carbs: Double = 0
    var carbsTarget: Double = 250
    var fat: Double = 0
    var fatTarget: Double = 65
    var updatedAt: Date
    var isImperial: Bool = false

    static let placeholder = SanaWidgetData(
        calories: 0, calorieTarget: 2000,
        waterMl: 0, waterGoalMl: 2000,
        streak: 0, protein: 0, proteinTarget: 120,
        updatedAt: .now
    )

    var calorieProgress: Double { min(1.0, Double(calories) / Double(max(1, calorieTarget))) }
    var waterProgress: Double   { min(1.0, Double(waterMl)  / Double(max(1, waterGoalMl))) }
    var proteinProgress: Double { min(1.0, protein / max(1, proteinTarget)) }
    var carbsProgress: Double   { min(1.0, carbs   / max(1, carbsTarget)) }
    var fatProgress: Double     { min(1.0, fat     / max(1, fatTarget)) }
    var caloriesRemaining: Int  { max(0, calorieTarget - calories) }

    func formatWater(_ ml: Int) -> String {
        if isImperial {
            return String(format: "%.0f fl oz", Double(ml) * 0.033814)
        }
        return ml >= 1000 ? String(format: "%.1fL", Double(ml) / 1000) : "\(ml) ml"
    }
}

private enum WidgetDataStore {
    static func load() -> SanaWidgetData {
        guard let defaults = UserDefaults(suiteName: "group.com.cagri.Sana"),
              let raw = defaults.data(forKey: "nourishWidgetData"),
              let decoded = try? JSONDecoder().decode(SanaWidgetData.self, from: raw)
        else { return .placeholder }
        return decoded
    }
}

// MARK: - Timeline Provider

struct SanaProvider: TimelineProvider {

    func placeholder(in context: Context) -> SanaEntry {
        SanaEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SanaEntry) -> Void) {
        completion(SanaEntry(date: .now, data: WidgetDataStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SanaEntry>) -> Void) {
        let entry = SanaEntry(date: .now, data: WidgetDataStore.load())
        // Refresh at midnight so streak and daily totals reset correctly.
        let midnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86400)
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }
}

struct SanaEntry: TimelineEntry {
    let date: Date
    let data: SanaWidgetData
}

// MARK: - Colors (hardcoded — asset catalog not available in widget target)

private extension Color {
    static let nourishGreen      = Color(red: 0.176, green: 0.620, blue: 0.459)  // #2D9E75
    static let nourishGreenLight = Color(red: 0.882, green: 0.961, blue: 0.933)  // #E1F5EE
    static let macroCarbs        = Color(red: 0.94, green: 0.65, blue: 0.20)
    static let macroFat          = Color(red: 0.98, green: 0.45, blue: 0.35)
}

// MARK: - Deep link URLs

private enum WidgetLink {
    static let dashboard = URL(string: "sana://dashboard")!
    static let water     = URL(string: "sana://water")!
    static let log       = URL(string: "sana://log")!
}

// MARK: - Small Widget  (calories ring + streak)

struct SmallWidgetView: View {
    let data: SanaWidgetData

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.nourishGreenLight, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: data.calorieProgress)
                    .stroke(Color.nourishGreen, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: data.calorieProgress)
                VStack(spacing: 1) {
                    Text("\(data.calories)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.nourishGreen)
                    Text("kcal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            if data.streak > 0 {
                Label("\(data.streak)d", systemImage: "flame.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .widgetURL(WidgetLink.dashboard)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Medium Widget  (ring + water + protein)

struct MediumWidgetView: View {
    let data: SanaWidgetData

    var body: some View {
        HStack(spacing: 16) {
            // Calorie ring
            ZStack {
                Circle()
                    .stroke(Color.nourishGreenLight, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: data.calorieProgress)
                    .stroke(Color.nourishGreen, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(data.caloriesRemaining)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.nourishGreen)
                    Text("left")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 72)

            // Stats column
            VStack(alignment: .leading, spacing: 10) {
                if data.streak > 0 {
                    Label("\(data.streak) day streak", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill").foregroundStyle(.blue).font(.system(size: 10))
                        Text("\(data.formatWater(data.waterMl)) / \(data.formatWater(data.waterGoalMl))")
                            .font(.system(size: 11, weight: .medium))
                    }
                    ProgressView(value: data.waterProgress)
                        .tint(.blue)
                        .scaleEffect(x: 1, y: 0.7)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").foregroundStyle(.indigo).font(.system(size: 10))
                        Text("\(Int(data.protein))g / \(Int(data.proteinTarget))g protein")
                            .font(.system(size: 11, weight: .medium))
                    }
                    ProgressView(value: data.proteinProgress)
                        .tint(.indigo)
                        .scaleEffect(x: 1, y: 0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Large Widget  (full macro dashboard)

struct LargeWidgetView: View {
    let data: SanaWidgetData

    var body: some View {
        VStack(spacing: 0) {
            header
            calorieSection
            Divider().padding(.horizontal, 16)
            macroRow
            Divider().padding(.horizontal, 16)
            waterSection
            footer
        }
        .widgetURL(WidgetLink.dashboard)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.nourishGreen)
                Text("Sana")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            Spacer()
            Text(Date(), format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: Calorie ring

    private var calorieSection: some View {
        ZStack {
            Circle()
                .stroke(Color.nourishGreenLight, lineWidth: 13)
            Circle()
                .trim(from: 0, to: data.calorieProgress)
                .stroke(Color.nourishGreen,
                        style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: data.calorieProgress)
            VStack(spacing: 3) {
                Text("\(data.calories)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.nourishGreen)
                Text("of \(data.calorieTarget) kcal")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("\(Int(data.calorieProgress * 100))% of goal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.nourishGreen.opacity(0.9))
            }
        }
        .frame(width: 128, height: 128)
        .padding(.vertical, 10)
    }

    // MARK: Macro mini-rings

    private var macroRow: some View {
        HStack(spacing: 0) {
            macroRing(label: "Protein", value: data.protein,
                      target: data.proteinTarget, progress: data.proteinProgress,
                      color: .indigo)
            macroRing(label: "Carbs", value: data.carbs,
                      target: data.carbsTarget, progress: data.carbsProgress,
                      color: Color.macroCarbs)
            macroRing(label: "Fat", value: data.fat,
                      target: data.fatTarget, progress: data.fatProgress,
                      color: Color.macroFat)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
    }

    private func macroRing(label: String, value: Double, target: Double,
                           progress: Double, color: Color) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            .frame(width: 58, height: 58)
            VStack(spacing: 1) {
                Text("\(Int(value)) / \(Int(target))g")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Water

    private var waterSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Link(destination: WidgetLink.water) {
                HStack(spacing: 5) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                    Text("Water  \(data.formatWater(data.waterMl)) / \(data.formatWater(data.waterGoalMl))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(Int(data.waterProgress * 100))%")
                        .font(.system(size: 11))
                        .foregroundStyle(.blue)
                }
            }
            ProgressView(value: data.waterProgress)
                .tint(.blue)
                .scaleEffect(x: 1, y: 0.75)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if data.streak > 0 {
                Label("\(data.streak) day streak", systemImage: "flame.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
            } else {
                Text("No active streak — log a meal!")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Link(destination: WidgetLink.log) {
                HStack(spacing: 3) {
                    Image(systemName: "plus.circle.fill")
                    Text("Log meal")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.nourishGreen)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }
}

// MARK: - Lock Screen: Circular (calorie ring)

struct AccessoryCircularView: View {
    let data: SanaWidgetData
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            ProgressView(value: data.calorieProgress)
                .progressViewStyle(.circular)
                .tint(Color.nourishGreen)
            VStack(spacing: 0) {
                Text("\(data.calories)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("kcal")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Lock Screen: Rectangular (calories + water bar)

struct AccessoryRectangularView: View {
    let data: SanaWidgetData
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("\(data.calories) / \(data.calorieTarget) kcal", systemImage: "flame.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.nourishGreen)
            ProgressView(value: data.calorieProgress).tint(Color.nourishGreen)
            Label("\(data.formatWater(data.waterMl)) / \(data.formatWater(data.waterGoalMl))", systemImage: "drop.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.blue)
            ProgressView(value: data.waterProgress).tint(.blue)
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Lock Screen: Inline (remaining calories)

struct AccessoryInlineView: View {
    let data: SanaWidgetData
    var body: some View {
        Label("\(data.caloriesRemaining) kcal left  💧\(data.formatWater(data.waterMl))", systemImage: "fork.knife")
    }
}

// MARK: - Widget Entry View

struct SanaWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SanaEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.data)
        case .systemMedium:
            MediumWidgetView(data: entry.data)
        case .systemLarge:
            LargeWidgetView(data: entry.data)
        case .accessoryCircular:
            AccessoryCircularView(data: entry.data)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            AccessoryRectangularView(data: entry.data)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            AccessoryInlineView(data: entry.data)
                .containerBackground(for: .widget) { Color.clear }
        default:
            MediumWidgetView(data: entry.data)
        }
    }
}

// MARK: - Widget Configuration

struct SanaWidget: Widget {
    let kind = "com.cagri.Sana.SanaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SanaProvider()) { entry in
            SanaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Sana")
        .description("Track your daily calories, macros, water, and streak at a glance.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

// MARK: - Previews

private let sampleData = SanaWidgetData(
    calories: 1240, calorieTarget: 2000,
    waterMl: 1200, waterGoalMl: 2000,
    streak: 5, protein: 78, proteinTarget: 120,
    carbs: 160, carbsTarget: 250,
    fat: 42, fatTarget: 65,
    updatedAt: .now
)

#Preview(as: .systemSmall) {
    SanaWidget()
} timeline: {
    SanaEntry(date: .now, data: sampleData)
}

#Preview(as: .systemMedium) {
    SanaWidget()
} timeline: {
    SanaEntry(date: .now, data: sampleData)
}

#Preview(as: .systemLarge) {
    SanaWidget()
} timeline: {
    SanaEntry(date: .now, data: sampleData)
}
