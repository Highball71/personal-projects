//
//  ExtractedRecipe.swift
//  Family Meal Planner
//

import Foundation

/// The JSON shape Claude returns when extracting a recipe from a photo.
/// Provides computed properties to convert into the app's form data types.
struct ExtractedRecipe: Codable {
    let name: String
    let category: String
    let servings: Int?
    let prepTimeMinutes: Int?
    let ingredients: [ExtractedIngredient]
    let instructions: String

    /// Map Claude's lowercase category string to the app's RecipeCategory enum.
    /// Falls back to .dinner if no match.
    var recipeCategory: RecipeCategory {
        // RecipeCategory rawValues are capitalized ("Dinner", "Side Dish"),
        // but Claude returns lowercase ("dinner", "side").
        // Build a lookup from lowercased case names.
        switch category.lowercased() {
        case "breakfast":  return .breakfast
        case "lunch":      return .lunch
        case "dinner":     return .dinner
        case "snack":      return .snack
        case "dessert":    return .dessert
        case "side":       return .side
        default:           return .dinner
        }
    }

    /// Convert extracted ingredients to IngredientFormData for the recipe form.
    var ingredientFormRows: [IngredientFormData] {
        ingredients.map { extracted in
            IngredientFormData(
                name: extracted.name,
                quantity: extracted.quantity,
                unit: extracted.ingredientUnit
            )
        }
    }
}

/// A single ingredient as extracted by Claude.
struct ExtractedIngredient: Codable {
    let name: String
    let quantity: Double
    let unit: String

    /// Map the unit string to the app's IngredientUnit enum.
    /// Tries exact rawValue match first, then fuzzy aliases.
    var ingredientUnit: IngredientUnit {
        // Exact match against IngredientUnit rawValues
        // (e.g. "cup", "tbsp", "oz", "lb", "g", "L", "mL")
        if let match = IngredientUnit(rawValue: unit) {
            return match
        }

        // Fuzzy matching for common variations
        let normalized = unit.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let aliases: [String: IngredientUnit] = [
            "cups": .cup,
            "tablespoon": .tablespoon, "tablespoons": .tablespoon,
            "tbs": .tablespoon,
            "teaspoon": .teaspoon, "teaspoons": .teaspoon,
            "ounce": .ounce, "ounces": .ounce,
            "pound": .pound, "pounds": .pound,
            "lbs": .pound,
            "gram": .gram, "grams": .gram,
            "liter": .liter, "liters": .liter,
            "l": .liter,
            "milliliter": .milliliter, "milliliters": .milliliter,
            "ml": .milliliter,
            "pinches": .pinch,
            "each": .whole, "item": .whole, "items": .whole,
            "pieces": .piece, "pcs": .piece,
        ]

        return aliases[normalized] ?? .piece
    }
}
