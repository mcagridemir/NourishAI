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
    let dailyCalorieTarget: Int
}

// MARK: - ClaudeService

actor ClaudeService {

    static let shared = ClaudeService()

    private let apiKey: String
    private let model = "claude-sonnet-4-6"
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let decoder = JSONDecoder()

    private init() {
        let key = APIKeyStore.claudeAPIKey
        guard !key.isEmpty else {
            fatalError("Claude API key is missing. Run Scripts/generate_api_key.py and update APIKeyStore.swift.")
        }
        self.apiKey = key
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
        Avoid: \(context.allergies.isEmpty ? "nothing" : context.allergies.joined(separator: ", "))
        Target: \(context.dailyCalorieTarget) kcal/day
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

    func generateGroceryList(from plan: MealPlanResponse) async throws -> [GrocerySection] {
        let meals = plan.days.flatMap { d in
            [d.breakfast.name, d.lunch.name, d.dinner.name] + d.snacks.map { $0.name }
        }
        let prompt = """
        Create a grouped grocery shopping list for: \(meals.joined(separator: ", ")).
        Return ONLY JSON array: [{"category": "string", "items": [{"name":"string","quantity":float,"unit":"string"}]}]
        Categories: Produce, Protein, Dairy, Grains, Pantry, Frozen. Consolidate duplicates.
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
        Avoid: \(context.allergies.isEmpty ? "nothing" : context.allergies.joined(separator: ", "))
        Target ~\(context.dailyCalorieTarget / 3) kcal per serving.
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
        - Avoid: \(context.allergies.isEmpty ? "nothing" : context.allergies.joined(separator: ", "))
        User profile: \(context.profileDescription)
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
        var req = URLRequest(url: baseURL, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
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

private struct ClaudeResponse: Codable {
    let content: [ContentBlock]
    struct ContentBlock: Codable { let text: String? }
}

private struct StreamDelta: Codable {
    let delta: DeltaContent?
    struct DeltaContent: Codable { let text: String? }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case imageEncodingFailed
    case invalidJSON
    case decodingFailed(String)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:      return "Could not encode image for upload."
        case .invalidJSON:              return "Received unexpected response format."
        case .decodingFailed(let msg):  return "Parse error: \(msg)"
        case .httpError(let code):      return "Server error (HTTP \(code))."
        }
    }
}
