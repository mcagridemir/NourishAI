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
                    case .idle:          photoInputSection
                    case .loadingCamera: LoadingCard(message: "Loading photo…")
                    case .analyzing:     AnalyzingView()
                    case .result(let a): AnalysisResultView(analysis: a, image: vm.capturedImage, mealType: vm.selectedMealType, onSave: { vm.saveMeal(a); dismiss() }, onRetry: { Task { await vm.retryAnalysis() } }, onDiscard: { vm.reset() })
                    case .error(let msg): ErrorBanner(message: msg, retry: { Task { await vm.retryAnalysis() } })
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
                ManualMealEntryView(mealType: vm.selectedMealType) { name, cal, prot, carbs, fat in
                    vm.saveManualMeal(name: name, calories: cal, protein: prot, carbs: carbs, fat: fat)
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
                        withAnimation(NourishTheme.Animation.snappy) { vm.selectedMealType = type }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon).font(.system(size: 14))
                            Text(type.rawValue).font(NourishTheme.Font.caption())
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

            // Photo library
            PhotosPicker(selection: $vm.selectedPhoto, matching: .images) {
                Label("Choose from library", systemImage: "photo.on.rectangle")
                    .font(NourishTheme.Font.headline())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NourishButtonStyle(isPrimary: false))
            .onChange(of: vm.selectedPhoto) { _, new in
                Task { await vm.handlePhotoSelection(new) }
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

    var body: some View {
        VStack(spacing: NourishTheme.Spacing.md) {
            // Photo preview
            if let image {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(height: 200).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.lg))
            }

            // Meal name + health score
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.mealName)
                        .font(NourishTheme.Font.headline(20))
                    Text("\(analysis.estimatedPortionSize) · \(mealType.rawValue)")
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
                    Text("\(analysis.calories) kcal")
                        .font(NourishTheme.Font.numeric)
                        .foregroundStyle(NourishTheme.Color.primary)
                }
                MacroPillsView(protein: analysis.protein, carbs: analysis.carbohydrates, fat: analysis.fat, fiber: analysis.fiber)
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
