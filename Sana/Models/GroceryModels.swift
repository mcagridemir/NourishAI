// Sana — GroceryModels.swift
import Foundation

struct GrocerySection: Codable, Sendable {
    var category: String
    var items: [GroceryItem]

    var icon: String {
        switch category.lowercased() {
        case "produce":  return "leaf"
        case "protein":  return "flame"
        case "dairy":    return "drop"
        case "grains":   return "circle.grid.3x3"
        case "pantry":   return "cabinet"
        case "frozen":   return "snowflake"
        default:         return "bag"
        }
    }
}

struct GroceryItem: Codable, Sendable {
    var id: UUID
    var name: String
    var quantity: Double
    var unit: String
    var isChecked: Bool

    init(name: String, quantity: Double, unit: String) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.isChecked = false
    }

    var formattedQuantity: String {
        quantity == quantity.rounded() ? "\(Int(quantity)) \(unit)" : "\(String(format: "%.1f", quantity)) \(unit)"
    }
}
