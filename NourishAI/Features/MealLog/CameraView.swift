// NourishAI — CameraView.swift
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
    let onSave: (String, Int, Double, Double, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var caloriesStr = ""
    @State private var proteinStr = ""
    @State private var carbsStr = ""
    @State private var fatStr = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal details") {
                    TextField("Meal name", text: $name)
                    TextField("Calories (kcal)", text: $caloriesStr).keyboardType(.numberPad)
                }
                Section("Macros") {
                    TextField("Protein (g)", text: $proteinStr).keyboardType(.decimalPad)
                    TextField("Carbohydrates (g)", text: $carbsStr).keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fatStr).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Manual entry")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if name.isEmpty { name = prefillName } }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(name, Int(caloriesStr) ?? 0, Double(proteinStr) ?? 0, Double(carbsStr) ?? 0, Double(fatStr) ?? 0)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
