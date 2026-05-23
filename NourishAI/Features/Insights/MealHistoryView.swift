// NourishAI — MealHistoryView.swift
import SwiftUI

struct MealHistoryView: View {
    @Bindable var user: User
    @State private var searchText = ""

    private var grouped: [(String, [MealEntry])] {
        let filtered = searchText.isEmpty ? user.mealEntries :
            user.mealEntries.filter { $0.mealName.localizedCaseInsensitiveContains(searchText) }
        let byDay = Dictionary(grouping: filtered.sorted { $0.loggedAt > $1.loggedAt }) {
            Calendar.current.startOfDay(for: $0.loggedAt).formatted(.dateTime.month().day().year())
        }
        return byDay.sorted { $0.key > $1.key }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.0) { day, meals in
                Section(day) {
                    ForEach(meals) { meal in
                        NavigationLink(destination: MealDetailView(meal: meal)) {
                            MealRowCompact(meal: meal)
                        }
                    }
                }
            }
        }
        .navigationTitle("Meal history")
        .searchable(text: $searchText, prompt: "Search meals")
    }
}

private struct MealRowCompact: View {
    let meal: MealEntry
    var body: some View {
        HStack {
            Image(systemName: meal.mealType.icon).foregroundStyle(NourishTheme.Color.primary).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.mealName).font(NourishTheme.Font.body()).lineLimit(1)
                Text(meal.loggedAt.formatted(.dateTime.hour().minute())).font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(meal.calories) kcal").font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
        }
    }
}

struct MealDetailView: View {
    let meal: MealEntry
    var body: some View {
        ScrollView {
            VStack(spacing: NourishTheme.Spacing.md) {
                if let data = meal.photoData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill().frame(height: 240).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.lg))
                }
                AnalysisResultView(
                    analysis: NutritionAnalysis(mealName: meal.mealName, calories: meal.calories,
                        protein: meal.protein, carbohydrates: meal.carbohydrates, fat: meal.fat,
                        fiber: meal.fiber, sugar: meal.sugar, sodium: meal.sodium,
                        vitamins: meal.vitamins, minerals: meal.minerals,
                        healthScore: meal.healthScore, insights: meal.aiInsights,
                        suggestions: meal.aiSuggestions, estimatedPortionSize: meal.estimatedPortionSize,
                        confidence: meal.confidence),
                    image: meal.photoData.flatMap { UIImage(data: $0) },
                    mealType: meal.mealType,
                    onSave: {}, onRetry: {}, onDiscard: {}
                )
            }
            .padding(NourishTheme.Spacing.md)
        }
        .navigationTitle(meal.mealName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
