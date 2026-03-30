//
//  RecipeFormData.swift
//  FluffyList
//
//  A plain struct that holds intermediate recipe data
//  between import and persistence. Used by the import pipeline to pass
//  extracted data to the recipe form without touching Core Data.

import Foundation
import CoreData

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

    /// Create a Core Data CDRecipe from this form data.
    func toRecipe(in context: NSManagedObjectContext, addedBy: String?) -> CDRecipe {
        let recipe = CDRecipe(context: context)
        recipe.id = UUID()
        recipe.name = name
        recipe.category = category
        recipe.servings = Int16(servings)
        recipe.prepTimeMinutes = Int16(prepTimeMinutes)
        recipe.cookTimeMinutes = Int16(cookTimeMinutes)
        recipe.instructions = instructions
        recipe.dateCreated = Date()
        recipe.sourceType = sourceURL.isEmpty ? nil : .url
        recipe.sourceDetail = sourceURL.isEmpty ? nil : sourceURL
        recipe.addedByName = addedBy

        // Link to the default household so it's included in the share.
        let householdRequest = CDHousehold.fetchRequest()
        householdRequest.fetchLimit = 1
        recipe.household = (try? context.fetch(householdRequest))?.first

        let validIngredients = ingredients
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        for ingData in validIngredients {
            let ing = CDIngredient(context: context)
            ing.id = UUID()
            ing.name = ingData.name
            ing.quantity = ingData.quantity
            ing.unit = ingData.unit
            ing.recipe = recipe
        }

        return recipe
    }

    /// Hydrate from an existing CDRecipe for editing.
    static func from(recipe: CDRecipe) -> RecipeFormData {
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
            servings: Int(recipe.servings),
            prepTimeMinutes: Int(recipe.prepTimeMinutes),
            cookTimeMinutes: Int(recipe.cookTimeMinutes),
            sourceURL: recipe.sourceDetail ?? "",
            category: recipe.category
        )
    }
}
