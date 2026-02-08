//
//  Ingredient.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import Foundation
import SwiftData

/// A single ingredient line in a recipe (e.g., "2 cups flour").
/// Each Ingredient belongs to exactly one Recipe.
@Model
final class Ingredient {
    var name: String
    var quantity: Double
    var unit: IngredientUnit

    // SwiftData automatically creates this inverse relationship
    // back to the Recipe that owns this ingredient.
    var recipe: Recipe?

    init(name: String, quantity: Double, unit: IngredientUnit = .piece) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }
}
