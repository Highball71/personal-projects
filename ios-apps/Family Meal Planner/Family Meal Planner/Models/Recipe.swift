//
//  Recipe.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import Foundation
import SwiftData

/// A recipe with its ingredients and instructions.
/// This is the core model — everything else references recipes.
@Model
final class Recipe {
    var name: String
    var category: RecipeCategory
    var servings: Int
    var prepTimeMinutes: Int
    var instructions: String
    var dateCreated: Date

    // .cascade means: when you delete a recipe, its ingredients
    // are automatically deleted too. No orphaned data.
    @Relationship(deleteRule: .cascade, inverse: \Ingredient.recipe)
    var ingredients: [Ingredient]

    init(
        name: String,
        category: RecipeCategory = .dinner,
        servings: Int = 4,
        prepTimeMinutes: Int = 30,
        instructions: String = "",
        ingredients: [Ingredient] = []
    ) {
        self.name = name
        self.category = category
        self.servings = servings
        self.prepTimeMinutes = prepTimeMinutes
        self.instructions = instructions
        self.ingredients = ingredients
        self.dateCreated = Date()
    }
}
