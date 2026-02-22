//
//  GroceryItem.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/22/26.
//

import Foundation
import SwiftData

/// A persisted grocery list item, scoped to a week.
/// Generated from the meal plan's ingredients and combined by name + unit.
/// The `isChecked` state survives app relaunches.
@Model
final class GroceryItem {
    /// Composite key: "flour|cup" — used for deduplication
    var itemID: String = ""
    var name: String = ""
    var totalQuantity: Double = 0
    var unit: IngredientUnit = IngredientUnit.none
    var isChecked: Bool = false
    /// The start of the week this item belongs to.
    var weekStart: Date = Date()

    init(itemID: String, name: String, totalQuantity: Double, unit: IngredientUnit, weekStart: Date) {
        self.itemID = itemID
        self.name = name
        self.totalQuantity = totalQuantity
        self.unit = unit
        self.weekStart = weekStart
    }
}
