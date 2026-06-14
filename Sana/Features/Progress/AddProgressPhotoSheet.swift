// Sana — AddProgressPhotoSheet.swift
import SwiftUI
import PhotosUI
import SwiftData

struct AddProgressPhotoSheet: View {

    @Bindable var user: User
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var notes: String = ""
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var sourcePickerPresented = false

    private var currentWeightKg: Double { user.latestWeightKg }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SanaTheme.Spacing.lg) {
                    photoPickerSection
                    if selectedImage != nil {
                        notesSection
                        saveButton
                    }
                }
                .padding(SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Add Progress Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(SanaTheme.Color.primary)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView(image: $selectedImage)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Sections

    private var photoPickerSection: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            selectedImage = nil
                            selectedItem = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                                .padding(10)
                        }
                        .accessibilityLabel(Text("Remove photo"))
                    }
            } else {
                // Source picker
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: SanaTheme.Radius.lg)
                            .fill(SanaTheme.Color.surface)
                            .frame(height: 220)
                        VStack(spacing: 12) {
                            Image(systemName: "camera.on.rectangle.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(SanaTheme.Color.primary)
                            Text("Add a progress photo")
                                .font(SanaTheme.Font.headline())
                            Text("Track your body transformation over time")
                                .font(SanaTheme.Font.caption())
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }

                    HStack(spacing: 12) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera.fill")
                                .font(SanaTheme.Font.headline(14))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(SanaTheme.Color.surface)
                                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
                                .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.md)
                                    .stroke(SanaTheme.Color.hairline, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)

                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label("Library", systemImage: "photo.on.rectangle.angled")
                                .font(SanaTheme.Font.headline(14))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(SanaTheme.Color.surface)
                                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
                                .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.md)
                                    .stroke(SanaTheme.Color.hairline, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .onChange(of: selectedItem) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    selectedImage = image
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes (optional)")
                .font(SanaTheme.Font.caption())
                .foregroundStyle(.secondary)
            TextField("How are you feeling? Any observations...", text: $notes, axis: .vertical)
                .font(SanaTheme.Font.body())
                .lineLimit(3...5)
                .padding()
                .background(SanaTheme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
        }
    }

    private var saveButton: some View {
        Button {
            Task { await savePhoto() }
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark")
                    Text("Save photo")
                }
            }
        }
        .buttonStyle(NourishButtonStyle())
        .disabled(selectedImage == nil || isSaving)
    }

    // MARK: - Save

    private func savePhoto() async {
        guard let image = selectedImage else { return }
        isSaving = true
        defer { isSaving = false }

        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let fileName = "progress_\(UUID().uuidString).jpg"
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let fileURL = dir.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
        } catch {
            return
        }

        let photo = ProgressPhoto(relativePath: fileName, weightKg: currentWeightKg, notes: notes)
        photo.user = user
        context.insert(photo)
        HapticService.notification(.success)
        dismiss()
    }
}

// MARK: - Camera picker wrapper

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
