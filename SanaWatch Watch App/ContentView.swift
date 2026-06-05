// Sana — ContentView.swift (watchOS 10)
// Full 6-page page-based companion app.
// Pages: Today · Log · Water · Fasting · Macros · Coach
import SwiftUI
import WatchKit
import Combine

// MARK: - Data model (mirrors SanaWidgetData stored in App Group)

private struct WatchData: Codable {
    var calories: Int    = 0
    var calorieTarget: Int = 2000
    var waterMl: Int     = 0
    var waterGoalMl: Int = 2000
    var streak: Int      = 0
    var protein: Double  = 0
    var proteinTarget: Double = 120
    var carbs: Double    = 0
    var carbsTarget: Double  = 250
    var fat: Double      = 0
    var fatTarget: Double    = 65
    var isImperial: Bool = false

    static let placeholder = WatchData()

    var caloriesRemaining: Int { max(0, calorieTarget - calories) }
    var calorieProgress: Double { min(1, Double(calories) / Double(max(1, calorieTarget))) }
    var waterProgress: Double   { min(1, Double(waterMl)  / Double(max(1, waterGoalMl))) }
    var proteinProgress: Double { min(1, protein / max(1, proteinTarget)) }
    var carbsProgress: Double   { min(1, carbs   / max(1, carbsTarget)) }
    var fatProgress: Double     { min(1, fat     / max(1, fatTarget)) }

    func formatWater(_ ml: Int) -> String {
        if isImperial { return String(format: "%.0f oz", Double(ml) * 0.033814) }
        return ml >= 1000 ? String(format: "%.1fL", Double(ml) / 1000) : "\(ml) ml"
    }
}

private struct WatchFasting {
    var isActive: Bool     = false
    var startDate: Date    = .now
    var targetHours: Double = 16

    var elapsed: Double {
        isActive ? max(0, Date().timeIntervalSince(startDate)) : 0
    }
    var targetSeconds: Double { targetHours * 3600 }
    var progress: Double  { min(1, elapsed / targetSeconds) }
    var remaining: Double { max(0, targetSeconds - elapsed) }
    var isDone: Bool      { isActive && elapsed >= targetSeconds }

    var zoneLabel: String {
        guard isActive else { return "—" }
        if elapsed < 4 * 3600  { return "Digesting" }
        if elapsed < 8 * 3600  { return "Absorbing" }
        if elapsed < 12 * 3600 { return "Glycogen depleting" }
        if elapsed < 16 * 3600 { return "Fat burning 🔥" }
        return "Deep ketosis 🔥"
    }
}

// MARK: - App Group accessor

private enum AppGroupStore {
    static let suiteName = "group.com.cagri.Sana"

    static func loadData() -> WatchData {
        guard let ud  = UserDefaults(suiteName: suiteName),
              let raw = ud.data(forKey: "nourishWidgetData"),
              let d   = try? JSONDecoder().decode(WatchData.self, from: raw)
        else { return .placeholder }
        return d
    }

    static func loadFasting() -> WatchFasting {
        guard let ud = UserDefaults(suiteName: suiteName) else { return WatchFasting() }
        let isActive  = ud.bool(forKey: "fasting.isActive")
        let startRef  = ud.double(forKey: "fasting.startDate")
        let tgt       = ud.double(forKey: "fasting.targetHours")
        return WatchFasting(
            isActive:    isActive,
            startDate:   Date(timeIntervalSinceReferenceDate: startRef),
            targetHours: tgt > 0 ? tgt : 16
        )
    }

    /// Queue ml to be flushed by the iPhone app on next foreground.
    static func logWater(_ ml: Int) {
        guard let ud = UserDefaults(suiteName: suiteName) else { return }
        ud.set(ud.integer(forKey: "siri.pendingWaterMl") + ml, forKey: "siri.pendingWaterMl")
    }
}

// MARK: - Design tokens

private extension Color {
    static let sanaGreen = Color(red: 0.176, green: 0.620, blue: 0.459)  // #2D9E75
    static let sanaBlue  = Color(red: 0.290, green: 0.486, blue: 1.000)  // #4A7CFF
    static let sanaGold  = Color(red: 0.941, green: 0.765, blue: 0.431)  // carbs amber
    static let sanaCoral = Color(red: 1.000, green: 0.624, blue: 0.541)  // fat coral
}

private func hhmmss(_ s: Double) -> String {
    let t = Int(s)
    return String(format: "%02d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
}

// MARK: - Root

struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchTodayPage()
            WatchLogPage()
            WatchWaterPage()
            WatchFastingPage()
            WatchMacrosPage()
            WatchCoachPage()
        }
        .tabViewStyle(.page)
    }
}

// MARK: - Page 1 · Today

private struct WatchTodayPage: View {
    @State private var data = AppGroupStore.loadData()

    var body: some View {
        VStack(spacing: 0) {
            pageLabel("Today", color: .sanaGreen)

            Spacer(minLength: 0)

            // Calorie ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 11)
                Circle()
                    .trim(from: 0, to: data.calorieProgress)
                    .stroke(Color.sanaGreen, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: data.calorieProgress)
                VStack(spacing: 0) {
                    Text("Left")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(data.caloriesRemaining)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.sanaGreen)
                        .monospacedDigit()
                    Text("kcal")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 108, height: 108)

            Spacer(minLength: 0)

            // P · C · F bottom strip
            HStack(spacing: 0) {
                macroChip("P", value: Int(data.protein), color: .sanaBlue)
                macroChip("C", value: Int(data.carbs),   color: .sanaGold)
                macroChip("F", value: Int(data.fat),     color: .sanaCoral)
            }
            .padding(.bottom, 8)
        }
        .onAppear { data = AppGroupStore.loadData() }
    }

    private func macroChip(_ label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text("g")
                    .font(.system(size: 9))
                    .foregroundStyle(color.opacity(0.7))
            }
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Page 2 · Log

private struct WatchLogPage: View {
    @State private var data = AppGroupStore.loadData()
    @State private var waterLogged = false

    private let actions: [(icon: String, label: String, color: Color)] = [
        ("drop.fill",    "Water",  .sanaBlue),
        ("mic.fill",     "Voice",  .sanaGreen),
        ("clock.fill",   "Recent", Color(red: 0.808, green: 0.667, blue: 1.0)),
        ("sparkles",     "Coach",  .sanaGold),
    ]

    var body: some View {
        VStack(spacing: 0) {
            pageLabel("Quick Log", color: .sanaGreen)
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                ForEach(actions, id: \.label) { action in
                    Button {
                        handleTap(action.label)
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(action.color.opacity(waterLogged && action.label == "Water" ? 1 : 0.85))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: action.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                )
                            Text(action.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(action.color.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
        }
    }

    private func handleTap(_ label: String) {
        WKInterfaceDevice.current().play(.click)
        if label == "Water" {
            AppGroupStore.logWater(250)
            withAnimation { waterLogged = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { waterLogged = false }
            }
        }
    }
}

// MARK: - Page 3 · Water

private struct WatchWaterPage: View {
    @State private var data   = AppGroupStore.loadData()
    @State private var logged = false

    private let segments = 8

    var body: some View {
        VStack(spacing: 0) {
            pageLabel("Water", color: .sanaBlue)

            Spacer(minLength: 0)

            // Current / goal
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(data.formatWater(data.waterMl))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.sanaBlue)
                    .monospacedDigit()
                Text("/ \(data.formatWater(data.waterGoalMl))")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Glass segments
            HStack(spacing: 4) {
                let filled = Int((data.waterProgress * Double(segments)).rounded())
                ForEach(0..<segments, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i < filled ? Color.sanaBlue : Color.white.opacity(0.12))
                        .frame(width: 14, height: 26)
                }
            }
            .padding(.vertical, 10)

            // +250 ml button
            Button {
                WKInterfaceDevice.current().play(.success)
                AppGroupStore.logWater(250)
                // Optimistically update local display
                data.waterMl = min(data.waterGoalMl, data.waterMl + 250)
                logged = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { logged = false }
            } label: {
                Label(logged ? "Logged!" : "+ 250 ml",
                      systemImage: logged ? "checkmark" : "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(logged ? Color.sanaGreen : Color.sanaBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .animation(.easeInOut(duration: 0.2), value: logged)
        }
        .onAppear { data = AppGroupStore.loadData() }
    }
}

// MARK: - Page 4 · Fasting

private struct WatchFastingPage: View {
    @State private var fasting = AppGroupStore.loadFasting()
    @State private var now     = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var elapsed: Double {
        fasting.isActive ? max(0, now.timeIntervalSince(fasting.startDate)) : 0
    }
    private var progress: Double { min(1, elapsed / fasting.targetSeconds) }
    private var remaining: Double { max(0, fasting.targetSeconds - elapsed) }

    var body: some View {
        VStack(spacing: 0) {
            pageLabel("Fasting", color: .sanaGold)

            Spacer(minLength: 0)

            if fasting.isActive {
                // Fasting ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [.sanaGold, .sanaGreen],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text(hhmmss(elapsed))
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.sanaGold)
                        Text("of \(Int(fasting.targetHours))h")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(width: 106, height: 106)

                // Remaining
                Text(hhmmss(remaining) + " left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 6)
            } else {
                // Not fasting state
                VStack(spacing: 10) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.sanaGold)
                    Text("No active fast")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Start on iPhone")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer(minLength: 0)
        }
        .onAppear { fasting = AppGroupStore.loadFasting(); now = Date() }
        .onReceive(timer) { tick in
            now = tick
            // Refresh fasting data every 30 s in case app group was updated
            if Int(tick.timeIntervalSince1970) % 30 == 0 {
                fasting = AppGroupStore.loadFasting()
            }
        }
    }
}

// MARK: - Page 5 · Macros

private struct WatchMacrosPage: View {
    @State private var data = AppGroupStore.loadData()

    private var rows: [(label: String, value: Double, target: Double, color: Color)] {[
        ("Protein", data.protein, data.proteinTarget, .sanaBlue),
        ("Carbs",   data.carbs,   data.carbsTarget,   .sanaGold),
        ("Fat",     data.fat,     data.fatTarget,      .sanaCoral),
    ]}

    var body: some View {
        VStack(spacing: 0) {
            pageLabel("Macros", color: .sanaGreen)
                .padding(.bottom, 6)

            VStack(spacing: 10) {
                ForEach(rows, id: \.label) { row in
                    VStack(spacing: 4) {
                        HStack {
                            Text(row.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer()
                            HStack(spacing: 1) {
                                Text("\(Int(row.value))")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(row.color)
                                Text("/\(Int(row.target))g")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.10))
                                    .frame(height: 5)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(row.color)
                                    .frame(
                                        width: geo.size.width * min(1, row.target > 0 ? row.value / row.target : 0),
                                        height: 5
                                    )
                                    .animation(.easeOut(duration: 0.5), value: row.value)
                            }
                        }
                        .frame(height: 5)
                    }
                }
            }
            .padding(.horizontal, 6)

            Spacer(minLength: 0)
        }
        .onAppear { data = AppGroupStore.loadData() }
    }
}

// MARK: - Page 6 · Coach

private struct WatchCoachPage: View {
    // 12 rotating tips – one per index (day-of-month % 12)
    private static let tips: [String] = [
        "Aim for 1 g of protein per lb of body weight to build and maintain muscle.",
        "Drinking water 30 min before meals can reduce calorie intake by 13%.",
        "A 10-minute walk after eating cuts blood-sugar spikes by up to 22%.",
        "Fiber keeps you full longer — target 25–38 g daily.",
        "Eating slowly helps your gut signal fullness 20 min after you start.",
        "Colorful vegetables pack more antioxidants per calorie than any supplement.",
        "Greek yogurt has 2× more protein than regular yogurt — same calories.",
        "Skipping breakfast often leads to larger portions at lunch and dinner.",
        "Omega-3s in salmon reduce inflammation and support brain health.",
        "Dark chocolate (>70% cacao) satisfies sweet cravings with less sugar.",
        "Getting 7–9 hours of sleep helps regulate hunger hormones.",
        "Magnesium-rich foods (spinach, pumpkin seeds) support 300+ body functions.",
    ]

    private var tip: String {
        let day = Calendar.current.component(.day, from: .now)
        return Self.tips[day % Self.tips.count]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                pageLabel("Coach", color: Color(red: 0.608, green: 0.498, blue: 0.902))

                HStack(spacing: 6) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.sanaGreen, Color(red: 0.608, green: 0.498, blue: 0.902)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                                .foregroundStyle(.white)
                        )
                    Text("Daily tip")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Text(tip)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Shared helpers

private func pageLabel(_ text: String, color: Color) -> some View {
    Text(text)
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.top, 6)
}

// MARK: - Preview

#Preview {
    WatchRootView()
}
