// NourishAI — FastingTrackerView.swift
import SwiftUI
internal import Combine

struct FastingTrackerView: View {

    // Persisted across launches
    @AppStorage("fasting.startDate")   private var startDateRef: Double = 0
    @AppStorage("fasting.targetHours") private var targetHours: Double = 16
    @AppStorage("fasting.isActive")    private var isActive: Bool = false

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var startDate: Date { Date(timeIntervalSinceReferenceDate: startDateRef) }
    private var targetSeconds: Double { targetHours * 3600 }
    private var elapsed: Double { isActive ? max(0, now.timeIntervalSince(startDate)) : 0 }
    private var progress: Double { min(1, elapsed / targetSeconds) }
    private var remaining: Double { max(0, targetSeconds - elapsed) }
    private var isDone: Bool { isActive && elapsed >= targetSeconds }

    private let protocols: [(String, Double)] = [
        ("12:12", 12), ("16:8", 16), ("18:6", 18), ("20:4", 20), ("OMAD", 23)
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Fasting", systemImage: "timer")
                    .font(NourishTheme.Font.headline())
                Spacer()
                Menu {
                    ForEach(protocols, id: \.0) { name, hours in
                        Button("\(name) — \(Int(hours))h fast") {
                            targetHours = hours
                            if isActive { restart() }
                        }
                    }
                } label: {
                    Text("\(Int(targetHours)):\(Int(24 - targetHours)) protocol")
                        .font(NourishTheme.Font.caption(12))
                        .foregroundStyle(NourishTheme.Color.primary)
                }
            }

            HStack(spacing: 24) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(NourishTheme.Color.primaryLight, lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(isDone ? Color.orange : NourishTheme.Color.primary,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(NourishTheme.Animation.smooth, value: progress)
                    VStack(spacing: 2) {
                        Text(isActive ? timeString(elapsed) : "--:--:--")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(isDone ? .orange : NourishTheme.Color.primary)
                        Text(isActive ? "elapsed" : "not started")
                            .font(NourishTheme.Font.caption(10))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 90, height: 90)

                VStack(alignment: .leading, spacing: 10) {
                    fastingStat(icon: "target",
                                label: "Target",
                                value: "\(Int(targetHours))h fast")
                    fastingStat(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                                label: "Remaining",
                                value: isActive ? timeString(remaining) : "--")
                    fastingStat(icon: isDone ? "flame.fill" : "moon.zzz.fill",
                                label: isDone ? "Fat burning!" : "Zone",
                                value: zoneLabel,
                                accent: isDone)
                }
                Spacer()
            }

            // Action button
            Button(action: toggleFasting) {
                Label(isActive ? "End fast" : "Start fast",
                      systemImage: isActive ? "stop.circle.fill" : "play.circle.fill")
                    .font(NourishTheme.Font.headline())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NourishButtonStyle(isPrimary: !isActive))
            .tint(isActive ? Color.red : NourishTheme.Color.primary)
        }
        .padding()
        .nourishCard()
        .onReceive(timer) { tick in
            now = tick
            // Sync zone and completion to Live Activity every minute
            let second = Int(elapsed) % 60
            if isActive && second == 0 {
                if isDone {
                    Task { await FastingLiveActivityService.shared.complete() }
                } else {
                    Task { await FastingLiveActivityService.shared.update(zone: zoneLabel) }
                }
            }
        }
    }

    // MARK: - Helpers

    private var zoneLabel: String {
        guard isActive else { return "—" }
        if elapsed < 4 * 3600  { return "Digesting" }
        if elapsed < 8 * 3600  { return "Absorbing" }
        if elapsed < 12 * 3600 { return "Glycogen depleting" }
        if elapsed < 16 * 3600 { return "Fat burning 🔥" }
        return "Deep ketosis 🔥"
    }

    private func fastingStat(icon: String, label: String, value: String, accent: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(accent ? .orange : NourishTheme.Color.primary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(NourishTheme.Font.caption(10))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(NourishTheme.Font.headline(13))
                    .foregroundStyle(accent ? .orange : .primary)
            }
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    private func toggleFasting() {
        HapticService.impact(.medium)
        if isActive {
            isActive = false
            NotificationService.shared.cancelFastingNotification()
            Task { await FastingLiveActivityService.shared.end() }
        } else {
            let now = Date()
            startDateRef = now.timeIntervalSinceReferenceDate
            isActive = true
            NotificationService.shared.scheduleFastingComplete(
                in: targetHours * 3600,
                targetHours: Int(targetHours)
            )
            Task {
                await FastingLiveActivityService.shared.start(
                    startDate: now,
                    targetSeconds: targetHours * 3600,
                    zone: "Digesting"
                )
            }
        }
    }

    private func restart() {
        let now = Date()
        startDateRef = now.timeIntervalSinceReferenceDate
        NotificationService.shared.scheduleFastingComplete(
            in: targetHours * 3600,
            targetHours: Int(targetHours)
        )
        Task {
            await FastingLiveActivityService.shared.end()
            await FastingLiveActivityService.shared.start(
                startDate: now,
                targetSeconds: targetHours * 3600,
                zone: "Digesting"
            )
        }
    }
}
