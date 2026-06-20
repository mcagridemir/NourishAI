// Sana — ProgressPhotosView.swift
import SwiftUI
import SwiftData

struct ProgressPhotosView: View {

    @Bindable var user: User
    @State private var showingAdd = false
    @State private var selectedPhoto: ProgressPhoto?
    @State private var compareMode = false
    @State private var compareFirst: ProgressPhoto?
    @State private var compareSecond: ProgressPhoto?

    private var photos: [ProgressPhoto] {
        (user.progressPhotos ?? []).sorted { $0.takenAt > $1.takenAt }
    }

    private let columns = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]

    var body: some View {
        NavigationStack {
            Group {
                if photos.isEmpty {
                    emptyState
                } else {
                    photoGrid
                }
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if photos.count >= 2 {
                            Button {
                                compareMode.toggle()
                                compareFirst = nil
                                compareSecond = nil
                            } label: {
                                Image(systemName: compareMode ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle")
                                    .foregroundStyle(compareMode ? .orange : SanaTheme.Color.primary)
                            }
                            .accessibilityLabel(compareMode ? "Exit compare mode" : "Compare photos")
                        }
                        Button {
                            showingAdd = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(SanaTheme.Color.primary)
                        }
                        .accessibilityLabel("Add progress photo")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddProgressPhotoSheet(user: user)
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo, user: user)
            }
            .sheet(item: comparePhotoBinding) { _ in
                if let first = compareFirst, let second = compareSecond {
                    PhotoComparisonView(before: second, after: first, user: user)
                }
            }
            .overlay(alignment: .bottom) {
                if compareMode {
                    compareBar
                }
            }
        }
    }

    // MARK: - Photo grid

    private var photoGrid: some View {
        ScrollView {
            VStack(spacing: SanaTheme.Spacing.md) {
                progressSummaryBanner
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(photos) { photo in
                        photoCell(photo)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
            }
            .padding(SanaTheme.Spacing.md)
        }
    }

    private func photoCell(_ photo: ProgressPhoto) -> some View {
        let isSelected = compareFirst?.id == photo.id || compareSecond?.id == photo.id

        return Button {
            if compareMode {
                handleCompareSelection(photo)
            } else {
                selectedPhoto = photo
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                PhotoThumbnailView(url: photo.imageURL)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()

                VStack(alignment: .leading, spacing: 1) {
                    Text(photo.takenAt, style: .date)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                    if photo.weightKg > 0 {
                        Text(user.formatWeight(photo.weightKg))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(6)
                .background(.black.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)

                if compareMode && isSelected {
                    Color.black.opacity(0.3)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected && compareMode ? SanaTheme.Color.primary : Color.clear, lineWidth: 2)
            )
            .animation(SanaTheme.Animation.smooth, value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compare

    private var compareBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(compareMode ? "Compare mode" : "")
                    .font(SanaTheme.Font.headline(13))
                Text(compareFirst == nil ? "Tap first photo" : compareSecond == nil ? "Tap second photo" : "Ready!")
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if compareFirst != nil && compareSecond != nil {
                Button("Compare") {
                    comparePhotoTrigger = true
                }
                .buttonStyle(NourishButtonStyle())
                .frame(width: 110)
            }
        }
        .padding(.horizontal, SanaTheme.Spacing.lg)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.xl))
        .padding(.horizontal, SanaTheme.Spacing.md)
        .padding(.bottom, 20)
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
    }

    @State private var comparePhotoTrigger = false
    private var comparePhotoBinding: Binding<ProgressPhoto?> {
        Binding(
            get: { comparePhotoTrigger && compareFirst != nil && compareSecond != nil ? compareFirst : nil },
            set: { if $0 == nil { comparePhotoTrigger = false } }
        )
    }

    private func handleCompareSelection(_ photo: ProgressPhoto) {
        if compareFirst == nil {
            compareFirst = photo
        } else if compareSecond == nil && compareFirst?.id != photo.id {
            compareSecond = photo
        } else if compareFirst?.id == photo.id {
            compareFirst = compareSecond
            compareSecond = nil
        } else if compareSecond?.id == photo.id {
            compareSecond = nil
        }
    }

    // MARK: - Summary banner

    private var progressSummaryBanner: some View {
        Group {
            if photos.count >= 2, let first = photos.last, let latest = photos.first {
                let days = Calendar.current.dateComponents([.day], from: first.takenAt, to: latest.takenAt).day ?? 0
                let weightChange = latest.weightKg - first.weightKg

                HStack(spacing: 20) {
                    summaryCell(value: "\(photos.count)", label: "Photos")
                    Divider().frame(height: 36).opacity(0.15)
                    summaryCell(value: "\(days)d", label: "Journey")
                    if first.weightKg > 0 && latest.weightKg > 0 {
                        Divider().frame(height: 36).opacity(0.15)
                        summaryCell(
                            value: "\(weightChange < 0 ? "−" : "+")\(user.formatWeight(abs(weightChange)))",
                            label: "Weight change",
                            valueColor: weightChange < 0 ? SanaTheme.Color.primary : .orange
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(SanaTheme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg)
                    .stroke(SanaTheme.Color.hairline, lineWidth: 0.5))
            }
        }
    }

    private func summaryCell(value: String, label: String, valueColor: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
            Text(LocalizedStringKey(label))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(SanaTheme.Color.primaryLight)
                    .frame(width: 90, height: 90)
                Image(systemName: "camera.on.rectangle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(SanaTheme.Color.primary)
            }
            VStack(spacing: 8) {
                Text("Start your journey")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Track your physical progress with photos.\nSee how far you've come over time.")
                    .font(SanaTheme.Font.body(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            Button {
                showingAdd = true
            } label: {
                Label("Add first photo", systemImage: "plus")
            }
            .buttonStyle(NourishButtonStyle())
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SanaTheme.Spacing.xl)
    }
}

// MARK: - Photo thumbnail (lazy image loader)

struct PhotoThumbnailView: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 0)
                    .fill(SanaTheme.Color.surface)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(SanaTheme.Color.primary.opacity(0.3))
                    )
            }
        }
        .task(id: url) {
            guard let url, image == nil else { return }
            image = await Task.detached(priority: .utility) {
                UIImage(contentsOfFile: url.path)
            }.value
        }
    }
}

// MARK: - Photo detail

struct PhotoDetailView: View {
    let photo: ProgressPhoto
    @Bindable var user: User
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SanaTheme.Spacing.lg) {
                    PhotoThumbnailView(url: photo.imageURL)
                        .aspectRatio(4/5, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(photo.takenAt.formatted(date: .long, time: .omitted), systemImage: "calendar")
                                .font(SanaTheme.Font.body())
                            Spacer()
                            if photo.weightKg > 0 {
                                Label(user.formatWeight(photo.weightKg), systemImage: "scalemass")
                                    .font(SanaTheme.Font.body())
                                    .foregroundStyle(SanaTheme.Color.primary)
                            }
                        }
                        if !photo.notes.isEmpty {
                            Text(photo.notes)
                                .font(SanaTheme.Font.body(14))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                        }
                    }
                    .padding()
                    .nourishCard()
                }
                .padding(SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Progress Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(SanaTheme.Color.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .confirmationDialog("Delete this photo?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deletePhoto() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func deletePhoto() {
        if let url = photo.imageURL {
            try? FileManager.default.removeItem(at: url)
        }
        context.delete(photo)
        HapticService.impact(.medium)
        dismiss()
    }
}

// MARK: - Photo comparison

struct PhotoComparisonView: View {
    let before: ProgressPhoto
    let after: ProgressPhoto
    @Bindable var user: User
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    photoPane(photo: before, label: "Before")
                    photoPane(photo: after, label: "After")
                }
                .frame(maxHeight: .infinity)

                comparisonStats
                    .padding(SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(SanaTheme.Color.primary)
                }
            }
        }
    }

    private func photoPane(photo: ProgressPhoto, label: String) -> some View {
        ZStack(alignment: .bottom) {
            PhotoThumbnailView(url: photo.imageURL)
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            VStack(spacing: 2) {
                Text(LocalizedStringKey(label))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Text(photo.takenAt, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.45))
        }
    }

    private var comparisonStats: some View {
        let days = Calendar.current.dateComponents([.day], from: before.takenAt, to: after.takenAt).day ?? 0
        let weightChange = after.weightKg - before.weightKg

        return HStack(spacing: 0) {
            compStat(value: "\(days)", label: "Days")
            Divider().frame(height: 36).opacity(0.15)
            if before.weightKg > 0 && after.weightKg > 0 {
                compStat(
                    value: "\(weightChange < 0 ? "−" : "+")\(user.formatWeight(abs(weightChange)))",
                    label: "Weight",
                    color: weightChange < 0 ? SanaTheme.Color.primary : .orange
                )
                Divider().frame(height: 36).opacity(0.15)
            }
            compStat(value: user.formatWeight(before.weightKg), label: "Before")
            Divider().frame(height: 36).opacity(0.15)
            compStat(value: user.formatWeight(after.weightKg), label: "After")
        }
        .padding(.vertical, 14)
        .background(SanaTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg).stroke(SanaTheme.Color.hairline, lineWidth: 0.5))
    }

    private func compStat(value: String, label: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(LocalizedStringKey(label))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
