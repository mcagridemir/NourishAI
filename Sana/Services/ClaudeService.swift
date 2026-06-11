// Sana — ClaudeService.swift
import Foundation
internal import UIKit

// MARK: - API domain types

struct NutritionAnalysis: Codable {
    let mealName: String
    let calories: Int
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let sodium: Double
    let vitamins: [String: Double]
    let minerals: [String: Double]
    let healthScore: Int
    let insights: [String]
    let suggestions: [String]
    let estimatedPortionSize: String
    let confidence: Double
}

struct RecipeResult: Codable {
    let name: String
    let description: String
    let servings: Int
    let prepTimeMinutes: Int
    let cookTimeMinutes: Int
    let ingredients: [String]
    let instructions: [String]
    var caloriesPerServing: Int   // mutable for serving-size scaling
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var fiber: Double
    let healthScore: Int
    let tips: [String]
}

struct MealSuggestion: Codable {
    let name: String
    let description: String
    let prepTime: Int
    let calories: Int
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let ingredients: [String]
    let recipe: String
}

struct MealPlanResponse: Codable {
    let days: [MealPlanDayResponse]
}

struct MealPlanDayResponse: Codable {
    let dayIndex: Int
    let breakfast: MealSuggestion
    let lunch: MealSuggestion
    let dinner: MealSuggestion
    let snacks: [MealSuggestion]
    let totalCalories: Int
}

struct WeeklyStats {
    let avgCalories: Int
    let avgProtein: Int
    let avgCarbs: Int
    let avgFat: Int
    let mealCount: Int
    let daysTracked: Int
    let avgHealthScore: Int
    let waterGoalHitDays: Int
}

struct WeeklyReport: Codable {
    let headline: String
    let overallScore: Int
    let highlights: [String]
    let improvements: [String]
    let nutrientSpotlight: String
    let nextWeekChallenge: String
}

struct UserNutritionContext {
    let profileDescription: String
    let recentNutritionSummary: String
    let detectedDeficiencies: [String]
    let allergies: [String]
    let healthConditions: [String]
    let country: String
    let dailyCalorieTarget: Int
    let language: String   // BCP-47 code, e.g. "tr", "en"

    // Convenience helpers for prompts
    var avoidClause: String {
        allergies.isEmpty ? "nothing" : allergies.joined(separator: ", ")
    }
    var conditionsClause: String {
        healthConditions.isEmpty ? "none" : healthConditions.joined(separator: ", ")
    }
    var cuisineNote: String {
        country.isEmpty ? "" : "Prefer \(country) cuisine and traditional foods when appropriate."
    }
    var languageInstruction: String {
        let name = Locale(identifier: "en").localizedString(forLanguageCode: language) ?? language
        return "Always respond in \(name). Never switch to another language, even if the user writes in one."
    }
}

// MARK: - ClaudeService

actor ClaudeService {

    static let shared = ClaudeService()

    private let apiKey: String
    private let model = "claude-sonnet-4-6"
    private let directURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let decoder = JSONDecoder()
    /// Set by AuthService after sign-in/out; forwarded as X-User-ID on proxy requests.
    private var currentUserID: String?

    private init() {
        self.apiKey = APIKeyStore.claudeAPIKey
    }

    func setUserID(_ id: String?) {
        currentUserID = id
    }

    // MARK: - Meal photo analysis

    func analyzeMeal(image: UIImage, mealType: MealType, context: UserNutritionContext) async throws -> NutritionAnalysis {
        guard let imageData = image.jpegData(compressionQuality: 0.75),
              imageData.count < 5_000_000 else {
            throw ClaudeError.imageEncodingFailed
        }
        let base64 = imageData.base64EncodedString()

        let schema = """
        {
          "mealName": "string",
          "calories": "integer",
          "protein": "float (grams)",
          "carbohydrates": "float (grams)",
          "fat": "float (grams)",
          "fiber": "float (grams)",
          "sugar": "float (grams)",
          "sodium": "float (mg)",
          "vitamins": {"vitamin_c": float, "vitamin_d": float, "vitamin_b12": float},
          "minerals": {"iron": float, "calcium": float, "potassium": float},
          "healthScore": "integer 0-100",
          "insights": ["string", "string"],
          "suggestions": ["string", "string"],
          "estimatedPortionSize": "string",
          "confidence": "float 0.0-1.0"
        }
        """

        let system = """
        You are an expert nutritionist AI. Analyse meal photos and return ONLY valid JSON matching this exact schema:
        \(schema)
        No markdown fences, no explanation — raw JSON only.
        Use metric units. Estimate portions from visual cues.
        Meal type context: \(mealType.rawValue)
        User profile: \(context.profileDescription)
        Health conditions to consider: \(context.conditionsClause)
        \(context.cuisineNote)
        \(context.languageInstruction)
        All "insights" and "suggestions" array values must be written in the user's language.
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": system,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": base64]],
                    ["type": "text", "text": "Analyse this \(mealType.rawValue.lowercased()) and return the NutritionAnalysis JSON."]
                ]
            ]]
        ]

        let data = try await post(body: body)
        let raw = try decoder.decode(ClaudeResponse.self, from: data)
        let jsonText = raw.content.first?.text ?? ""
        return try parseJSON(NutritionAnalysis.self, from: jsonText)
    }

    // MARK: - Text meal analysis (natural-language description → NutritionAnalysis)

    func analyzeTextMeal(description: String, context: UserNutritionContext) async throws -> NutritionAnalysis {
        let schema = """
        {"mealName":"string","calories":"integer","protein":"float (g)","carbohydrates":"float (g)","fat":"float (g)","fiber":"float (g)","sugar":"float (g)","sodium":"float (mg)","vitamins":{"vitamin_c":0,"vitamin_d":0,"vitamin_b12":0},"minerals":{"iron":0,"calcium":0,"potassium":0},"healthScore":"integer 0-100","insights":["string"],"suggestions":["string"],"estimatedPortionSize":"string","confidence":"float 0-1"}
        """
        let regionHint = context.country.isEmpty ? "internationally" : "in \(context.country)"
        let system = """
        You are an expert nutritionist AI. Estimate the nutritional content of food described in plain language.
        Consider typical portion sizes as understood \(regionHint) — e.g. "1 glass" ≈ 200-250 ml, "1 bowl" ≈ 300-350 ml, "1 plate" ≈ 400 g, "1 tablespoon" ≈ 15 g, "1 teaspoon" ≈ 5 g, "1 handful" ≈ 30 g.
        Return ONLY valid JSON matching this schema. No markdown, no explanation.
        \(schema)
        User profile: \(context.profileDescription)
        Health conditions: \(context.conditionsClause)
        \(context.languageInstruction)
        All "insights" and "suggestions" array values must be written in the user's language.
        """
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": system,
            "messages": [["role": "user", "content": "Estimate nutrition for: \(description)"]]
        ]
        let data = try await post(body: body)
        let raw  = try decoder.decode(ClaudeResponse.self, from: data)
        return try parseJSON(NutritionAnalysis.self, from: raw.content.first?.text ?? "{}")
    }

    // MARK: - Streaming chat

    func streamChat(messages: [ChatMessage], context: UserNutritionContext) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let system = """
                    You are Sana, a warm, knowledgeable, and encouraging nutrition coach.
                    Be concise and practical. Use plain language — avoid jargon.
                    Never diagnose medical conditions. For health concerns, recommend a doctor.
                    Always tailor advice to the user's profile and recent data.
                    User profile: \(context.profileDescription)
                    Recent nutrition: \(context.recentNutritionSummary)
                    Deficiencies detected: \(context.detectedDeficiencies.isEmpty ? "none" : context.detectedDeficiencies.joined(separator: ", "))
                    Health conditions: \(context.conditionsClause)
                    \(context.cuisineNote)
                    When suggesting meals, use culturally familiar foods for the user's region. Always flag any meal or nutrient that conflicts with their health conditions.
                    \(context.languageInstruction)
                    """

                    let apiMessages = messages.prefix(40).map { $0.toAPIDict() }

                    let body: [String: Any] = [
                        "model": model, "max_tokens": 1024, "stream": true,
                        "system": system, "messages": Array(apiMessages)
                    ]

                    let request = try buildRequest(body: body)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        throw ClaudeError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: "),
                              let lineData = String(line.dropFirst(6)).data(using: .utf8),
                              let event = try? decoder.decode(StreamDelta.self, from: lineData),
                              let text = event.delta?.text
                        else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Meal plan generation

    func generateMealPlan(days: Int = 3, context: UserNutritionContext) async throws -> MealPlanResponse {
        let prompt = """
        Generate a \(days)-day meal plan. Return ONLY raw JSON, no markdown.
        Format: {"days":[{"dayIndex":0,"breakfast":{...},"lunch":{...},"dinner":{...},"snacks":[],"totalCalories":0}]}
        Each meal: {"name":"","description":"","prepTime":0,"calories":0,"protein":0,"carbohydrates":0,"fat":0,"ingredients":["item1","item2"],"recipe":""}
        Rules: max 3 ingredients per meal, recipe max 1 sentence, snacks array can be empty.
        User: \(context.profileDescription)
        Avoid: \(context.avoidClause)
        Health conditions to accommodate: \(context.conditionsClause)
        \(context.cuisineNote)
        Target: \(context.dailyCalorieTarget) kcal/day
        Include traditional \(context.country.isEmpty ? "local" : context.country) meals and ingredients where fitting.
        \(context.languageInstruction)
        All meal names, descriptions, ingredients, and recipe text must be in the user's language.
        """

        let body: [String: Any] = [
            "model": model, "max_tokens": 4096,
            "messages": [["role": "user", "content": prompt]]
        ]

        let data = try await post(body: body)
        let raw = try decoder.decode(ClaudeResponse.self, from: data)
        let jsonText = raw.content.first?.text ?? "{}"
        print("📦 Raw meal plan JSON: \(jsonText.prefix(300))")
        return try parseJSON(MealPlanResponse.self, from: jsonText)
    }

    // MARK: - Grocery list

    func generateGroceryList(from plan: MealPlanResponse, language: String = "en") async throws -> [GrocerySection] {
        let meals = plan.days.flatMap { d in
            [d.breakfast.name, d.lunch.name, d.dinner.name] + d.snacks.map { $0.name }
        }
        let langName = Locale(identifier: "en").localizedString(forLanguageCode: language) ?? language
        let langInstruction = "Always respond in \(langName). Translate all category names and item names to \(langName)."
        let prompt = """
        Create a grouped grocery shopping list for: \(meals.joined(separator: ", ")).
        Return ONLY JSON array: [{"category": "string", "items": [{"name":"string","quantity":float,"unit":"string"}]}]
        Categories: Produce, Protein, Dairy, Grains, Pantry, Frozen. Consolidate duplicates.
        \(langInstruction)
        """

        let body: [String: Any] = [
            "model": model, "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ]

        let data = try await post(body: body)
        let raw = try decoder.decode(ClaudeResponse.self, from: data)
        let jsonText = raw.content.first?.text ?? "[]"

        struct RawSection: Codable {
            let category: String
            struct RawItem: Codable { let name: String; let quantity: Double; let unit: String }
            let items: [RawItem]
        }
        let rawSections = try parseJSON([RawSection].self, from: jsonText)
        return rawSections.map { raw in
            GrocerySection(category: raw.category, items: raw.items.map {
                GroceryItem(name: $0.name, quantity: $0.quantity, unit: $0.unit)
            })
        }
    }

    // MARK: - Recipe generation

    func generateRecipe(ingredients: [String], context: UserNutritionContext) async throws -> RecipeResult {
        let schema = """
        {"name":"string","description":"string (1-2 sentences)","servings":integer,"prepTimeMinutes":integer,"cookTimeMinutes":integer,"ingredients":["string"],"instructions":["string"],"caloriesPerServing":integer,"protein":float,"carbohydrates":float,"fat":float,"fiber":float,"healthScore":integer,"tips":["string"]}
        """
        let prompt = """
        Create a healthy recipe using these ingredients: \(ingredients.joined(separator: ", ")).
        You may add a few common pantry staples. Return ONLY raw JSON matching this schema:
        \(schema)
        User: \(context.profileDescription)
        Avoid: \(context.avoidClause)
        Health conditions to accommodate: \(context.conditionsClause)
        \(context.cuisineNote)
        Target ~\(context.dailyCalorieTarget / 3) kcal per serving.
        \(context.languageInstruction)
        All name, description, ingredients, instructions, and tips must be in the user's language.
        """
        let body: [String: Any] = [
            "model": model, "max_tokens": 2048,
            "messages": [["role": "user", "content": prompt]]
        ]
        let data = try await post(body: body)
        let raw = try decoder.decode(ClaudeResponse.self, from: data)
        return try parseJSON(RecipeResult.self, from: raw.content.first?.text ?? "{}")
    }

    // MARK: - Full weekly report

    func generateWeeklyReport(context: UserNutritionContext, stats: WeeklyStats) async throws -> WeeklyReport {
        let schema = """
        {
          "headline": "string (one punchy sentence summarising the week)",
          "overallScore": integer (0-100),
          "highlights": ["string", "string", "string"],
          "improvements": ["string", "string"],
          "nutrientSpotlight": "string (focus on one specific nutrient pattern)",
          "nextWeekChallenge": "string (one actionable challenge for next week)"
        }
        """
        let prompt = """
        Analyse this user's nutrition week and return ONLY raw JSON matching this schema:
        \(schema)

        User profile: \(context.profileDescription)
        Week stats:
        - Average daily calories: \(stats.avgCalories) (target: \(context.dailyCalorieTarget))
        - Average protein: \(stats.avgProtein)g | carbs: \(stats.avgCarbs)g | fat: \(stats.avgFat)g
        - Meals logged: \(stats.mealCount) over \(stats.daysTracked) days
        - Average health score: \(stats.avgHealthScore)/100
        - Deficiencies detected: \(context.detectedDeficiencies.isEmpty ? "none" : context.detectedDeficiencies.joined(separator: ", "))
        - Water goal hit: \(stats.waterGoalHitDays)/\(stats.daysTracked) days

        Be specific, warm, and data-driven. No generic advice.
        \(context.languageInstruction)
        """
        let body: [String: Any] = [
            "model": model, "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ]
        let data = try await post(body: body)
        let raw = try decoder.decode(ClaudeResponse.self, from: data)
        return try parseJSON(WeeklyReport.self, from: raw.content.first?.text ?? "{}")
    }

    // MARK: - Meal replacement

    func replaceMealSuggestion(
        currentMealName: String,
        mealType: MealType,
        preference: String,
        context: UserNutritionContext
    ) async throws -> MealSuggestion {
        let preferenceNote = preference.isEmpty
            ? "something different but equally nutritious"
            : preference
        let approxCal = context.dailyCalorieTarget / (mealType == .snack ? 5 : 3)
        let prompt = """
        Suggest a replacement \(mealType.rawValue.lowercased()) instead of "\(currentMealName)".
        User preference: \(preferenceNote).
        Return ONLY raw JSON (no markdown):
        {"name":"","description":"","prepTime":0,"calories":0,"protein":0,"carbohydrates":0,"fat":0,"ingredients":["item1","item2","item3"],"recipe":""}
        Constraints:
        - Target ~\(approxCal) kcal
        - 4-6 ingredients
        - recipe: 1-2 sentences maximum
        - Avoid: \(context.avoidClause)
        - Health conditions: \(context.conditionsClause)
        \(context.cuisineNote)
        User profile: \(context.profileDescription)
        \(context.languageInstruction)
        """
        let body: [String: Any] = [
            "model": model, "max_tokens": 512,
            "messages": [["role": "user", "content": prompt]]
        ]
        let data = try await post(body: body)
        let raw = try decoder.decode(ClaudeResponse.self, from: data)
        return try parseJSON(MealSuggestion.self, from: raw.content.first?.text ?? "{}")
    }

    // MARK: - Nutrition insights

    func generateWeeklyInsights(context: UserNutritionContext) async throws -> String {
        let prompt = """
        Write a short, encouraging weekly nutrition summary (3-4 sentences).
        User: \(context.profileDescription)
        Recent data: \(context.recentNutritionSummary)
        Deficiencies: \(context.detectedDeficiencies.joined(separator: ", "))
        Be specific, warm, and actionable. Plain text only.
        \(context.languageInstruction)
        """
        let body: [String: Any] = [
            "model": model, "max_tokens": 256,
            "messages": [["role": "user", "content": prompt]]
        ]
        let data = try await post(body: body)
        let raw = try decoder.decode(ClaudeResponse.self, from: data)
        return raw.content.first?.text ?? ""
    }

    // MARK: - Private helpers

    private func post(body: [String: Any]) async throws -> Data {
        let request = try buildRequest(body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ClaudeError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }

    private func buildRequest(body: [String: Any]) throws -> URLRequest {
        let url = BackendConfig.proxyURL ?? directURL
        var req = URLRequest(url: url, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if BackendConfig.proxyURL != nil {
            req.setValue(BackendConfig.appSecret, forHTTPHeaderField: "X-App-Secret")
            if let userID = currentUserID {
                req.setValue(userID, forHTTPHeaderField: "X-User-ID")
            }
        } else {
            guard !apiKey.isEmpty else {
                throw ClaudeError.apiKeyMissing
            }
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    private func parseJSON<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Strip ```json ... ``` or ``` ... ``` fences
        if clean.hasPrefix("```") {
            let lines = clean.components(separatedBy: "\n")
            let stripped = lines.dropFirst().dropLast()
            clean = stripped.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Find the first { or [ and trim anything before it
        if let start = clean.firstIndex(where: { $0 == "{" || $0 == "[" }) {
            clean = String(clean[start...])
        }
        
        guard let data = clean.data(using: .utf8) else { throw ClaudeError.invalidJSON }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("❌ JSON decode error: \(error)")
            print("❌ Attempted to decode: \(clean.prefix(300))")
            throw ClaudeError.decodingFailed(error.localizedDescription)
        }
    }
}

// MARK: - Private response types

private struct ClaudeResponse: Codable, Sendable {
    let content: [ContentBlock]
    struct ContentBlock: Codable, Sendable { let text: String? }
}

private struct StreamDelta: Codable, Sendable {
    let delta: DeltaContent?
    struct DeltaContent: Codable, Sendable { let text: String? }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case imageEncodingFailed
    case invalidJSON
    case decodingFailed(String)
    case httpError(Int)
    case apiKeyMissing

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return NSLocalizedString("Could not encode image for upload.", comment: "")
        case .invalidJSON:
            return NSLocalizedString("Received unexpected response format.", comment: "")
        case .decodingFailed(let msg):
            return String(format: NSLocalizedString("Parse error: %@", comment: ""), msg)
        case .httpError(let code):
            return String(format: NSLocalizedString("Server error (HTTP %d).", comment: ""), code)
        case .apiKeyMissing:
            return NSLocalizedString("AI service is not configured. Please check your setup.", comment: "")
        }
    }
}
