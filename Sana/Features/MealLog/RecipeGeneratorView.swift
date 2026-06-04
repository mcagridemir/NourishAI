// Sana — RecipeGeneratorView.swift
import SwiftUI
internal import Combine

struct RecipeGeneratorView: View {

    @Bindable var user: User
    @Environment(\.dismiss) private var dismiss
    let mealType: MealType
    let onSave: (RecipeResult) -> Void

    @State private var ingredientInput = ""
    @State private var ingredients: [String] = []
    @State private var isGenerating = false
    @State private var recipe: RecipeResult?
    @State private var errorMessage: String?
    @State private var messageIndex = 0
    @State private var servingMultiplier: Double = 1.0   // 0.5×, 1×, 1.5×, 2×
    @FocusState private var inputFocused: Bool

    private var scaledRecipe: RecipeResult? {
        guard var r = recipe, servingMultiplier != 1.0 else { return recipe }
        r.caloriesPerServing = Int(Double(r.caloriesPerServing) * servingMultiplier)
        r.protein        *= servingMultiplier
        r.carbohydrates  *= servingMultiplier
        r.fat            *= servingMultiplier
        r.fiber          *= servingMultiplier
        return r
    }

    private let generatingMessages = [
        "Analysing your ingredients…",
        "Balancing macros…",
        "Crafting the recipe…",
        "Adding finishing touches…"
    ]
    private let timer = Timer.publish(every: 1.6, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SanaTheme.Spacing.lg) {
                    if let recipe {
                        recipeResultView(recipe)
                    } else if isGenerating {
                        generatingView
                    } else {
                        inputSection
                        if let errorMessage {
                            ErrorBanner(message: errorMessage, retry: { Task { await generate() } })
                        }
                    }
                }
                .padding(SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Recipe generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                if recipe != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New recipe") {
                            self.recipe = nil
                            ingredients = []
                            ingredientInput = ""
                        }
                        .font(SanaTheme.Font.caption())
                        .foregroundStyle(SanaTheme.Color.primary)
                    }
                }
            }
            .onReceive(timer) { _ in
                if isGenerating {
                    messageIndex = (messageIndex + 1) % generatingMessages.count
                }
            }
        }
    }

    // MARK: - Input section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: SanaTheme.Spacing.md) {
            // Hero
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(SanaTheme.Color.primary.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "frying.pan.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(SanaTheme.Color.primary)
                }
                .shadow(color: SanaTheme.Color.primary.opacity(0.18), radius: 14, y: 6)
                Text("What's in your kitchen?")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .kerning(-0.5)
                Text("Add ingredients and Claude will craft a healthy recipe tailored to your goals.")
                    .font(SanaTheme.Font.body(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SanaTheme.Spacing.md)

            // Ingredient input
            VStack(alignment: .leading, spacing: 10) {
                Text("Ingredients").font(SanaTheme.Font.headline())

                HStack(spacing: 10) {
                    TextField("e.g. chicken, broccoli, oats…", text: $ingredientInput)
                        .font(SanaTheme.Font.body(14))
                        .submitLabel(.done)
                        .focused($inputFocused)
                        .onSubmit { addIngredient() }
                        .padding(12)
                        .background(SanaTheme.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))

                    Button(action: addIngredient) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(ingredientInput.trimmingCharacters(in: .whitespaces).isEmpty
                                             ? SanaTheme.Color.primary.opacity(0.25)
                                             : SanaTheme.Color.primary)
                    }
                    .disabled(ingredientInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                // Chips
                if !ingredients.isEmpty {
                    ChipFlowLayout(spacing: 8) {
                        ForEach(ingredients, id: \.self) { ingredient in
                            ingredientChip(ingredient)
                        }
                    }
                }
            }
            .padding()
            .nourishCard()

            // Quick-add suggestions
            if ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick add").font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                    ChipFlowLayout(spacing: 8) {
                        ForEach(suggestions, id: \.self) { s in
                            Button(s) {
                                HapticService.selection()
                                ingredients.append(s)
                            }
                            .font(SanaTheme.Font.caption(12))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(SanaTheme.Color.primaryLight)
                            .foregroundStyle(SanaTheme.Color.primary)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Generate button
            Button("Generate recipe") { Task { await generate() } }
                .buttonStyle(NourishButtonStyle())
                .disabled(ingredients.isEmpty)
                .opacity(ingredients.isEmpty ? 0.5 : 1)
        }
    }

    private func ingredientChip(_ name: String) -> some View {
        HStack(spacing: 4) {
            Text(name).font(SanaTheme.Font.caption(12))
            Button {
                HapticService.selection()
                ingredients.removeAll { $0 == name }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(SanaTheme.Color.primary.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(SanaTheme.Color.primaryLight)
        .foregroundStyle(SanaTheme.Color.primary)
        .clipShape(Capsule())
    }

    // MARK: - Generating view

    private var generatingView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)
            ProgressView().scaleEffect(1.4).tint(SanaTheme.Color.primary)
            Text(generatingMessages[messageIndex])
                .font(SanaTheme.Font.headline())
                .foregroundStyle(SanaTheme.Color.primary)
                .animation(SanaTheme.Animation.smooth, value: messageIndex)
            Text("Claude is creating your personalised recipe")
                .font(SanaTheme.Font.body(13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recipe result

    @ViewBuilder
    private func recipeResultView(_ recipe: RecipeResult) -> some View {
        // Header
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.name)
                        .font(SanaTheme.Font.headline(22))
                    Text(recipe.description)
                        .font(SanaTheme.Font.body(14))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HealthScoreBadge(score: recipe.healthScore, size: 52)
            }
            HStack(spacing: 16) {
                timeBadge(icon: "clock", label: "Prep", value: "\(recipe.prepTimeMinutes)m")
                timeBadge(icon: "flame", label: "Cook", value: "\(recipe.cookTimeMinutes)m")
                timeBadge(icon: "person.2", label: "Serves", value: "\(recipe.servings)")
            }
        }
        .padding()
        .nourishCard()

        // Serving scaler
        VStack(spacing: 10) {
            HStack {
                Text("Serving size").font(SanaTheme.Font.headline())
                Spacer()
                Text(servingMultiplier == 1 ? "1× (as generated)" :
                     servingMultiplier < 1 ? "½ serving" : "\(String(format: "%.1f", servingMultiplier))× serving")
                    .font(SanaTheme.Font.caption(12))
                    .foregroundStyle(SanaTheme.Color.primary)
            }
            HStack(spacing: 12) {
                ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { mult in
                    Button {
                        HapticService.selection()
                        withAnimation(SanaTheme.Animation.snappy) { servingMultiplier = mult }
                    } label: {
                        Text(mult == 0.5 ? "½×" : "\(Int(mult == 1.5 ? 1 : Int(mult)))×\(mult == 1.5 ? "½" : "")")
                            .font(SanaTheme.Font.caption(13))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(servingMultiplier == mult ? SanaTheme.Color.primary : SanaTheme.Color.surface)
                            .foregroundStyle(servingMultiplier == mult ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .nourishCard()

        // Nutrition (scaled)
        let display = scaledRecipe ?? recipe
        VStack(spacing: 12) {
            HStack {
                Text("Nutrition\(servingMultiplier != 1 ? " (×\(String(format: "%.1f", servingMultiplier)))" : " per serving")")
                    .font(SanaTheme.Font.headline())
                Spacer()
                Text("\(display.caloriesPerServing) kcal")
                    .font(SanaTheme.Font.numeric)
                    .foregroundStyle(SanaTheme.Color.primary)
            }
            MacroPillsView(protein: display.protein, carbs: display.carbohydrates,
                           fat: display.fat, fiber: display.fiber)
        }
        .padding()
        .nourishCard()

        // Ingredients
        VStack(alignment: .leading, spacing: 10) {
            Label("Ingredients", systemImage: "cart.fill")
                .font(SanaTheme.Font.headline())
                .foregroundStyle(SanaTheme.Color.primary)
            ForEach(recipe.ingredients, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(SanaTheme.Color.primary)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(item).font(SanaTheme.Font.body(14))
                }
            }
        }
        .padding()
        .nourishCard()

        // Instructions
        VStack(alignment: .leading, spacing: 12) {
            Label("Instructions", systemImage: "list.number")
                .font(SanaTheme.Font.headline())
                .foregroundStyle(SanaTheme.Color.primary)
            ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(idx + 1)")
                        .font(SanaTheme.Font.headline(13))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(SanaTheme.Color.primary)
                        .clipShape(Circle())
                    Text(step)
                        .font(SanaTheme.Font.body(14))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .nourishCard()

        // Tips
        if !recipe.tips.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Tips", systemImage: "lightbulb.fill")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(.orange)
                ForEach(recipe.tips, id: \.self) { tip in
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

        // Log button
        Button("Log this meal") {
            onSave(scaledRecipe ?? recipe)
        }
        .buttonStyle(NourishButtonStyle())
        .padding(.bottom, SanaTheme.Spacing.md)
    }

    private func timeBadge(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(SanaTheme.Color.primary)
            Text(value).font(SanaTheme.Font.headline(13))
            Text(label).font(SanaTheme.Font.caption(11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(SanaTheme.Color.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
    }

    // MARK: - Actions

    private func addIngredient() {
        let trimmed = ingredientInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !ingredients.contains(trimmed) else { return }
        HapticService.selection()
        ingredients.append(trimmed)
        ingredientInput = ""
    }

    private func generate() async {
        guard !ingredients.isEmpty else { return }
        inputFocused = false
        isGenerating = true
        errorMessage = nil
        do {
            let result = try await ClaudeService.shared.generateRecipe(
                ingredients: ingredients,
                context: user.nutritionContext
            )
            HapticService.notification(.success)
            recipe = result
        } catch {
            HapticService.notification(.error)
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }

    private var suggestions: [String] {
        ["Chicken breast", "Eggs", "Oats", "Broccoli", "Sweet potato",
         "Salmon", "Greek yogurt", "Spinach", "Quinoa", "Avocado"]
    }
}

// MARK: - Flow layout (wrapping chip layout)

private struct ChipFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}
