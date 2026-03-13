//
//  RecipeFormData.swift
//  Family Meal Planner
//
//  A plain struct (not SwiftData) that holds intermediate recipe data
//  between import and persistence. Used by the import pipeline to pass
//  extracted data to the recipe form without touching SwiftData.

import Foundation
import SwiftData

struct RecipeFormData {
    var name: String = ""
    var ingredients: [IngredientFormData] = []
    var instructions: String = ""
    var servings: Int = 4
    var prepTimeMinutes: Int = 30
    var cookTimeMinutes: Int = 0
    var notes: String = ""
    var sourceURL: String = ""
    var category: RecipeCategory = .dinner

    /// Create a SwiftData Recipe from this form data.
    func toRecipe(in context: ModelContext, addedBy: String?) -> Recipe {
        let validIngredients = ingredients
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { Ingredient(name: $0.name, quantity: $0.quantity, unit: $0.unit) }

        let recipe = Recipe(
            name: name,
            category: category,
            servings: servings,
            prepTimeMinutes: prepTimeMinutes,
            cookTimeMinutes: cookTimeMinutes,
            instructions: instructions,
            ingredients: validIngredients,
            sourceType: sourceURL.isEmpty ? nil : .url,
            sourceDetail: sourceURL.isEmpty ? nil : sourceURL
        )
        recipe.addedByName = addedBy
        return recipe
    }

    /// Hydrate from an existing Recipe for editing.
    static func from(recipe: Recipe) -> RecipeFormData {
        RecipeFormData(
            name: recipe.name,
            ingredients: recipe.ingredientsList.map { ingredient in
                IngredientFormData(
                    name: ingredient.name,
                    quantity: ingredient.quantity,
                    unit: ingredient.unit,
                    quantityText: FractionFormatter.formatAsFraction(ingredient.quantity)
                )
            },
            instructions: recipe.instructions,
            servings: recipe.servings,
            prepTimeMinutes: recipe.prepTimeMinutes,
            cookTimeMinutes: recipe.cookTimeMinutes,
            sourceURL: recipe.sourceDetail ?? "",
            category: recipe.category
        )
    }
}
