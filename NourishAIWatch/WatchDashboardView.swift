// NourishAI — WatchDashboardView.swift
import SwiftUI

struct WatchDashboardView: View {

    @State private var data = WatchDataStore.load()
    @State private var waterLogged = false

    private let green = Color(red: 0.176, green: 0.620, blue: 0.459)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                calorieRing
                statsRow
                waterCard
                if data.streak > 0 { streakBadge }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("NourishAI")
        .onAppear { data = WatchDataStore.load() }
    }

    // MARK: - Calorie ring

    private var calorieRing: some View {
        ZStack {
            Circle()
                .stroke(green.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: data.calorieProgress)
                .stroke(green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: data.calorieProgress)
            VStack(spacing: 2) {
                Text("\(data.calories)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(green)
                Text("/ \(data.calorieTarget) kcal")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 110, height: 110)
        .padding(.top, 4)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 8) {
            watchStat(value: "\(Int(data.protein))g",
                      label: "Protein",
                      progress: data.proteinProgress,
                      color: .indigo)
            watchStat(value: "\(data.caloriesRemaining)",
                      label: "Remaining",
                      progress: 1 - data.calorieProgress,
                      color: green)
        }
    }

    private func watchStat(value: String, label: String, progress: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            .frame(width: 54, height: 54)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Water quick-log

    private var waterCard: some View {
        VStack(spacing: 6) {
            HStack {
                Label("\(data.waterMl) ml", systemImage: "drop.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)
                Spacer()
                Text("\(data.waterGoalMl) ml goal")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: data.waterProgress)
                .tint(.blue)
            HStack(spacing: 6) {
                ForEach([150, 250, 350], id: \.self) { ml in
                    Button("+\(ml)") {
                        WatchDataStore.logWater(ml)
                        data.waterMl = min(data.waterGoalMl, data.waterMl + ml)
                        WKInterfaceDevice.current().play(.success)
                        waterLogged = true
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.blue)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(10)
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            waterLogged ?
            RoundedRectangle(cornerRadius: 12).stroke(Color.blue, lineWidth: 1.5) : nil
        )
    }

    // MARK: - Streak badge

    private var streakBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill").foregroundStyle(.orange)
            Text("\(data.streak) day streak")
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.12))
        .clipShape(Capsule())
    }
}
