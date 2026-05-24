//
//  GroceryList.swift
//  Sana
//
//  Created by cagri.demir on 23.05.2026.
//

import Foundation
import SwiftData

@Model
final class GroceryList {
    var id: UUID
    var createdAt: Date
    var weekStartDate: Date
    var sections: [GrocerySection]
    var isArchived: Bool

    var totalItems: Int { sections.flatMap { $0.items }.count }
    var checkedItems: Int { sections.flatMap { $0.items }.filter { $0.isChecked }.count }
    var progress: Double {
        guard totalItems > 0 else { return 0 }
        return Double(checkedItems) / Double(totalItems)
    }

    init(weekStartDate: Date, sections: [GrocerySection] = []) {
        self.id = UUID()
        self.createdAt = .now
        self.weekStartDate = weekStartDate
        self.sections = sections
        self.isArchived = false
    }
}

struct GrocerySection: Codable {
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

struct GroceryItem: Codable {
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
