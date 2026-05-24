// NourishAI — MealLogView.swift
import SwiftUI
import PhotosUI
import SwiftData
internal import Combine

struct MealLogView: View {

    @Bindable var user: User
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: MealLogViewModel

    init(user: User, context: ModelContext) {
        self.user = user
        _vm = StateObject(wrappedValue: MealLogViewModel(user: user, context: context))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NourishTheme.Spacing.lg) {
                    mealTypePicker
                    switch vm.state {
                    case .idle:
                        savedMealsSection
                        frequentMealsSection
                        photoInputSection
                    case .loadingCamera:
                        LoadingCard(message: "Loading photo…")
                    case .analyzing:
                        AnalyzingView()
                    case .result(let a):
                        AnalysisResultView(analysis: a, image: vm.capturedImage, mealType: vm.selectedMealType,
                            onSave: { vm.saveMeal(a); dismiss() },
                            onRetry: { Task { await vm.retryAnalysis() } },
                            onDiscard: { vm.reset() })
                    case .barcodeResult(let product):
                        BarcodeProductView(
                            product: product,
                            mealType: vm.selectedMealType,
                            allergenWarnings: AllergenChecker.detect(in: product.name, against: user.allergies)
                        ) { grams in
                            vm.saveBarcodeMeal(product: product, grams: grams)
                            dismiss()
                        } onDiscard: { vm.reset() }
                    case .error(let msg):
                        ErrorBanner(message: msg, retry: { Task { await vm.retryAnalysis() } })
                    }
                }
                .padding(NourishTheme.Spacing.md)
            }
            .background(NourishTheme.Color.background)
            .navigationTitle("Log meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Manual entry") { vm.showingManualEntry = true }
                        .font(NourishTheme.Font.caption())
                }
            }
            .sheet(isPresented: $vm.showingCamera) {
                CameraView { image in
                    vm.showingCamera = false
                    Task { await vm.handleCapturedImage(image) }
                }
            }
            .sheet(isPresented: $vm.showingManualEntry) {
                ManualMealEntryView(mealType: vm.selectedMealType, prefillName: vm.voicePrefill) { name, cal, prot, carbs, fat in
                    vm.saveManualMeal(name: name, calories: cal, protein: prot, carbs: carbs, fat: fat)
                    vm.voicePrefill = ""
                    dismiss()
                }
                .onDisappear { vm.voicePrefill = "" }
            }
            .sheet(isPresented: $vm.showingVoiceInput) {
                VoiceMealInputView { text in
                    vm.voicePrefill = text
                    vm.showingVoiceInput = false
                    vm.showingManualEntry = true
                }
            }
            .fullScreenCover(isPresented: $vm.showingBarcodeScanner) {
                BarcodeScannerView(
                    onScan: { code in Task { await vm.handleBarcode(code) } },
                    onCancel: { vm.showingBarcodeScanner = false }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $vm.showingFoodSearch) {
                FoodSearchView(mealType: vm.selectedMealType, allergies: user.allergies) { product in
                    vm.showingFoodSearch = false
                    vm.state = .barcodeResult(product)
                }
            }
            .sheet(isPresented: $vm.showingRecipeGenerator) {
                RecipeGeneratorView(user: user, mealType: vm.selectedMealType) { recipe in
                    vm.saveRecipeMeal(recipe)
                    dismiss()
                }
            }
            .sheet(isPresented: $vm.showingLabelScanner) {
                NutritionLabelScannerView(mealType: vm.selectedMealType) { result in
                    vm.saveLabelMeal(result)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sections

    private var mealTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MealType.allCases, id: \.self) { type in
                    Button {
                        HapticService.selection()
                        withAnimation(NourishTheme.Animation.snappy) { vm.selectedMealType = type }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon).font(.system(size: 14))
                            Text(type.localizedName).font(NourishTheme.Font.caption())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(vm.selectedMealType == type ? NourishTheme.Color.primary : NourishTheme.Color.surface)
                        .foregroundStyle(vm.selectedMealType == type ? .white : .primary)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var frequentMealsSection: some View {
        if !vm.frequentMeals.isEmpty {
            VStack(alignment: .leading, spacing: NourishTheme.Spacing.sm) {
                Label("Quick re-log", systemImage: "arrow.clockwise")
                    .font(NourishTheme.Font.headline())
                    .foregroundStyle(NourishTheme.Color.primary)
                ForEach(vm.frequentMeals) { meal in
                    Button {
                        HapticService.impact(.light)
                        vm.logAgain(meal)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(NourishTheme.Color.primaryLight)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: meal.mealType.icon)
                                        .foregroundStyle(NourishTheme.Color.primary)
                                        .font(.system(size: 13))
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.mealName)
                                    .font(NourishTheme.Font.body(14))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("\(meal.calories) kcal · \(Int(meal.protein))g protein")
                                    .font(NourishTheme.Font.caption(11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(NourishTheme.Color.primary)
                                .font(.system(size: 20))
                        }
                        .padding(.vertical, 6)
                    }
                    .accessibilityLabel("Re-log \(meal.mealName), \(meal.calories) calories")
                    if meal.id != vm.frequentMeals.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .padding()
            .nourishCard()
        }
    }

    @ViewBuilder
    private var savedMealsSection: some View {
        if !vm.savedMeals.isEmpty {
            VStack(alignment: .leading, spacing: NourishTheme.Spacing.sm) {
                Label("Saved meals", systemImage: "star.fill")
                    .font(NourishTheme.Font.headline())
                    .foregroundStyle(NourishTheme.Color.accent)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.savedMeals) { meal in
                            SavedMealChip(meal: meal) {
                                vm.logAgain(meal)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .padding()
            .nourishCard()
        }
    }

    private var photoInputSection: some View {
        VStack(spacing: NourishTheme.Spacing.md) {
            // Camera button
            Button {
                vm.showingCamera = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(NourishTheme.Color.primary)
                    Text("Take a photo")
                        .font(NourishTheme.Font.headline())
                    Text("Point at your meal for instant nutrition analysis")
                        .font(NourishTheme.Font.body(13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(NourishTheme.Color.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: NourishTheme.Radius.lg).stroke(NourishTheme.Color.primary.opacity(0.3), lineWidth: 1.5))
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $vm.selectedPhoto, matching: .images) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .font(NourishTheme.Font.headline())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NourishButtonStyle(isPrimary: false))
                .onChange(of: vm.selectedPhoto) { _, new in
                    Task { await vm.handlePhotoSelection(new) }
                }

                Button {
                    vm.showingBarcodeScanner = true
                } label: {
                    Label("Barcode", systemImage: "barcode.viewfinder")
                        .font(NourishTheme.Font.headline())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NourishButtonStyle(isPrimary: false))
            }

            HStack(spacing: 10) {
                Button {
                    HapticService.selection()
                    vm.showingFoodSearch = true
                } label: {
                    Label("Search food", systemImage: "magnifyingglass")
                        .font(NourishTheme.Font.headline())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NourishButtonStyle(isPrimary: false))

                Button {
                    HapticService.selection()
                    vm.showingRecipeGenerator = true
                } label: {
                    Label("Recipe AI", systemImage: "frying.pan.fill")
                        .font(NourishTheme.Font.headline())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NourishButtonStyle(isPrimary: false))
            }

            HStack(spacing: 10) {
                Button {
                    HapticService.selection()
                    vm.showingVoiceInput = true
                } label: {
                    Label("Voice log", systemImage: "mic.fill")
                        .font(NourishTheme.Font.headline())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NourishButtonStyle(isPrimary: false))

                Button {
                    HapticService.selection()
                    vm.showingLabelScanner = true
                } label: {
                    Label("Scan label", systemImage: "doc.viewfinder")
                        .font(NourishTheme.Font.headline())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NourishButtonStyle(isPrimary: false))
            }

            if user.subscriptionTier == .free {
                HStack {
                    Image(systemName: "info.circle").foregroundStyle(.secondary).font(.caption)
                    Text("\(user.remainingFreeAnalyses) free analyses remaining today")
                        .font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Analyzing view

struct AnalyzingView: View {
    @State private var dots = ""
    let messages = ["Identifying ingredients…", "Estimating portions…", "Calculating macros…", "Generating insights…"]
    @State private var messageIndex = 0
    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.4).tint(NourishTheme.Color.primary)
            Text(messages[messageIndex])
                .font(NourishTheme.Font.headline())
                .foregroundStyle(NourishTheme.Color.primary)
                .animation(NourishTheme.Animation.smooth, value: messageIndex)
            Text("Claude is analysing your meal")
                .font(NourishTheme.Font.body(13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .nourishCard()
        .onReceive(timer) { _ in
            messageIndex = (messageIndex + 1) % messages.count
        }
    }
}

// MARK: - Analysis result

struct AnalysisResultView: View {
    let analysis: NutritionAnalysis
    let image: UIImage?
    let mealType: MealType
    let onSave: () -> Void
    let onRetry: () -> Void
    let onDiscard: () -> Void

    // Editable overrides — populated when confidence is low
    @State private var overrideCalories: String = ""
    @State private var overrideProtein: String = ""
    @State private var overrideCarbs: String = ""
    @State private var overrideFat: String = ""
    @State private var showingOverride = false

    private var isLowConfidence: Bool { analysis.confidence < 0.75 }

    var body: some View {
        VStack(spacing: NourishTheme.Spacing.md) {
            // Photo preview
            if let image {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(height: 200).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.lg))
            }

            // Low-confidence warning banner
            if isLowConfidence {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Low confidence (\(Int(analysis.confidence * 100))%)")
                            .font(NourishTheme.Font.headline(13))
                            .foregroundStyle(.orange)
                        Text("The image may be unclear. Review the values before saving.")
                            .font(NourishTheme.Font.caption(12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit") {
                        overrideCalories = "\(analysis.calories)"
                        overrideProtein  = String(format: "%.1f", analysis.protein)
                        overrideCarbs    = String(format: "%.1f", analysis.carbohydrates)
                        overrideFat      = String(format: "%.1f", analysis.fat)
                        withAnimation(NourishTheme.Animation.snappy) { showingOverride.toggle() }
                    }
                    .font(NourishTheme.Font.caption())
                    .foregroundStyle(.orange)
                }
                .padding(12)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
            }

            // Inline macro override editor
            if showingOverride {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Adjust values")
                        .font(NourishTheme.Font.headline(14))
                    HStack(spacing: 10) {
                        overrideField(label: "Calories", binding: $overrideCalories, unit: "kcal")
                        overrideField(label: "Protein", binding: $overrideProtein, unit: "g")
                        overrideField(label: "Carbs", binding: $overrideCarbs, unit: "g")
                        overrideField(label: "Fat", binding: $overrideFat, unit: "g")
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Meal name + health score
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.mealName)
                        .font(NourishTheme.Font.headline(20))
                    Text("\(analysis.estimatedPortionSize) · \(mealType.localizedName)")
                        .font(NourishTheme.Font.caption())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HealthScoreBadge(score: analysis.healthScore, size: 52)
            }
            .padding()
            .nourishCard()

            // Calories + macros
            VStack(spacing: 12) {
                HStack {
                    Text("Nutrition").font(NourishTheme.Font.headline())
                    Spacer()
                    Text("\(showingOverride ? (Int(overrideCalories) ?? analysis.calories) : analysis.calories) kcal")
                        .font(NourishTheme.Font.numeric)
                        .foregroundStyle(isLowConfidence ? .orange : NourishTheme.Color.primary)
                }
                let p = showingOverride ? (Double(overrideProtein) ?? analysis.protein) : analysis.protein
                let c = showingOverride ? (Double(overrideCarbs) ?? analysis.carbohydrates) : analysis.carbohydrates
                let f = showingOverride ? (Double(overrideFat) ?? analysis.fat) : analysis.fat
                MacroPillsView(protein: p, carbs: c, fat: f, fiber: analysis.fiber)
                Divider()
                HStack {
                    NutrientRow(label: "Sugar", value: "\(String(format: "%.1f", analysis.sugar))g")
                    Spacer()
                    NutrientRow(label: "Sodium", value: "\(Int(analysis.sodium))mg")
                    Spacer()
                    NutrientRow(label: "Confidence", value: "\(Int(analysis.confidence * 100))%")
                }
            }
            .padding()
            .nourishCard()

            // AI Insights
            if !analysis.insights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Insights", systemImage: "lightbulb.fill")
                        .font(NourishTheme.Font.headline())
                        .foregroundStyle(NourishTheme.Color.primary)
                    ForEach(analysis.insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(NourishTheme.Color.primary).font(.caption)
                            Text(insight).font(NourishTheme.Font.body(14))
                        }
                    }
                }
                .padding()
                .nourishCard()
            }

            // Suggestions
            if !analysis.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Tips", systemImage: "arrow.up.heart.fill")
                        .font(NourishTheme.Font.headline())
                        .foregroundStyle(.orange)
                    ForEach(analysis.suggestions, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right.circle").foregroundStyle(.orange).font(.caption)
                            Text(tip).font(NourishTheme.Font.body(14))
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.lg))
            }

            // Actions
            VStack(spacing: 10) {
                Button("Save meal", action: onSave)
                    .buttonStyle(NourishButtonStyle())
                HStack(spacing: 12) {
                    Button("Retake photo", action: onRetry)
                        .buttonStyle(NourishButtonStyle(isPrimary: false))
                    Button("Discard", action: onDiscard)
                        .buttonStyle(NourishButtonStyle(isPrimary: false))
                }
            }
        }
        .onAppear {
            if isLowConfidence {
                overrideCalories = "\(analysis.calories)"
                overrideProtein  = String(format: "%.1f", analysis.protein)
                overrideCarbs    = String(format: "%.1f", analysis.carbohydrates)
                overrideFat      = String(format: "%.1f", analysis.fat)
                showingOverride  = true
            }
        }
    }

    private func overrideField(label: String, binding: Binding<String>, unit: String) -> some View {
        VStack(spacing: 4) {
            TextField("", text: binding)
                .keyboardType(.decimalPad)
                .font(NourishTheme.Font.headline(14))
                .multilineTextAlignment(.center)
                .padding(6)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text("\(label)\n(\(unit))")
                .font(NourishTheme.Font.caption(10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct NutrientRow: View {
    let label: String; let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(NourishTheme.Font.headline(14))
            Text(label).font(NourishTheme.Font.caption(11)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Barcode product view

struct BarcodeProductView: View {
    let product: FoodProduct
    let mealType: MealType
    var allergenWarnings: [String] = []
    let onSave: (Double) -> Void
    let onDiscard: () -> Void

    @State private var grams: Double

    init(product: FoodProduct, mealType: MealType, allergenWarnings: [String] = [],
         onSave: @escaping (Double) -> Void, onDiscard: @escaping () -> Void) {
        self.product = product
        self.mealType = mealType
        self.allergenWarnings = allergenWarnings
        self.onSave = onSave
        self.onDiscard = onDiscard
        _grams = State(initialValue: product.defaultServingG)
    }

    private var scaled: ScaledProduct { product.scaled(toGrams: grams) }
    private let quickGrams: [Double] = [50, 100, 150, 200]

    var body: some View {
        VStack(spacing: NourishTheme.Spacing.md) {
            if !allergenWarnings.isEmpty {
                allergenBanner
            }
            productHeader
            servingSection
            nutritionSection
            actionButtons
        }
    }

    private var allergenBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 4) {
                Text("Allergen warning")
                    .font(NourishTheme.Font.headline(14))
                    .foregroundStyle(.red)
                Text("Contains: \(allergenWarnings.joined(separator: ", "))")
                    .font(NourishTheme.Font.body(13))
                    .foregroundStyle(.red.opacity(0.85))
            }
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: NourishTheme.Radius.md).stroke(Color.red.opacity(0.3), lineWidth: 1))
    }

    private var productHeader: some View {
        VStack(spacing: 6) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 30))
                .foregroundStyle(NourishTheme.Color.primary)
            Text(product.name)
                .font(NourishTheme.Font.headline(20))
                .multilineTextAlignment(.center)
            Label("Open Food Facts", systemImage: "checkmark.seal.fill")
                .font(NourishTheme.Font.caption(11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .nourishCard()
    }

    private var servingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Serving size")
                    .font(NourishTheme.Font.headline())
                Spacer()
                Text("\(Int(grams)) g")
                    .font(NourishTheme.Font.headline())
                    .foregroundStyle(NourishTheme.Color.primary)
            }
            Slider(value: $grams, in: 10...500, step: 5)
                .tint(NourishTheme.Color.primary)
                .animation(NourishTheme.Animation.smooth, value: grams)
            HStack(spacing: 8) {
                ForEach(quickGrams, id: \.self) { g in
                    Button("\(Int(g))g") {
                        HapticService.selection()
                        withAnimation(NourishTheme.Animation.snappy) { grams = g }
                    }
                    .font(NourishTheme.Font.caption(11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(grams == g ? NourishTheme.Color.primary : NourishTheme.Color.primaryLight)
                    .foregroundStyle(grams == g ? .white : NourishTheme.Color.primary)
                    .clipShape(Capsule())
                }
                Spacer()
            }
        }
        .padding()
        .nourishCard()
    }

    private var nutritionSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Nutrition").font(NourishTheme.Font.headline())
                Spacer()
                Text("\(scaled.calories) kcal")
                    .font(NourishTheme.Font.numeric)
                    .foregroundStyle(NourishTheme.Color.primary)
            }
            MacroPillsView(protein: scaled.protein, carbs: scaled.carbs,
                           fat: scaled.fat, fiber: scaled.fiber)
            Divider()
            HStack {
                NutrientRow(label: "Sugar",  value: "\(String(format: "%.1f", scaled.sugar))g")
                Spacer()
                NutrientRow(label: "Sodium", value: "\(Int(scaled.sodiumMg))mg")
            }
        }
        .padding()
        .nourishCard()
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button("Add to log") { onSave(grams) }
                .buttonStyle(NourishButtonStyle())
            Button("Discard", action: onDiscard)
                .buttonStyle(NourishButtonStyle(isPrimary: false))
        }
    }
}

private struct SavedMealChip: View {
    let meal: MealEntry
    let onLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: meal.mealType.icon)
                    .font(.caption2)
                    .foregroundStyle(NourishTheme.Color.primary)
                Text(meal.mealName)
                    .font(NourishTheme.Font.caption(12))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            Text("\(meal.calories) kcal")
                .font(NourishTheme.Font.headline(13))
                .foregroundStyle(NourishTheme.Color.primary)
            Button(action: onLog) {
                Text("Log now")
                    .font(NourishTheme.Font.caption(11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(NourishTheme.Color.primary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(10)
        .frame(width: 130, alignment: .leading)
        .background(NourishTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: NourishTheme.Radius.md)
                .stroke(NourishTheme.Color.primaryLight, lineWidth: 1)
        )
    }
}
