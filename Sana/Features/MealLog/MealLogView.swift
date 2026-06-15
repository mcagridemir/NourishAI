// Sana — MealLogView.swift
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
                VStack(spacing: SanaTheme.Spacing.lg) {
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
                            onSave: { effective in vm.saveMeal(effective); dismiss() },
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
                .padding(SanaTheme.Spacing.lg)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Log meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Manual entry") { vm.showingManualEntry = true }
                        .font(SanaTheme.Font.caption())
                }
            }
            .fullScreenCover(isPresented: $vm.showingCamera) {
                CameraView { image in
                    vm.showingCamera = false
                    Task { await vm.handleCapturedImage(image) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $vm.showingManualEntry) {
                ManualMealEntryView(
                    mealType: vm.selectedMealType,
                    prefillName: vm.voicePrefill,
                    nutritionContext: user.nutritionContext
                ) { name, cal, prot, carbs, fat in
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
                FoodSearchView(mealType: vm.selectedMealType, allergies: user.allergies) { product, grams in
                    vm.showingFoodSearch = false
                    vm.saveBarcodeMeal(product: product, grams: grams)
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
            .sheet(isPresented: $vm.showPaywall) {
                PaywallView()
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
                        withAnimation(SanaTheme.Animation.snappy) { vm.selectedMealType = type }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon).font(.system(size: 14))
                            Text(type.localizedName).font(SanaTheme.Font.caption())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(vm.selectedMealType == type ? SanaTheme.Color.primary : SanaTheme.Color.surface)
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
            VStack(alignment: .leading, spacing: SanaTheme.Spacing.sm) {
                Label("Quick re-log", systemImage: "arrow.clockwise")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(SanaTheme.Color.primary)
                ForEach(vm.frequentMeals) { meal in
                    Button {
                        HapticService.impact(.light)
                        vm.logAgain(meal)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(SanaTheme.Color.primaryLight)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: meal.mealType.icon)
                                        .foregroundStyle(SanaTheme.Color.primary)
                                        .font(.system(size: 13))
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.mealName)
                                    .font(SanaTheme.Font.body(14))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Text("\(meal.calories) kcal · \(Int(meal.protein))g protein")
                                    .font(SanaTheme.Font.caption(11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(SanaTheme.Color.primary)
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
            VStack(alignment: .leading, spacing: SanaTheme.Spacing.sm) {
                Label("Saved meals", systemImage: "star.fill")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(SanaTheme.Color.accent)
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
        VStack(spacing: SanaTheme.Spacing.md) {
            // Camera button
            Button {
                vm.showingCamera = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(SanaTheme.Color.primary)
                    Text("Take a photo")
                        .font(SanaTheme.Font.headline())
                    Text("Point at your meal for instant nutrition analysis")
                        .font(SanaTheme.Font.body(13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(SanaTheme.Color.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg).stroke(SanaTheme.Color.primary.opacity(0.3), lineWidth: 1.5))
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $vm.selectedPhoto, matching: .images) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .font(SanaTheme.Font.headline())
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
                        .font(SanaTheme.Font.headline())
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
                        .font(SanaTheme.Font.headline())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NourishButtonStyle(isPrimary: false))

                Button {
                    HapticService.selection()
                    vm.showingRecipeGenerator = true
                } label: {
                    Label("Recipe AI", systemImage: "frying.pan.fill")
                        .font(SanaTheme.Font.headline())
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
                        .font(SanaTheme.Font.headline())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NourishButtonStyle(isPrimary: false))

                Button {
                    HapticService.selection()
                    vm.showingLabelScanner = true
                } label: {
                    Label("Scan label", systemImage: "doc.viewfinder")
                        .font(SanaTheme.Font.headline())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NourishButtonStyle(isPrimary: false))
            }

            if user.subscriptionTier == .free {
                HStack {
                    Image(systemName: "info.circle").foregroundStyle(.secondary).font(.caption)
                    Text(String(format: NSLocalizedString("%d free analyses remaining today", comment: ""), user.remainingFreeAnalyses))
                        .font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Analyzing view (design spec: progress ring + step ticker)

struct AnalyzingView: View {
    @State private var progress: Double = 0
    @State private var stepIndex = 0
    private let steps = ["Detecting items", "Identifying portions", "Calculating macros", "Scoring meal quality"]
    private let ticker = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Progress ring with pulsing sparkle center
            ZStack {
                Circle()
                    .stroke(SanaTheme.Color.hairline, lineWidth: 6)
                    .frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: progress / 100)
                    .stroke(SanaTheme.Color.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 140, height: 140)
                    .animation(.linear(duration: 0.08), value: progress)
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(SanaTheme.Color.primaryLight)
                            .frame(width: 60, height: 60)
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(SanaTheme.Color.primary)
                    }
                    Text("\(Int(progress))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
            }

            Spacer().frame(height: 28)

            Text("Analyzing your meal")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .kerning(-0.5)
            Text("This usually takes 4–6 seconds")
                .font(SanaTheme.Font.body(13))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer().frame(height: 24)

            // Step ticker
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.0) { i, step in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(i < stepIndex
                                    ? SanaTheme.Color.primary
                                    : i == stepIndex
                                        ? SanaTheme.Color.primaryLight
                                        : SanaTheme.Color.hairline)
                                .frame(width: 22, height: 22)
                            if i < stepIndex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            } else if i == stepIndex {
                                Circle()
                                    .fill(SanaTheme.Color.primary)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        Text(step)
                            .font(SanaTheme.Font.body(14))
                            .fontWeight(i == stepIndex ? .semibold : .regular)
                            .foregroundStyle(i <= stepIndex ? .primary : .tertiary)
                    }
                    .animation(SanaTheme.Animation.smooth, value: stepIndex)
                }
            }
            .frame(maxWidth: 260, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .nourishCard()
        .onReceive(ticker) { _ in
            guard progress < 100 else { return }
            withAnimation(.linear(duration: 0.05)) {
                progress = min(100, progress + 1.5)
            }
            stepIndex = min(steps.count - 1, Int(progress / (100.0 / Double(steps.count))))
        }
    }
}

// MARK: - Analysis result

struct AnalysisResultView: View {
    let analysis: NutritionAnalysis
    let image: UIImage?
    let mealType: MealType
    let onSave: (_ effective: NutritionAnalysis) -> Void
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
        VStack(spacing: SanaTheme.Spacing.lg) {
            // Photo preview
            if let image {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(height: 200).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
            }

            // Low-confidence warning banner
            if isLowConfidence {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Low confidence (\(Int(analysis.confidence * 100))%)")
                            .font(SanaTheme.Font.headline(13))
                            .foregroundStyle(.orange)
                        Text("The image may be unclear. Review the values before saving.")
                            .font(SanaTheme.Font.caption(12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit") {
                        overrideCalories = "\(analysis.calories)"
                        overrideProtein  = String(format: "%.1f", analysis.protein)
                        overrideCarbs    = String(format: "%.1f", analysis.carbohydrates)
                        overrideFat      = String(format: "%.1f", analysis.fat)
                        withAnimation(SanaTheme.Animation.snappy) { showingOverride.toggle() }
                    }
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(.orange)
                }
                .padding(12)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
            }

            // Inline macro override editor
            if showingOverride {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Adjust values")
                        .font(SanaTheme.Font.headline(14))
                    HStack(spacing: 10) {
                        overrideField(label: "Calories", binding: $overrideCalories, unit: "kcal")
                        overrideField(label: "Protein", binding: $overrideProtein, unit: "g")
                        overrideField(label: "Carbs", binding: $overrideCarbs, unit: "g")
                        overrideField(label: "Fat", binding: $overrideFat, unit: "g")
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Meal name + health score
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.mealName)
                        .font(SanaTheme.Font.headline(20))
                    Text("\(analysis.estimatedPortionSize) · \(mealType.localizedName)")
                        .font(SanaTheme.Font.caption())
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
                    Text("Nutrition").font(SanaTheme.Font.headline())
                    Spacer()
                    Text("\(showingOverride ? (Int(overrideCalories) ?? analysis.calories) : analysis.calories) kcal")
                        .font(SanaTheme.Font.numeric)
                        .foregroundStyle(isLowConfidence ? .orange : SanaTheme.Color.primary)
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
                        .font(SanaTheme.Font.headline())
                        .foregroundStyle(SanaTheme.Color.primary)
                    ForEach(analysis.insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(SanaTheme.Color.primary).font(.caption)
                            Text(insight).font(SanaTheme.Font.body(14))
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
                        .font(SanaTheme.Font.headline())
                        .foregroundStyle(.orange)
                    ForEach(analysis.suggestions, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right.circle").foregroundStyle(.orange).font(.caption)
                            Text(tip).font(SanaTheme.Font.body(14))
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
            }

            // Actions
            VStack(spacing: 10) {
                Button("Save meal") { onSave(effectiveAnalysis) }
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

    /// Returns the analysis with any user-entered overrides applied.
    private var effectiveAnalysis: NutritionAnalysis {
        guard showingOverride else { return analysis }
        return NutritionAnalysis(
            mealName: analysis.mealName,
            calories: Int(overrideCalories) ?? analysis.calories,
            protein: Double(overrideProtein) ?? analysis.protein,
            carbohydrates: Double(overrideCarbs) ?? analysis.carbohydrates,
            fat: Double(overrideFat) ?? analysis.fat,
            fiber: analysis.fiber,
            sugar: analysis.sugar,
            sodium: analysis.sodium,
            vitamins: analysis.vitamins,
            minerals: analysis.minerals,
            healthScore: analysis.healthScore,
            insights: analysis.insights,
            suggestions: analysis.suggestions,
            estimatedPortionSize: analysis.estimatedPortionSize,
            confidence: analysis.confidence
        )
    }

    private func overrideField(label: String, binding: Binding<String>, unit: String) -> some View {
        VStack(spacing: 4) {
            TextField("", text: binding)
                .keyboardType(.decimalPad)
                .font(SanaTheme.Font.headline(14))
                .multilineTextAlignment(.center)
                .padding(6)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text("\(label)\n(\(unit))")
                .font(SanaTheme.Font.caption(10))
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
            Text(value).font(SanaTheme.Font.headline(14))
            Text(label).font(SanaTheme.Font.caption(11)).foregroundStyle(.secondary)
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
        VStack(spacing: SanaTheme.Spacing.lg) {
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
                    .font(SanaTheme.Font.headline(14))
                    .foregroundStyle(.red)
                Text(String(format: NSLocalizedString("Contains: %@", comment: ""), allergenWarnings.joined(separator: ", ")))
                    .font(SanaTheme.Font.body(13))
                    .foregroundStyle(.red.opacity(0.85))
            }
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.md).stroke(Color.red.opacity(0.3), lineWidth: 1))
    }

    private var productHeader: some View {
        VStack(spacing: 6) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 30))
                .foregroundStyle(SanaTheme.Color.primary)
            Text(product.name)
                .font(SanaTheme.Font.headline(20))
                .multilineTextAlignment(.center)
            Label("Open Food Facts", systemImage: "checkmark.seal.fill")
                .font(SanaTheme.Font.caption(11))
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
                    .font(SanaTheme.Font.headline())
                Spacer()
                Text("\(Int(grams)) g")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(SanaTheme.Color.primary)
            }
            Slider(value: $grams, in: 10...500, step: 5)
                .tint(SanaTheme.Color.primary)
                .animation(SanaTheme.Animation.smooth, value: grams)
            HStack(spacing: 8) {
                ForEach(quickGrams, id: \.self) { g in
                    Button("\(Int(g))g") {
                        HapticService.selection()
                        withAnimation(SanaTheme.Animation.snappy) { grams = g }
                    }
                    .font(SanaTheme.Font.caption(11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(grams == g ? SanaTheme.Color.primary : SanaTheme.Color.primaryLight)
                    .foregroundStyle(grams == g ? .white : SanaTheme.Color.primary)
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
                Text("Nutrition").font(SanaTheme.Font.headline())
                Spacer()
                Text("\(scaled.calories) kcal")
                    .font(SanaTheme.Font.numeric)
                    .foregroundStyle(SanaTheme.Color.primary)
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
                    .foregroundStyle(SanaTheme.Color.primary)
                Text(meal.mealName)
                    .font(SanaTheme.Font.caption(12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.primary)
            }
            Text("\(meal.calories) kcal")
                .font(SanaTheme.Font.headline(13))
                .foregroundStyle(SanaTheme.Color.primary)
            Button(action: onLog) {
                Text("Log now")
                    .font(SanaTheme.Font.caption(11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(SanaTheme.Color.primary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(10)
        .frame(width: 130, alignment: .leading)
        .background(SanaTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: SanaTheme.Radius.md)
                .stroke(SanaTheme.Color.primaryLight, lineWidth: 1)
        )
    }
}
