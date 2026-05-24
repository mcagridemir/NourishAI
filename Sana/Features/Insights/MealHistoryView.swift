// Sana — MealHistoryView.swift
import SwiftUI
import SwiftData

struct MealHistoryView: View {
    @Bindable var user: User
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .list
    @State private var activeFilter: MealFilter = .all
    @State private var editingMeal: MealEntry?

    enum ViewMode { case list, gallery }

    enum MealFilter: String, CaseIterable {
        case all = "All"
        case favourites = "Favourites"
        case highProtein = "High protein"
        case lowCalorie = "Low cal"
        case photo = "With photo"

        func matches(_ meal: MealEntry) -> Bool {
            switch self {
            case .all: return true
            case .favourites: return meal.isFavourite
            case .highProtein: return meal.protein >= 30
            case .lowCalorie: return meal.calories <= 400
            case .photo: return meal.photoData != nil
            }
        }
    }

    private var mealsWithPhotos: [MealEntry] {
        user.mealEntries
            .filter { $0.photoData != nil }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    private var filteredEntries: [MealEntry] {
        user.mealEntries
            .filter { meal in
                let matchSearch = searchText.isEmpty ||
                    meal.mealName.localizedCaseInsensitiveContains(searchText) ||
                    meal.mealType.rawValue.localizedCaseInsensitiveContains(searchText) ||
                    (searchText.lowercased() == "barcode" && meal.logSource == "barcode") ||
                    (searchText.lowercased() == "photo" && meal.photoData != nil)
                return matchSearch && activeFilter.matches(meal)
            }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    private var grouped: [(String, [MealEntry])] {
        let byDay = Dictionary(grouping: filteredEntries) {
            Calendar.current.startOfDay(for: $0.loggedAt).formatted(.dateTime.month().day().year())
        }
        return byDay.sorted { $0.key > $1.key }
    }

    var body: some View {
        Group {
            if viewMode == .list {
                VStack(spacing: 0) {
                    // Filter chips
                    filterChipsRow
                    List {
                        ForEach(grouped, id: \.0) { day, meals in
                            Section(day) {
                                ForEach(meals) { meal in
                                    NavigationLink(destination: MealDetailView(meal: meal)) {
                                        MealRowCompact(meal: meal)
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            HapticService.impact(.light)
                                            meal.isFavourite.toggle()
                                        } label: {
                                            Label(meal.isFavourite ? "Unsave" : "Save",
                                                  systemImage: meal.isFavourite ? "star.slash" : "star.fill")
                                        }
                                        .tint(SanaTheme.Color.accent)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            HapticService.selection()
                                            editingMeal = meal
                                        } label: {
                                            Label("Notes", systemImage: "square.and.pencil")
                                        }
                                        .tint(SanaTheme.Color.primary)
                                    }
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search meals, types…")
            } else {
                photoGallery
            }
        }
        .navigationTitle("Meal history")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Picker("View", selection: $viewMode) {
                    Image(systemName: "list.bullet").tag(ViewMode.list)
                    Image(systemName: "photo.on.rectangle").tag(ViewMode.gallery)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
            }
        }
        .sheet(item: $editingMeal) { meal in
            MealNotesSheet(meal: meal)
        }
    }

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MealFilter.allCases, id: \.self) { filter in
                    Button {
                        HapticService.selection()
                        withAnimation(SanaTheme.Animation.snappy) { activeFilter = filter }
                    } label: {
                        Text(filter.rawValue)
                            .font(SanaTheme.Font.caption(12))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(activeFilter == filter ? SanaTheme.Color.primary : SanaTheme.Color.surface)
                            .foregroundStyle(activeFilter == filter ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel("Filter: \(filter.rawValue)")
                }
            }
            .padding(.horizontal, SanaTheme.Spacing.md)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private var photoGallery: some View {
        ScrollView {
            if mealsWithPhotos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(SanaTheme.Color.primaryLight)
                    Text("No meal photos yet")
                        .font(SanaTheme.Font.headline())
                        .foregroundStyle(.secondary)
                    Text("Take a photo when logging meals to see them here")
                        .font(SanaTheme.Font.body(13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                    ForEach(mealsWithPhotos) { meal in
                        NavigationLink(destination: MealDetailView(meal: meal)) {
                            PhotoThumbnail(meal: meal)
                        }
                    }
                }
            }
        }
        .background(SanaTheme.Color.background)
    }
}

private struct PhotoThumbnail: View {
    let meal: MealEntry
    var body: some View {
        GeometryReader { geo in
            if let data = meal.photoData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.width)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        Text("\(meal.calories) kcal")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.5))
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct MealRowCompact: View {
    let meal: MealEntry
    var body: some View {
        HStack {
            Image(systemName: meal.mealType.icon).foregroundStyle(SanaTheme.Color.primary).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.mealName).font(SanaTheme.Font.body()).lineLimit(1)
                Text(meal.loggedAt.formatted(.dateTime.hour().minute())).font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(meal.calories) kcal").font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
        }
    }
}

struct MealDetailView: View {
    @Bindable var meal: MealEntry
    var body: some View {
        ScrollView {
            VStack(spacing: SanaTheme.Spacing.md) {
                if let data = meal.photoData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill().frame(height: 240).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
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
                    onSave: {effective in }, onRetry: {}, onDiscard: {}
                )
            }
            .padding(SanaTheme.Spacing.md)
        }
        .navigationTitle(meal.mealName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticService.impact(.light)
                    meal.isFavourite.toggle()
                } label: {
                    Image(systemName: meal.isFavourite ? "star.fill" : "star")
                        .foregroundStyle(SanaTheme.Color.accent)
                }
            }
        }
    }
}
