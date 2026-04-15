//
//  RecipeService.swift
//  FluffyList
//
//  CRUD for recipes and their ingredients via Supabase.
//  Replaces Core Data @FetchRequest for the Supabase path.
//

import Combine
import Foundation
import os
import Supabase

@MainActor
final class RecipeService: ObservableObject {
    @Published var recipes: [RecipeRow] = []
    /// Map of recipe ID → its ingredient names, lowercased for search.
    /// Populated alongside `recipes` on every `fetchRecipes()` call.
    @Published var ingredientsByRecipeID: [UUID: [String]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Fetch

    /// Load all recipes for the current household, then load all of
    /// their ingredients so client-side search can match by name.
    func fetchRecipes() async {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.warning("fetchRecipes: no household ID set, returning empty list")
            recipes = []
            ingredientsByRecipeID = [:]
            return
        }

        Logger.supabase.info("fetchRecipes: loading for household \(householdID.uuidString)")
        isLoading = true

        do {
            recipes = try await supabase
                .from("recipes")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            Logger.supabase.info("fetchRecipes: loaded \(self.recipes.count) recipe(s)")

            // Also load all ingredients so search works immediately.
            // RLS on recipe_ingredients already scopes to the household.
            await fetchAllIngredients()

            isLoading = false
        } catch {
            Logger.supabase.error("fetchRecipes: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Fetch every ingredient visible to the current household (RLS
    /// enforces the scoping) and build a lookup map keyed by recipe ID.
    /// Stored names are lowercased so search comparisons are cheap.
    func fetchAllIngredients() async {
        do {
            let allIngredients: [RecipeIngredientRow] = try await supabase
                .from("recipe_ingredients")
                .select()
                .execute()
                .value

            var map: [UUID: [String]] = [:]
            for ingredient in allIngredients {
                map[ingredient.recipeID, default: []].append(ingredient.name.lowercased())
            }
            ingredientsByRecipeID = map

            Logger.supabase.info("fetchAllIngredients: loaded \(allIngredients.count) ingredient(s) across \(map.count) recipe(s)")
        } catch {
            Logger.supabase.error("fetchAllIngredients: failed — \(error.localizedDescription)")
            // Non-fatal: search just won't match ingredients until next
            // successful fetch. Don't surface as user-facing error.
        }
    }

    /// Fetch ingredients for a single recipe.
    func fetchIngredients(for recipeID: UUID) async -> [RecipeIngredientRow] {
        do {
            return try await supabase
                .from("recipe_ingredients")
                .select()
                .eq("recipe_id", value: recipeID.uuidString)
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    // MARK: - Create

    /// Add a new recipe with all structured fields + ingredients.
    func addRecipe(
        name: String,
        category: String = "dinner",
        servings: Int = 4,
        prepTimeMinutes: Int = 0,
        cookTimeMinutes: Int = 0,
        instructions: String = "",
        notes: String = "",
        sourceType: String? = nil,
        sourceDetail: String? = nil,
        ingredients: [RecipeIngredientInsert] = []
    ) async -> RecipeRow? {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.error("addRecipe: no household ID — cannot save")
            errorMessage = "No household selected."
            return nil
        }

        Logger.supabase.info("addRecipe: household=\(householdID.uuidString), name=\"\(name)\", category=\(category), ingredients=\(ingredients.count)")
        isLoading = true
        errorMessage = nil

        do {
            let insert = RecipeInsert(
                householdID: householdID,
                name: name,
                category: category,
                servings: servings,
                prepTimeMinutes: prepTimeMinutes,
                cookTimeMinutes: cookTimeMinutes,
                instructions: instructions,
                notes: notes,
                sourceType: sourceType,
                sourceDetail: sourceDetail
            )

            let rows: [RecipeRow] = try await supabase
                .from("recipes")
                .insert(insert)
                .select()
                .execute()
                .value

            guard let newRecipe = rows.first else {
                Logger.supabase.error("addRecipe: insert returned no rows")
                errorMessage = "Recipe was not created."
                isLoading = false
                return nil
            }

            Logger.supabase.info("addRecipe: saved recipe id=\(newRecipe.id.uuidString)")

            // Insert ingredients if any.
            if !ingredients.isEmpty {
                let ingredientsWithRecipeID = ingredients.map {
                    RecipeIngredientInsert(
                        recipeID: newRecipe.id,
                        name: $0.name,
                        quantity: $0.quantity,
                        unit: $0.unit,
                        sortOrder: $0.sortOrder
                    )
                }

                try await supabase
                    .from("recipe_ingredients")
                    .insert(ingredientsWithRecipeID)
                    .execute()

                Logger.supabase.info("addRecipe: inserted \(ingredients.count) ingredient(s)")
            }

            // Refresh the list.
            Logger.supabase.info("addRecipe: reloading recipe list")
            await fetchRecipes()
            isLoading = false
            return newRecipe
        } catch {
            Logger.supabase.error("addRecipe: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }

    // MARK: - Update

    /// Update an existing recipe's fields and replace its ingredients.
    func updateRecipe(
        id: UUID,
        name: String,
        category: String,
        servings: Int,
        prepTimeMinutes: Int,
        cookTimeMinutes: Int,
        instructions: String,
        notes: String = "",
        sourceType: String?,
        sourceDetail: String?,
        ingredients: [RecipeIngredientInsert]
    ) async -> Bool {
        Logger.supabase.info("updateRecipe: id=\(id.uuidString), name=\"\(name)\", ingredients=\(ingredients.count)")
        isLoading = true
        errorMessage = nil

        do {
            // Update the recipe row.
            let update = RecipeInsert(
                householdID: SupabaseManager.shared.currentHouseholdID ?? UUID(),
                name: name,
                category: category,
                servings: servings,
                prepTimeMinutes: prepTimeMinutes,
                cookTimeMinutes: cookTimeMinutes,
                instructions: instructions,
                notes: notes,
                sourceType: sourceType,
                sourceDetail: sourceDetail
            )

            try await supabase
                .from("recipes")
                .update(update)
                .eq("id", value: id.uuidString)
                .execute()

            // Replace ingredients: delete old, insert new.
            try await supabase
                .from("recipe_ingredients")
                .delete()
                .eq("recipe_id", value: id.uuidString)
                .execute()

            if !ingredients.isEmpty {
                let ingredientsWithRecipeID = ingredients.map {
                    RecipeIngredientInsert(
                        recipeID: id,
                        name: $0.name,
                        quantity: $0.quantity,
                        unit: $0.unit,
                        sortOrder: $0.sortOrder
                    )
                }

                try await supabase
                    .from("recipe_ingredients")
                    .insert(ingredientsWithRecipeID)
                    .execute()
            }

            Logger.supabase.info("updateRecipe: succeeded")
            await fetchRecipes()
            isLoading = false
            return true
        } catch {
            Logger.supabase.error("updateRecipe: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Delete

    func deleteRecipe(_ id: UUID) async {
        do {
            try await supabase
                .from("recipes")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            recipes.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Update

    func toggleFavorite(_ recipe: RecipeRow) async {
        do {
            try await supabase
                .from("recipes")
                .update(["is_favorite": !recipe.isFavorite])
                .eq("id", value: recipe.id.uuidString)
                .execute()

            await fetchRecipes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
