// Sana — FoodSearchView.swift
import SwiftUI

struct FoodSearchView: View {

    @Environment(\.dismiss) private var dismiss
    let mealType: MealType
    var allergies: [String] = []
    let onSelect: (FoodProduct) -> Void

    @State private var query = ""
    @State private var results: [FoodProduct] = []
    @State private var isSearching = false
    @State private var selectedProduct: FoodProduct?
    @State private var showingProductDetail = false
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            Group {
                if showingProductDetail, let product = selectedProduct {
                    ScrollView {
                        BarcodeProductView(
                            product: product,
                            mealType: mealType,
                            allergenWarnings: AllergenChecker.detect(in: product.name, against: allergies)
                        ) { grams in
                            onSelect(product)
                        } onDiscard: {
                            selectedProduct = nil
                            showingProductDetail = false
                        }
                        .padding(SanaTheme.Spacing.md)
                    }
                    .background(SanaTheme.Color.background)
                    .navigationTitle(product.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Back") {
                                selectedProduct = nil
                                showingProductDetail = false
                            }
                        }
                    }
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !showingProductDetail {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
        .task(id: query) {
            hasSearched = false
            guard query.count >= 2 else { results = []; return }
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            isSearching = true
            results = (try? await BarcodeService.shared.searchProducts(query: query)) ?? []
            isSearching = false
            hasSearched = true
        }
    }

    private var resultsList: some View {
        List {
            if isSearching {
                HStack {
                    Spacer()
                    ProgressView().tint(SanaTheme.Color.primary)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if query.count < 2 {
                searchPrompt
            } else if hasSearched && results.isEmpty {
                emptyState
            } else {
                ForEach(results, id: \.name) { product in
                    productRow(product)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "e.g. chicken breast, oat milk…")
    }

    private var searchPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(SanaTheme.Color.primary)
            Text("Type at least 2 characters to search\nthe Open Food Facts database")
                .font(SanaTheme.Font.body(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .listRowBackground(Color.clear)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(SanaTheme.Color.primary)
            Text(String(format: NSLocalizedString("No results for \"%@\"", comment: ""), query))
                .font(SanaTheme.Font.headline())
            Text("Try a different name or use the barcode scanner")
                .font(SanaTheme.Font.body(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .listRowBackground(Color.clear)
    }

    private func productRow(_ product: FoodProduct) -> some View {
        Button {
            HapticService.selection()
            selectedProduct = product
            showingProductDetail = true
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: SanaTheme.Radius.sm)
                    .fill(SanaTheme.Color.primaryLight)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .foregroundStyle(SanaTheme.Color.primary)
                            .font(.system(size: 16))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(SanaTheme.Font.body(14))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Label("\(Int(product.caloriesPer100g)) kcal", systemImage: "flame.fill")
                            .font(SanaTheme.Font.caption(11))
                            .foregroundStyle(.orange)
                        Text("per 100g")
                            .font(SanaTheme.Font.caption(11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(SanaTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
        }
        .buttonStyle(.plain)
    }
}
