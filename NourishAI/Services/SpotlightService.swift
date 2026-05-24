// NourishAI — SpotlightService.swift
import CoreSpotlight
import Foundation

struct SpotlightService {

    static let domainID = "com.cagri.NourishAI.meals"

    /// Index all meal entries so they appear in iOS Spotlight search.
    static func indexMeals(_ meals: [MealEntry]) {
        let items: [CSSearchableItem] = meals.map { meal in
            let attr = CSSearchableItemAttributeSet(contentType: .text)
            attr.title = meal.mealName
            attr.contentDescription = "\(meal.calories) kcal · \(meal.mealType.rawValue) · \(meal.loggedAt.formatted(.dateTime.month().day()))"
            attr.keywords = [meal.mealType.rawValue, "meal", "nutrition", "calories",
                             "\(meal.calories) kcal", "\(Int(meal.protein))g protein"]
            if let data = meal.photoData {
                attr.thumbnailData = data
            }
            return CSSearchableItem(
                uniqueIdentifier: meal.id.uuidString,
                domainIdentifier: domainID,
                attributeSet: attr
            )
        }
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    /// Remove a single meal from the index (call on delete).
    static func deindex(mealID: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [mealID.uuidString]) { _ in }
    }

    /// Remove all NourishAI meals from Spotlight.
    static func deindexAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainID]) { _ in }
    }
}
