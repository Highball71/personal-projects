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
    var name: String = ""
    var category: RecipeCategory = RecipeCategory.dinner
    var servings: Int = 4
    var prepTimeMinutes: Int = 30
    var cookTimeMinutes: Int = 0
    var instructions: String = ""
    var dateCreated: Date = Date()
    var isFavorite: Bool = false

    // Where this recipe came from (cookbook, website, photo, etc.).
    // Optional — older or manually entered recipes may not have a source.
    var sourceType: RecipeSource?
    var sourceDetail: String?

    // .cascade means: when you delete a recipe, its ingredients
    // are automatically deleted too. No orphaned data.
    // Optional because CloudKit requires all relationships to be optional.
    // Inverse is declared on Ingredient.recipe.
    @Relationship(deleteRule: .cascade)
    var ingredients: [Ingredient]?

    // .nullify means: if a recipe is deleted, the meal plan entries
    // stay but their recipe becomes nil (an empty slot).
    // Inverse is declared on MealPlan.recipe.
    @Relationship(deleteRule: .nullify)
    var mealPlans: [MealPlan]?

    /// Non-optional accessor — returns the ingredients array or empty if nil.
    /// Use this throughout the app so we don't need nil checks everywhere.
    var ingredientsList: [Ingredient] {
        get { ingredients ?? [] }
        set { ingredients = newValue }
    }

    init(
        name: String,
        category: RecipeCategory = .dinner,
        servings: Int = 4,
        prepTimeMinutes: Int = 30,
        cookTimeMinutes: Int = 0,
        instructions: String = "",
        ingredients: [Ingredient] = [],
        sourceType: RecipeSource? = nil,
        sourceDetail: String? = nil
    ) {
        self.name = name
        self.category = category
        self.servings = servings
        self.prepTimeMinutes = prepTimeMinutes
        self.cookTimeMinutes = cookTimeMinutes
        self.instructions = instructions
        self.ingredients = ingredients
        self.dateCreated = Date()
        self.sourceType = sourceType
        self.sourceDetail = sourceDetail
    }
}
