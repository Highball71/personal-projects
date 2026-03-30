//
//  RecipeFormViewModel.swift
//  FluffyList
//
//  Owns all form state for adding or editing a recipe.
//  Extracted from AddEditRecipeView to keep the view thin.

import SwiftUI
import CoreData

@Observable
final class RecipeFormViewModel {
    // Form fields
    var name: String = ""
    var category: RecipeCategory = .dinner
    var servings: Int = 4
    var prepTimeMinutes: Int = 30
    var cookTimeMinutes: Int = 0
    var instructions: String = ""
    var ingredientRows: [IngredientFormData] = []
    var sourceType: RecipeSource?
    var sourceDetail: String = ""

    // The recipe being edited, or nil for add mode.
    private(set) var recipeToEdit: CDRecipe?

    var isEditing: Bool { recipeToEdit != nil }

    init(recipe: CDRecipe? = nil) {
        self.recipeToEdit = recipe
        if let recipe {
            name = recipe.name
            category = recipe.category
            servings = Int(recipe.servings)
            prepTimeMinutes = Int(recipe.prepTimeMinutes)
            cookTimeMinutes = Int(recipe.cookTimeMinutes)
            instructions = recipe.instructions
            ingredientRows = recipe.ingredientsList.map { ingredient in
                IngredientFormData(
                    name: ingredient.name,
                    quantity: ingredient.quantity,
                    unit: ingredient.unit,
                    quantityText: FractionFormatter.formatAsFraction(ingredient.quantity)
                )
            }
            sourceType = recipe.sourceType
            sourceDetail = recipe.sourceDetail ?? ""
        }
    }

    func validate() -> Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && servings >= 1
    }

    /// Save or update the recipe in the given Core Data context.
    func save(to context: NSManagedObjectContext, addedBy: String?) {
        let validIngredients = ingredientRows
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }

        if let recipe = recipeToEdit {
            // Update existing recipe
            recipe.name = name
            recipe.category = category
            recipe.servings = Int16(servings)
            recipe.prepTimeMinutes = Int16(prepTimeMinutes)
            recipe.cookTimeMinutes = Int16(cookTimeMinutes)
            recipe.instructions = instructions
            recipe.sourceType = sourceType
            recipe.sourceDetail = sourceDetail.isEmpty ? nil : sourceDetail

            // Replace all ingredients: delete old, add new
            for ingredient in recipe.ingredientsList {
                context.delete(ingredient)
            }
            recipe.ingredients = nil

            // Add new ingredients
            for data in validIngredients {
                let ingredient = CDIngredient(context: context)
                ingredient.id = UUID()
                ingredient.name = data.name
                ingredient.quantity = data.quantity
                ingredient.unitRaw = data.unit.rawValue
                ingredient.recipe = recipe
            }
        } else {
            // Create new recipe
            let recipe = CDRecipe(context: context)
            recipe.id = UUID()
            recipe.name = name
            recipe.categoryRaw = category.rawValue
            recipe.servings = Int16(servings)
            recipe.prepTimeMinutes = Int16(prepTimeMinutes)
            recipe.cookTimeMinutes = Int16(cookTimeMinutes)
            recipe.instructions = instructions
            recipe.dateCreated = Date()
            recipe.isFavorite = false
            recipe.sourceType = sourceType
            recipe.sourceDetail = sourceDetail.isEmpty ? nil : sourceDetail
            recipe.addedByName = addedBy

            // Link to the default household so it's included in the share.
            let householdRequest = CDHousehold.fetchRequest()
            householdRequest.fetchLimit = 1
            recipe.household = (try? context.fetch(householdRequest))?.first

            // Add ingredients
            for data in validIngredients {
                let ingredient = CDIngredient(context: context)
                ingredient.id = UUID()
                ingredient.name = data.name
                ingredient.quantity = data.quantity
                ingredient.unitRaw = data.unit.rawValue
                ingredient.recipe = recipe
            }
        }

        try? context.save()
    }

    /// Populate form fields from an extracted recipe (photo scan, URL import, or search).
    func populateFrom(_ extracted: ExtractedRecipe, sourceURL: String? = nil, sourceType: RecipeSource? = nil) {
        name = extracted.name
        category = extracted.recipeCategory
        servings = extracted.servingsInt
        prepTimeMinutes = extracted.prepTimeMinutesInt
        cookTimeMinutes = extracted.cookTimeMinutesInt
        instructions = extracted.instructionsText
        ingredientRows = extracted.ingredientFormRows

        if let sourceType {
            self.sourceType = sourceType
        }
        if let sourceURL {
            self.sourceDetail = sourceURL
        } else if let source = extracted.source {
            self.sourceDetail = source
        }
    }

    /// Placeholder text for the source detail field.
    var sourcePlaceholder: String {
        switch sourceType {
        case .cookbook: "Book title, p. 42"
        case .website: "https://..."
        case .photo:   "Cookbook name"
        case .url:     "https://..."
        case .other:   "Where is this from?"
        case nil:      ""
        }
    }
}
