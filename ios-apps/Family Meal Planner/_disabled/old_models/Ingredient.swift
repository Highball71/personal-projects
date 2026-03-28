//
//  Ingredient.swift
//  FluffyList
//
//  Created by David Albert on 2/8/26.
//

import Foundation
import SwiftData

/// A single ingredient line in a recipe (e.g., "2 cups flour").
/// Each Ingredient belongs to exactly one Recipe.
@Model
final class Ingredient {
    var name: String = ""
    var quantity: Double = 1.0
    var unitRaw: String = IngredientUnit.piece.rawValue

    var unit: IngredientUnit {
        get { IngredientUnit(rawValue: unitRaw) ?? .piece }
        set { unitRaw = newValue.rawValue }
    }

    // Explicit inverse of Recipe.ingredients — CloudKit requires
    // every relationship to declare its inverse.
    @Relationship(inverse: \Recipe.ingredients)
    var recipe: Recipe?

    init(name: String, quantity: Double, unit: IngredientUnit = .piece) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }
}
