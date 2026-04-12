//
//  SupabaseRecipeFormViewModel.swift
//  FluffyList
//
//  Owns all form state for adding a recipe via Supabase.
//  Mirrors RecipeFormViewModel but saves through RecipeService
//  instead of Core Data.
//
//  Reuses the shared IngredientFormData struct for ingredient rows
//  and the shared enums (RecipeCategory, RecipeSource, IngredientUnit).
//

import Foundation
import os

@MainActor @Observable
final class SupabaseRecipeFormViewModel {
    // Form fields
    var name: String = ""
    var category: RecipeCategory = .dinner
    var servings: Int = 4
    var prepTimeMinutes: Int = 30
    var cookTimeMinutes: Int = 0
    var instructions: String = ""
    var ingredientRows: [IngredientFormData] = [IngredientFormData()]
    var sourceType: RecipeSource?
    var sourceDetail: String = ""

    // Save state
    var isSaving: Bool = false
    var saveError: String?

    // MARK: - Validation

    func validate() -> Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && servings >= 1
    }

    // MARK: - Save

    /// Save the recipe to Supabase via RecipeService.
    /// Returns true on success, false on failure.
    func save(
        recipeService: RecipeService
    ) async -> Bool {
        guard validate() else { return false }

        isSaving = true
        saveError = nil

        Logger.supabase.info("SupabaseRecipeFormVM: saving \"\(self.name)\"")

        // Only name + household_id are sent — other fields are collected
        // by the form but not persisted until the schema supports them.
        let result = await recipeService.addRecipe(
            name: name.trimmingCharacters(in: .whitespaces)
        )

        if result != nil {
            Logger.supabase.info("SupabaseRecipeFormVM: save succeeded")
            isSaving = false
            return true
        } else {
            Logger.supabase.error("SupabaseRecipeFormVM: save failed — \(recipeService.errorMessage ?? "unknown")")
            saveError = recipeService.errorMessage ?? "Failed to save recipe."
            isSaving = false
            return false
        }
    }

    // MARK: - Source Placeholder

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
