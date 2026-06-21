// Sana — NutritionShareCard.swift
import SwiftUI

struct NutritionShareCard: View {
    let user: User
    let avgCalories: Int
    let avgProtein: Int
    let avgCarbs: Int
    let avgFat: Int
    let streak: Int
    let days: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sana")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.176, green: 0.620, blue: 0.459))
                    Text("\(days)-day nutrition summary")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 12))
                        Text("\(streak) day streak")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            Divider()

            HStack(spacing: 0) {
                shareMetric(value: "\(avgCalories)", unit: "kcal", label: "Avg calories", color: Color(red: 0.176, green: 0.620, blue: 0.459))
                shareMetric(value: "\(avgProtein)g", unit: "", label: "Avg protein", color: .blue)
                shareMetric(value: "\(avgCarbs)g", unit: "", label: "Avg carbs", color: .purple)
                shareMetric(value: "\(avgFat)g", unit: "", label: "Avg fat", color: .orange)
            }

            Text("Tracked with Sana")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        .frame(width: 340)
    }

    private func shareMetric(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Text(LocalizedStringKey(label)).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
