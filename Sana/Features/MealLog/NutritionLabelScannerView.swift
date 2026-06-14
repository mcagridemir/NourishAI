// Sana — NutritionLabelScannerView.swift
// Photograph a nutrition facts panel → Claude extracts all macros automatically.
import SwiftUI
import PhotosUI

// MARK: - Result model

struct LabelScanResult {
    var mealName: String
    var servingSize: String
    var servingsPerContainer: Double
    var servingsUsed: Double = 1.0   // user can adjust
    var calories: Int
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var sodium: Double
    var confidence: Double
    var ingredients: [String] = []   // full ingredient list from label
}

// MARK: - Ingredient health classification

enum IngredientRisk: Int, Comparable {
    case none = 0, moderate = 1, high = 2
    static func < (l: IngredientRisk, r: IngredientRisk) -> Bool { l.rawValue < r.rawValue }
}

struct IngredientHealthEngine {

    // High concern — strong evidence of harm at typical consumption levels
    private static let highConcern: [String] = [
        "palm oil", "palm kernel oil",
        "partially hydrogenated", "hydrogenated vegetable",
        "high fructose corn syrup",
        "glucose-fructose syrup", "glucose fructose syrup",
        "trans fat"
    ]

    // Moderate concern — ultra-processed / may cause issues at excess
    private static let moderateConcern: [String] = [
        "glucose syrup", "corn syrup",
        "sodium nitrate", "sodium nitrite",
        "artificial flavour", "artificial flavor",
        "artificial colour", "artificial color",
        "carrageenan",
        "bha", "bht", "tbhq",
        "aspartame", "acesulfame", "saccharin", "sucralose",
        "sodium benzoate", "potassium sorbate",
        "potassium bromate", "brominated vegetable oil",
        "modified starch", "modified corn starch",
        "caramel colour", "caramel color"
    ]

    static func risk(for ingredient: String) -> IngredientRisk {
        let lower = ingredient.lowercased()
        if highConcern.contains(where: { lower.contains($0) }) { return .high }
        if moderateConcern.contains(where: { lower.contains($0) }) { return .moderate }
        return .none
    }

    static func overallRisk(of ingredients: [String]) -> IngredientRisk {
        ingredients.map { risk(for: $0) }.max() ?? .none
    }

    static func explanation(for ingredient: String) -> String? {
        let lower = ingredient.lowercased()
        if lower.contains("palm oil") || lower.contains("palm kernel") {
            return NSLocalizedString("High in saturated fat; linked to cardiovascular risk and environmental concerns.", comment: "")
        }
        if lower.contains("hydrogenated") {
            return NSLocalizedString("Contains trans fats, which raise LDL cholesterol.", comment: "")
        }
        if lower.contains("high fructose corn syrup") || lower.contains("glucose-fructose") || lower.contains("glucose fructose") {
            return NSLocalizedString("Rapidly spikes blood sugar; associated with obesity and metabolic syndrome.", comment: "")
        }
        if lower.contains("glucose syrup") || lower.contains("corn syrup") {
            return NSLocalizedString("Concentrated sugar source; contributes to excess calorie intake.", comment: "")
        }
        if lower.contains("sodium nitrate") || lower.contains("sodium nitrite") {
            return NSLocalizedString("Preservatives in processed meats linked to increased cancer risk.", comment: "")
        }
        if lower.contains("carrageenan") {
            return NSLocalizedString("Controversial additive; may cause digestive inflammation in some people.", comment: "")
        }
        if lower.contains("bha") || lower.contains("bht") || lower.contains("tbhq") {
            return NSLocalizedString("Synthetic antioxidant preservatives; possible carcinogen at high doses.", comment: "")
        }
        if lower.contains("artificial") {
            return NSLocalizedString("Synthetic flavour/colour with no nutritional benefit.", comment: "")
        }
        if lower.contains("aspartame") || lower.contains("acesulfame") || lower.contains("saccharin") {
            return NSLocalizedString("Artificial sweetener; some studies link them to altered gut microbiome.", comment: "")
        }
        return nil
    }
}

// MARK: - View

struct NutritionLabelScannerView: View {
    let mealType: MealType
    let onSave: (LabelScanResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var photo: PhotosPickerItem?
    @State private var state: ScanState = .idle
    @State private var showingCamera = false
    @State private var showPaywall = false

    enum ScanState: Equatable {
        case idle
        case analyzing
        case result(LabelScanResult)
        case error(String)

        static func == (lhs: ScanState, rhs: ScanState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.analyzing, .analyzing): return true
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SanaTheme.Spacing.lg) {
                    switch state {
                    case .idle:
                        idleContent
                    case .analyzing:
                        analyzingContent
                    case .result(let result):
                        ResultView(result: result, mealType: mealType, onSave: onSave, onRescan: { state = .idle })
                    case .error(let msg):
                        errorContent(msg)
                    }
                }
                .padding(SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Nutrition Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView { image in
                    showingCamera = false
                    Task { await analyze(image: image) }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    // MARK: - Idle

    private var idleContent: some View {
        VStack(spacing: SanaTheme.Spacing.lg) {
            // Hero
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: SanaTheme.Radius.lg)
                        .fill(SanaTheme.Color.primaryLight)
                        .frame(height: 180)
                    VStack(spacing: 12) {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 52))
                            .foregroundStyle(SanaTheme.Color.primary)
                        Text("Point at a Nutrition Facts label")
                            .font(SanaTheme.Font.headline())
                            .multilineTextAlignment(.center)
                        Text("Claude reads the entire panel in seconds")
                            .font(SanaTheme.Font.body(13))
                            .foregroundStyle(.secondary)
                    }
                }

                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    tipRow(icon: "light.max", text: "Good lighting improves accuracy")
                    tipRow(icon: "camera.viewfinder", text: "Include the full label in frame")
                    tipRow(icon: "hand.raised.fill", text: "Hold steady for sharpest scan")
                }
                .padding()
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
            }

            // Buttons
            Button {
                showingCamera = true
            } label: {
                Label("Scan label with camera", systemImage: "camera.fill")
                    .font(SanaTheme.Font.headline())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NourishButtonStyle())

            PhotosPicker(selection: $photo, matching: .images) {
                Label("Choose from photo library", systemImage: "photo.on.rectangle")
                    .font(SanaTheme.Font.headline())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NourishButtonStyle(isPrimary: false))
            .onChange(of: photo) { _, newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    await analyze(image: image)
                }
            }
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(SanaTheme.Color.primary)
                .frame(width: 20)
            Text(text)
                .font(SanaTheme.Font.body(14))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Analyzing

    private var analyzingContent: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)
            ProgressView()
                .scaleEffect(1.5)
            VStack(spacing: 8) {
                Text("Reading nutrition label…")
                    .font(SanaTheme.Font.headline())
                Text("Claude is extracting macros, serving sizes, and ingredient list")
                    .font(SanaTheme.Font.body(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 60)
        }
    }

    // MARK: - Error

    private func errorContent(_ msg: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Couldn't read label")
                .font(SanaTheme.Font.headline())
            Text(msg)
                .font(SanaTheme.Font.body(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again") { state = .idle }
                .buttonStyle(NourishButtonStyle())
                .padding(.horizontal, 60)
        }
        .padding(.top, 60)
    }

    // MARK: - Analysis

    private func analyze(image: UIImage) async {
        state = .analyzing
        guard let data = image.jpegData(compressionQuality: 0.8),
              data.count < 5_000_000 else {
            state = .error(String(localized: "Image too large. Try a closer crop."))
            return
        }

        let base64 = data.base64EncodedString()
        let schema = """
        {"mealName":"string","servingSize":"string","servingsPerContainer":float,"calories":integer,"protein":float,"carbohydrates":float,"fat":float,"fiber":float,"sugar":float,"sodium":float,"ingredients":["string"],"confidence":float}
        """
        let system = """
        You are a nutrition label reader. Analyse the provided food label image.
        Return ONLY valid JSON matching this exact schema — no markdown, no explanation:
        \(schema)
        Rules:
        - Extract nutrition values per serving as printed on the label.
        - If servings per container is not shown, use 1.
        - mealName: the product name as shown on the packaging.
        - ingredients: extract ALL ingredients listed in order as they appear on the label. Each should be a clean string. If the ingredients list is not visible, return an empty array [].
        - confidence: 0.0–1.0 based on overall label readability.
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 512,
            "system": system,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": base64]],
                    ["type": "text", "text": "Extract all nutrition information from this label."]
                ]
            ]]
        ]

        do {
            let endpoint = BackendConfig.proxyURL ?? URL(string: "https://api.anthropic.com/v1/messages")!
            var req = URLRequest(url: endpoint, timeoutInterval: 60)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            if BackendConfig.proxyURL != nil {
                req.setValue(BackendConfig.appSecret, forHTTPHeaderField: "X-App-Secret")
            } else {
                let apiKey = APIKeyStore.claudeAPIKey
                guard !apiKey.isEmpty else {
                    state = .error(String(localized: "API key not configured."))
                    return
                }
                req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            }
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (responseData, urlResponse) = try await URLSession.shared.data(for: req)
            let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode == 429 { throw ClaudeError.quotaExceeded }
            guard statusCode == 200 else { throw ClaudeError.httpError(statusCode) }
            let decoded = try JSONDecoder().decode(LabelAPIResponse.self, from: responseData)
            guard let text = decoded.content.first?.text else { throw NSError(domain: "parse", code: 0) }

            let clean = cleanJSON(text)
            guard let jsonData = clean.data(using: .utf8) else { throw NSError(domain: "json", code: 0) }
            let label = try JSONDecoder().decode(LabelJSON.self, from: jsonData)

            let result = LabelScanResult(
                mealName: label.mealName,
                servingSize: label.servingSize,
                servingsPerContainer: label.servingsPerContainer,
                servingsUsed: 1.0,
                calories: label.calories,
                protein: label.protein,
                carbohydrates: label.carbohydrates,
                fat: label.fat,
                fiber: label.fiber,
                sugar: label.sugar,
                sodium: label.sodium,
                confidence: label.confidence,
                ingredients: label.ingredients ?? []
            )
            state = .result(result)
        } catch ClaudeError.quotaExceeded {
            showPaywall = true
        } catch {
            state = .error(String(localized: "Couldn't read the label clearly. Make sure the image is sharp and well-lit."))
        }
    }

    private func cleanJSON(_ text: String) -> String {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```") {
            let lines = clean.components(separatedBy: "\n").dropFirst().dropLast()
            clean = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = clean.firstIndex(where: { $0 == "{" }) { clean = String(clean[start...]) }
        return clean
    }
}

// MARK: - Result view (inside scanner)

private struct ResultView: View {
    @State var result: LabelScanResult
    let mealType: MealType
    let onSave: (LabelScanResult) -> Void
    let onRescan: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var scaledCalories: Int { Int(Double(result.calories) * result.servingsUsed) }
    private var scaledProtein: Double { result.protein * result.servingsUsed }
    private var scaledCarbs: Double { result.carbohydrates * result.servingsUsed }
    private var scaledFat: Double { result.fat * result.servingsUsed }
    private var scaledFiber: Double { result.fiber * result.servingsUsed }

    var body: some View {
        VStack(spacing: SanaTheme.Spacing.lg) {
            // Header
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(SanaTheme.Color.primary)
                    Text("Label read successfully")
                        .font(SanaTheme.Font.headline())
                    Spacer()
                    confidenceBadge
                }
                Text(result.mealName)
                    .font(SanaTheme.Font.title(22))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Serving adjuster
            VStack(alignment: .leading, spacing: 10) {
                Text("How much did you eat?")
                    .font(SanaTheme.Font.headline(14))
                Text(String(format: NSLocalizedString("Label serving: %@  ·  %.1f servings per container", comment: ""), result.servingSize, result.servingsPerContainer))
                    .font(SanaTheme.Font.caption(12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { mult in
                        Button {
                            withAnimation(SanaTheme.Animation.snappy) { result.servingsUsed = mult }
                        } label: {
                            Text(mult == 0.5 ? "½" : mult == 1.0 ? "1" : mult == 1.5 ? "1½" : "2")
                                .font(SanaTheme.Font.headline())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(result.servingsUsed == mult ? SanaTheme.Color.primary : SanaTheme.Color.surface)
                                .foregroundStyle(result.servingsUsed == mult ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.sm))
                        }
                    }
                }

                Text("× serving")
                    .font(SanaTheme.Font.caption(11))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .nourishCard()

            // Scaled macros
            VStack(alignment: .leading, spacing: 12) {
                Text("Nutrition (scaled)")
                    .font(SanaTheme.Font.headline())
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    macroCell(label: "Calories", value: "\(scaledCalories)", unit: "kcal", color: .orange)
                    macroCell(label: "Protein", value: String(format: "%.1f", scaledProtein), unit: "g", color: .blue)
                    macroCell(label: "Carbs", value: String(format: "%.1f", scaledCarbs), unit: "g", color: .yellow)
                    macroCell(label: "Fat", value: String(format: "%.1f", scaledFat), unit: "g", color: .red)
                    macroCell(label: "Fiber", value: String(format: "%.1f", scaledFiber), unit: "g", color: .green)
                    macroCell(label: "Sodium", value: String(format: "%.0f", result.sodium * result.servingsUsed), unit: "mg", color: .purple)
                }
            }
            .padding()
            .nourishCard()

            // Ingredient analysis
            if !result.ingredients.isEmpty {
                IngredientsAnalysisView(ingredients: result.ingredients)
            }

            // Action buttons
            Button("Log this meal") {
                var saved = result
                saved.servingsUsed = result.servingsUsed
                onSave(saved)
                dismiss()
            }
            .buttonStyle(NourishButtonStyle())

            Button("Scan again") { onRescan() }
                .buttonStyle(NourishButtonStyle(isPrimary: false))
        }
    }

    private var confidenceBadge: some View {
        let pct = Int(result.confidence * 100)
        let color: Color = result.confidence > 0.8 ? .green : result.confidence > 0.6 ? .orange : .red
        return Text("\(pct)% accuracy")
            .font(SanaTheme.Font.caption(11))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func macroCell(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(SanaTheme.Font.headline(18)).foregroundStyle(color)
                Text(unit).font(SanaTheme.Font.caption(11)).foregroundStyle(.secondary)
            }
            Text(label).font(SanaTheme.Font.caption(11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.sm))
    }
}

// MARK: - Ingredients analysis view

private struct IngredientsAnalysisView: View {

    let ingredients: [String]
    @State private var isExpanded = false

    private var overallRisk: IngredientRisk { IngredientHealthEngine.overallRisk(of: ingredients) }
    private var flagged: [(String, IngredientRisk)] {
        ingredients.compactMap { ing in
            let r = IngredientHealthEngine.risk(for: ing)
            return r == .none ? nil : (ing, r)
        }
    }

    private var riskColor: Color {
        switch overallRisk {
        case .high:     return .red
        case .moderate: return .orange
        case .none:     return .green
        }
    }

    private var riskLabel: String {
        switch overallRisk {
        case .high:     return NSLocalizedString("Contains concerning ingredients", comment: "")
        case .moderate: return NSLocalizedString("Some ingredients to watch", comment: "")
        case .none:     return NSLocalizedString("Clean ingredient list", comment: "")
        }
    }

    private var riskIcon: String {
        switch overallRisk {
        case .high:     return "exclamationmark.triangle.fill"
        case .moderate: return "exclamationmark.circle.fill"
        case .none:     return "checkmark.seal.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with overall risk badge
            HStack {
                Label("Ingredients", systemImage: "list.bullet.rectangle")
                    .font(SanaTheme.Font.headline())
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: riskIcon)
                    Text(riskLabel)
                }
                .font(SanaTheme.Font.caption(11))
                .foregroundStyle(riskColor)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(riskColor.opacity(0.12))
                .clipShape(Capsule())
            }

            // Flagged concerns (always visible)
            if !flagged.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(flagged, id: \.0) { (ing, risk) in
                        FlaggedIngredientRow(name: ing, risk: risk)
                    }
                }
            }

            // Full ingredient list (expandable)
            Button {
                withAnimation(SanaTheme.Animation.snappy) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(isExpanded
                 ? NSLocalizedString("Hide full list", comment: "")
                 : String(format: NSLocalizedString("Show all %d ingredients", comment: ""), ingredients.count)
            )
                        .font(SanaTheme.Font.caption(12))
                        .foregroundStyle(SanaTheme.Color.primary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(SanaTheme.Color.primary)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(ingredients.enumerated()), id: \.offset) { _, ing in
                        let risk = IngredientHealthEngine.risk(for: ing)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Circle()
                                .fill(risk == .high ? Color.red : risk == .moderate ? Color.orange : Color.secondary.opacity(0.4))
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)
                            Text(ing)
                                .font(SanaTheme.Font.body(13))
                                .foregroundStyle(risk == .none ? .secondary : .primary)
                                .fontWeight(risk == .none ? .regular : .medium)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .nourishCard()
    }
}

private struct FlaggedIngredientRow: View {
    let name: String
    let risk: IngredientRisk
    @State private var showingExplanation = false

    private var color: Color { risk == .high ? .red : .orange }
    private var icon: String { risk == .high ? "exclamationmark.triangle.fill" : "exclamationmark.circle" }
    private var label: String {
        risk == .high
            ? NSLocalizedString("High concern", comment: "")
            : NSLocalizedString("Watch", comment: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(SanaTheme.Animation.snappy) { showingExplanation.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.system(size: 13))
                    Text(name)
                        .font(SanaTheme.Font.body(13))
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(label)
                        .font(SanaTheme.Font.caption(10))
                        .foregroundStyle(color)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                    Image(systemName: showingExplanation ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if showingExplanation, let explanation = IngredientHealthEngine.explanation(for: name) {
                Text(explanation)
                    .font(SanaTheme.Font.caption(12))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 22)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.sm))
    }
}

// MARK: - Private Codable types

private struct LabelAPIResponse: Codable {
    let content: [Block]
    struct Block: Codable { let text: String? }
}

private struct LabelJSON: Codable {
    let mealName: String
    let servingSize: String
    let servingsPerContainer: Double
    let calories: Int
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let sodium: Double
    let ingredients: [String]?
    let confidence: Double
}
