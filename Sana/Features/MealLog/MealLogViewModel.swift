// Sana — MealLogViewModel.swift
import Foundation
import SwiftUI
import PhotosUI
import SwiftData
import StoreKit
internal import Combine

@MainActor
final class MealLogViewModel: ObservableObject {

    enum State {
        case idle, loadingCamera, analyzing
        case result(NutritionAnalysis)
        case barcodeResult(FoodProduct)
        case error(String)
    }

    @Published var state: State = .idle
    @Published var selectedPhoto: PhotosPickerItem?
    @Published var capturedImage: UIImage?
    @Published var selectedMealType: MealType = .snack
    @Published var showingCamera = false
    @Published var showingManualEntry = false
    @Published var showingBarcodeScanner = false
    @Published var showingFoodSearch = false
    @Published var showingRecipeGenerator = false
    @Published var showingVoiceInput = false
    @Published var voicePrefill: String = ""
    @Published var showingLabelScanner = false

    private let user: User
    private let context: ModelContext

    init(user: User, context: ModelContext) {
        self.user = user
        self.context = context
        self.selectedMealType = Self.inferMealType()
    }

    func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        state = .loadingCamera
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                state = .error("Could not load photo.")
                return
            }
            capturedImage = image
            await analyzeImage(image)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func handleCapturedImage(_ image: UIImage) async {
        capturedImage = image
        await analyzeImage(image)
    }

    func analyzeImage(_ image: UIImage) async {
        guard user.canAnalyzeMeal else {
            state = .error("You've reached your 5 free analyses today. Upgrade to Premium for unlimited.")
            return
        }
        state = .analyzing
        do {
            let analysis = try await ClaudeService.shared.analyzeMeal(
                image: image, mealType: selectedMealType, context: user.nutritionContext)
            state = .result(analysis)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func retryAnalysis() async {
        guard let image = capturedImage else { return }
        await analyzeImage(image)
    }

    func saveMeal(_ analysis: NutritionAnalysis) {
        HapticService.notification(.success)
        let entry = MealEntry(from: analysis, mealType: selectedMealType, photoData: capturedImage?.jpegData(compressionQuality: 0.6))
        entry.user = user
        user.mealEntries.append(entry)
        user.dailyAnalysisCount += 1
        Task { try? await HealthKitService.shared.logMeal(entry) }
        scheduleDeficiencyAlertsIfNeeded()
        refreshWidget()
        refreshLiveActivity()
        requestReviewIfEligible()
        reset()
    }

    func saveManualMeal(name: String, calories: Int, protein: Double, carbs: Double, fat: Double) {
        HapticService.notification(.success)
        let entry = MealEntry(manual: name, calories: calories, protein: protein, carbs: carbs, fat: fat, mealType: selectedMealType)
        entry.user = user
        user.mealEntries.append(entry)
        scheduleDeficiencyAlertsIfNeeded()
        refreshWidget()
        refreshLiveActivity()
        requestReviewIfEligible()
        reset()
    }

    func saveLabelMeal(_ result: LabelScanResult) {
        HapticService.notification(.success)
        let scaledCal  = Int(Double(result.calories) * result.servingsUsed)
        let scaledProt = result.protein * result.servingsUsed
        let scaledCarb = result.carbohydrates * result.servingsUsed
        let scaledFat  = result.fat * result.servingsUsed
        let scaledFib  = result.fiber * result.servingsUsed
        let entry = MealEntry(manual: result.mealName,
                              calories: scaledCal, protein: scaledProt,
                              carbs: scaledCarb, fat: scaledFat,
                              mealType: selectedMealType)
        entry.fiber = scaledFib
        entry.confidence = result.confidence
        entry.logSource = "label"
        entry.user = user
        user.mealEntries.append(entry)
        scheduleDeficiencyAlertsIfNeeded()
        refreshWidget()
        refreshLiveActivity()
        requestReviewIfEligible()
        reset()
    }

    func handleBarcode(_ code: String) async {
        showingBarcodeScanner = false
        state = .analyzing
        do {
            let product = try await BarcodeService.shared.fetchProduct(barcode: code)
            state = .barcodeResult(product)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func saveBarcodeMeal(product: FoodProduct, grams: Double) {
        HapticService.notification(.success)
        let scaled = product.scaled(toGrams: grams)
        let entry = MealEntry(barcode: scaled, mealType: selectedMealType)
        entry.user = user
        user.mealEntries.append(entry)
        user.dailyAnalysisCount += 1
        Task { try? await HealthKitService.shared.logMeal(entry) }
        scheduleDeficiencyAlertsIfNeeded()
        refreshWidget()
        refreshLiveActivity()
        requestReviewIfEligible()
        reset()
    }

    private func refreshWidget() {
        WidgetDataStore.save(user.widgetData)
    }

    private func refreshLiveActivity() {
        LiveActivityService.shared.startOrUpdate(user: user)
    }

    private func scheduleDeficiencyAlertsIfNeeded() {
        let deficiencies = user.detectedDeficiencies
        guard !deficiencies.isEmpty else { return }
        for nutrient in deficiencies {
            NotificationService.shared.sendDeficiencyAlert(nutrient: nutrient)
        }
    }

    var savedMeals: [MealEntry] {
        Array(
            user.mealEntries
                .filter { $0.isFavourite }
                .sorted { $0.mealName < $1.mealName }
                .prefix(12)
        )
    }

    /// Top-5 most-logged meals by name (excluding today, past 30 days), one representative entry each.
    var frequentMeals: [MealEntry] {
        let cutoff = Date().addingTimeInterval(-30 * 86400)
        let recent = user.mealEntries.filter { $0.loggedAt > cutoff && !Calendar.current.isDateInToday($0.loggedAt) }
        let grouped = Dictionary(grouping: recent) { $0.mealName.lowercased() }
        return grouped
            .sorted { $0.value.count > $1.value.count }
            .prefix(5)
            .compactMap { $0.value.max(by: { $0.loggedAt < $1.loggedAt }) }
    }

    func logAgain(_ meal: MealEntry) {
        HapticService.notification(.success)
        let entry = MealEntry(relogging: meal, mealType: selectedMealType)
        entry.user = user
        user.mealEntries.append(entry)
        Task { try? await HealthKitService.shared.logMeal(entry) }
        scheduleDeficiencyAlertsIfNeeded()
        refreshWidget()
        refreshLiveActivity()
        requestReviewIfEligible()
    }

    func saveRecipeMeal(_ recipe: RecipeResult) {
        HapticService.notification(.success)
        let entry = MealEntry(manual: recipe.name,
                              calories: recipe.caloriesPerServing,
                              protein: recipe.protein,
                              carbs: recipe.carbohydrates,
                              fat: recipe.fat,
                              mealType: selectedMealType)
        entry.fiber = recipe.fiber
        entry.healthScore = recipe.healthScore
        entry.aiInsights = recipe.tips
        entry.logSource = "recipe"
        entry.user = user
        user.mealEntries.append(entry)
        Task { try? await HealthKitService.shared.logMeal(entry) }
        scheduleDeficiencyAlertsIfNeeded()
        refreshWidget()
        refreshLiveActivity()
        requestReviewIfEligible()
    }

    private func requestReviewIfEligible() {
        let total = user.mealEntries.count
        guard total == 5 || total == 20 || total == 50 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    func reset() {
        state = .idle
        capturedImage = nil
        selectedPhoto = nil
    }

    private static func inferMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 6..<10: return .breakfast
        case 11..<14: return .lunch
        case 17..<21: return .dinner
        default: return .snack
        }
    }
}
