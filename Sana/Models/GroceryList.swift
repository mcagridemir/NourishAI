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
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var weekStartDate: Date = Date.now
    var sections: [GrocerySection] = []
    var isArchived: Bool = false

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

