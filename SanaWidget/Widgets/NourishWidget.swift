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
    var updatedAt: Date

    static let placeholder = SanaWidgetData(
        calories: 0, calorieTarget: 2000,
        waterMl: 0, waterGoalMl: 2000,
        streak: 0, protein: 0, proteinTarget: 120,
        updatedAt: .now
    )

    var calorieProgress: Double { min(1.0, Double(calories) / Double(max(1, calorieTarget))) }
    var waterProgress: Double   { min(1.0, Double(waterMl) / Double(max(1, waterGoalMl))) }
    var proteinProgress: Double { min(1.0, protein / max(1, proteinTarget)) }
    var caloriesRemaining: Int  { max(0, calorieTarget - calories) }
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
        // Refresh at midnight so streak and daily totals reset correctly
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
}

// MARK: - Deep link URLs

private enum WidgetLink {
    static let dashboard = URL(string: "nourishai://dashboard")!
    static let water     = URL(string: "nourishai://water")!
    static let log       = URL(string: "nourishai://log")!
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

// MARK: - Medium Widget  (ring + water bar + protein)

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
                // Streak
                if data.streak > 0 {
                    Label("\(data.streak) day streak", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                // Water
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill").foregroundStyle(.blue).font(.system(size: 10))
                        Text("\(data.waterMl) / \(data.waterGoalMl) ml")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    ProgressView(value: data.waterProgress)
                        .tint(.blue)
                        .scaleEffect(x: 1, y: 0.7)
                }

                // Protein
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").foregroundStyle(.indigo).font(.system(size: 10))
                        Text("\(Int(data.protein))g / \(Int(data.proteinTarget))g protein")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
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

// Medium widget uses Link() so different regions deep-link differently
extension MediumWidgetView {
    // Water row taps → water tab, rest → dashboard (handled by widgetURL fallback)
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
            Label("\(data.waterMl) / \(data.waterGoalMl) ml", systemImage: "drop.fill")
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
        Label("\(data.caloriesRemaining) kcal left  💧\(data.waterMl)ml", systemImage: "fork.knife")
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
        .description("Track your daily calories, water, and streak at a glance.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    SanaWidget()
} timeline: {
    SanaEntry(date: .now, data: SanaWidgetData(
        calories: 1240, calorieTarget: 2000,
        waterMl: 1200, waterGoalMl: 2000,
        streak: 5, protein: 78, proteinTarget: 120,
        updatedAt: .now
    ))
}

#Preview(as: .systemMedium) {
    SanaWidget()
} timeline: {
    SanaEntry(date: .now, data: SanaWidgetData(
        calories: 1240, calorieTarget: 2000,
        waterMl: 1200, waterGoalMl: 2000,
        streak: 5, protein: 78, proteinTarget: 120,
        updatedAt: .now
    ))
}
