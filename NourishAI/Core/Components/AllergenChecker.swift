// NourishAI — AllergenChecker.swift
import Foundation

struct AllergenChecker {

    static func detect(in productName: String, against allergies: [String]) -> [String] {
        let lower = productName.lowercased()
        return allergies.filter { allergen in
            keywords(for: allergen).contains { lower.contains($0) }
        }
    }

    private static func keywords(for allergen: String) -> [String] {
        switch allergen.lowercased() {
        case "gluten":    return ["gluten", "wheat", "barley", "rye", "spelt", "kamut", "semolina"]
        case "dairy":     return ["milk", "dairy", "cheese", "butter", "cream", "whey", "lactose", "yogurt", "yoghurt", "casein", "ghee"]
        case "nuts":      return ["almond", "walnut", "cashew", "peanut", "hazelnut", "pecan", "pistachio", "macadamia", "nut"]
        case "eggs":      return ["egg"]
        case "soy":       return ["soy", "soya", "tofu", "edamame", "miso", "tempeh"]
        case "shellfish": return ["shrimp", "crab", "lobster", "prawn", "shellfish", "clam", "oyster", "mussel", "scallop"]
        case "fish":      return ["fish", "salmon", "tuna", "cod", "tilapia", "bass", "halibut", "trout", "anchovy", "sardine", "mackerel"]
        case "sesame":    return ["sesame", "tahini"]
        default:          return [allergen.lowercased()]
        }
    }
}
