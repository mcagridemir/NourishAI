// Sana — BarcodeService.swift
import Foundation

// MARK: - Domain types

struct FoodProduct {
    let name: String
    let caloriesPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let fiberPer100g: Double
    let sugarPer100g: Double
    let sodiumMgPer100g: Double
    let defaultServingG: Double

    func scaled(toGrams grams: Double) -> ScaledProduct {
        let f = grams / 100.0
        return ScaledProduct(
            name: name,
            grams: grams,
            calories: Int((caloriesPer100g * f).rounded()),
            protein: proteinPer100g * f,
            carbs: carbsPer100g * f,
            fat: fatPer100g * f,
            fiber: fiberPer100g * f,
            sugar: sugarPer100g * f,
            sodiumMg: sodiumMgPer100g * f
        )
    }
}

struct ScaledProduct {
    let name: String
    let grams: Double
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let sodiumMg: Double
}

enum BarcodeError: LocalizedError {
    case productNotFound, networkError(String)
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return NSLocalizedString("Product not found. Try scanning again or enter manually.", comment: "")
        case .networkError(let m):
            return String(format: NSLocalizedString("Network error: %@", comment: ""), m)
        }
    }
}

// MARK: - Service

actor BarcodeService {

    static let shared = BarcodeService()
    private init() {}

    func fetchProduct(barcode: String) async throws -> FoodProduct {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json") else {
            throw BarcodeError.networkError("Invalid barcode")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 1,
              let product = json["product"] as? [String: Any],
              let parsed = parseProduct(product) else {
            throw BarcodeError.productNotFound
        }
        return parsed
    }

    func searchProducts(query: String) async throws -> [FoodProduct] {
        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encoded)&json=1&page_size=25&fields=product_name,nutriments,brands,serving_quantity")
        else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let products = json["products"] as? [[String: Any]] else { return [] }
        return products.compactMap { parseProduct($0) }
    }

    private func parseProduct(_ product: [String: Any]) -> FoodProduct? {
        let rawName = (product["product_name"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        guard !rawName.isEmpty else { return nil }
        let brand = (product["brands"] as? String ?? "")
            .components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let name = brand.isEmpty ? rawName : "\(rawName) · \(brand)"

        let nutriments = product["nutriments"] as? [String: Any] ?? [:]
        let cal = double(nutriments, "energy-kcal_100g") ?? double(nutriments, "energy-kcal") ?? 0
        guard cal > 0 else { return nil }

        let serving = (product["serving_quantity"] as? Double) ?? 100.0
        return FoodProduct(
            name: name,
            caloriesPer100g: cal,
            proteinPer100g:  double(nutriments, "proteins_100g") ?? 0,
            carbsPer100g:    double(nutriments, "carbohydrates_100g") ?? 0,
            fatPer100g:      double(nutriments, "fat_100g") ?? 0,
            fiberPer100g:    double(nutriments, "fiber_100g") ?? 0,
            sugarPer100g:    double(nutriments, "sugars_100g") ?? 0,
            sodiumMgPer100g: (double(nutriments, "sodium_100g") ?? 0) * 1000,
            defaultServingG: max(serving, 10)
        )
    }

    private func double(_ dict: [String: Any], _ key: String) -> Double? {
        if let d = dict[key] as? Double { return d }
        if let i = dict[key] as? Int { return Double(i) }
        // OpenFoodFacts sometimes returns numeric nutriment values as strings.
        if let s = dict[key] as? String { return Double(s) }
        return nil
    }
}
