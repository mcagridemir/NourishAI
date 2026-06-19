// Sana — CameraView.swift
import SwiftUI
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                onCapture(image)
            }
        }
    }
}

struct ManualMealEntryView: View {
    let mealType: MealType
    var prefillName: String = ""
    var nutritionContext: UserNutritionContext? = nil
    let onSave: (String, Int, Double, Double, Double) -> Void

    @Environment(\.dismiss) private var dismiss

    // AI Quick-Add
    @State private var quickDescription = ""
    @State private var isEstimating = false
    @State private var estimateError: String?
    @State private var showPaywall = false

    // Manual fields
    @State private var name = ""
    @State private var caloriesStr = ""
    @State private var proteinStr = ""
    @State private var carbsStr = ""
    @State private var fatStr = ""

    // Common portion quick-picks
    private let portionChips = ["1 glass", "1 bowl", "1 plate", "1 cup", "1 tbsp", "1 tsp", "1 handful", "1 piece"]

    var body: some View {
        NavigationStack {
            Form {

                // MARK: - AI Quick-Add
                Section {
                    TextField("e.g. 2 köfte, 1 glass of ayran, salad", text: $quickDescription, axis: .vertical)
                        .font(SanaTheme.Font.body())
                        .lineLimit(2...3)

                    // Portion chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(portionChips, id: \.self) { chip in
                                Button {
                                    quickDescription = quickDescription.isEmpty
                                        ? chip : "\(quickDescription), \(chip)"
                                } label: {
                                    Text(chip)
                                        .font(.system(size: 12, weight: .medium))
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(SanaTheme.Color.primaryLight)
                                        .foregroundStyle(SanaTheme.Color.primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    if let err = estimateError {
                        Text(err)
                            .font(SanaTheme.Font.caption(12))
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await estimateNutrition() }
                    } label: {
                        HStack(spacing: 6) {
                            if isEstimating {
                                ProgressView().scaleEffect(0.85)
                                Text("Estimating…")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Estimate with AI")
                            }
                        }
                        .font(SanaTheme.Font.headline())
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(.white)
                        .background(quickDescription.isEmpty || isEstimating
                            ? SanaTheme.Color.primary.opacity(0.4)
                            : SanaTheme.Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.xl))
                    }
                    .buttonStyle(.plain)
                    .disabled(quickDescription.isEmpty || isEstimating)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 8, trailing: 16))

                } header: {
                    Label("AI Quick Add", systemImage: "sparkles")
                } footer: {
                    Text("Describe portion in plain language — e.g. \"1 glass of milk\", \"2 tablespoons of olive oil\".")
                        .font(SanaTheme.Font.caption(12))
                }

                // MARK: - Manual entry
                Section("Or enter manually") {
                    TextField("Meal name", text: $name)
                        .font(SanaTheme.Font.body())
                }

                Section("Macros") {
                    macroRow(label: "Calories", value: $caloriesStr, unit: "kcal", keyboard: .numberPad)
                    macroRow(label: "Protein",  value: $proteinStr,  unit: "g",    keyboard: .decimalPad)
                    macroRow(label: "Carbs",    value: $carbsStr,    unit: "g",    keyboard: .decimalPad)
                    macroRow(label: "Fat",      value: $fatStr,      unit: "g",    keyboard: .decimalPad)
                }
            }
            .navigationTitle("Log meal")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if name.isEmpty { name = prefillName } }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let saveName = name.isEmpty ? quickDescription : name
                        onSave(saveName,
                               Int(caloriesStr) ?? 0,
                               Double(proteinStr) ?? 0,
                               Double(carbsStr) ?? 0,
                               Double(fatStr) ?? 0)
                        dismiss()
                    }
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(SanaTheme.Color.primary)
                    .disabled(name.isEmpty && quickDescription.isEmpty)
                }
            }
        }
    }

    // MARK: - AI estimation

    private func estimateNutrition() async {
        guard let ctx = nutritionContext, !quickDescription.isEmpty else { return }
        isEstimating = true
        estimateError = nil
        do {
            let analysis = try await ClaudeService.shared.analyzeTextMeal(
                description: quickDescription, context: ctx)
            name        = analysis.mealName
            caloriesStr = "\(analysis.calories)"
            proteinStr  = String(format: "%.1f", analysis.protein)
            carbsStr    = String(format: "%.1f", analysis.carbohydrates)
            fatStr      = String(format: "%.1f", analysis.fat)
        } catch ClaudeError.quotaExceeded {
            showPaywall = true
        } catch {
            estimateError = error.localizedDescription
        }
        isEstimating = false
    }

    // MARK: - Helpers

    private func macroRow(label: String, value: Binding<String>, unit: String, keyboard: UIKeyboardType) -> some View {
        HStack {
            Text(LocalizedStringKey(label))
                .font(SanaTheme.Font.body())
            Spacer()
            TextField("0", text: value)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
                .font(SanaTheme.Font.body())
            Text(unit)
                .font(SanaTheme.Font.caption())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
        }
    }
}
