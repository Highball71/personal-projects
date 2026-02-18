//
//  GroceryCheck.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/18/26.
//

import Foundation
import SwiftData

/// Persists the checked/unchecked state of a grocery list item.
/// Scoped to a week so checks don't carry over when the week changes.
@Model
final class GroceryCheck {
    /// Matches GroceryItem.id — e.g. "flour|cup"
    var itemID: String = ""

    /// The Monday (start) of the week this check belongs to.
    var weekStart: Date = Date()

    init(itemID: String, weekStart: Date) {
        self.itemID = itemID
        self.weekStart = weekStart
    }
}
