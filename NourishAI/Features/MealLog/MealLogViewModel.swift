// NourishAI — MealLogViewModel.swift
import Foundation
import SwiftUI
import PhotosUI
import SwiftData
internal import Combine

@MainActor
final class MealLogViewModel: ObservableObject {

    enum State {
        case idle, loadingCamera, analyzing, result(NutritionAnalysis), error(String)
    }

    @Published var state: State = .idle
    @Published var selectedPhoto: PhotosPickerItem?
    @Published var capturedImage: UIImage?
    @Published var selectedMealType: MealType = .snack
    @Published var showingCamera = false
    @Published var showingManualEntry = false

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
        let entry = MealEntry(from: analysis, mealType: selectedMealType, photoData: capturedImage?.jpegData(compressionQuality: 0.6))
        entry.user = user
        user.mealEntries.append(entry)
        user.dailyAnalysisCount += 1
        Task { try? await HealthKitService.shared.logMeal(entry) }
        reset()
    }

    func saveManualMeal(name: String, calories: Int, protein: Double, carbs: Double, fat: Double) {
        let entry = MealEntry(manual: name, calories: calories, protein: protein, carbs: carbs, fat: fat, mealType: selectedMealType)
        entry.user = user
        user.mealEntries.append(entry)
        reset()
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
