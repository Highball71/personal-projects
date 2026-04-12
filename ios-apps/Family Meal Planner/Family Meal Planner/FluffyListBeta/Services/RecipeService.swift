//
//  RecipeService.swift
//  FluffyList
//
//  CRUD for recipes and their ingredients via Supabase.
//  Replaces Core Data @FetchRequest for the Supabase path.
//

import Combine
import Foundation
import Supabase

@MainActor
final class RecipeService: ObservableObject {
    @Published var recipes: [RecipeRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Fetch

    /// Load all recipes for the current household.
    func fetchRecipes() async {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            recipes = []
            return
        }

        isLoading = true

        do {
            recipes = try await supabase
                .from("recipes")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
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

    /// Add a new recipe with ingredients.
    func addRecipe(
        name: String,
        category: String = "dinner",
        servings: Int = 4,
        prepTimeMinutes: Int = 0,
        cookTimeMinutes: Int = 0,
        instructions: String = "",
        sourceType: String? = nil,
        sourceDetail: String? = nil,
        addedByName: String? = nil,
        ingredients: [RecipeIngredientInsert] = []
    ) async -> RecipeRow? {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            errorMessage = "No household selected."
            return nil
        }

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
                sourceType: sourceType,
                sourceDetail: sourceDetail,
                addedByName: addedByName,
                addedByUserID: SupabaseManager.shared.currentUserID
            )

            let rows: [RecipeRow] = try await supabase
                .from("recipes")
                .insert(insert)
                .select()
                .execute()
                .value

            guard let newRecipe = rows.first else {
                errorMessage = "Recipe was not created."
                isLoading = false
                return nil
            }

            // Insert ingredients if any.
            if !ingredients.isEmpty {
                let ingredientsWithRecipeID = ingredients.map {
                    RecipeIngredientInsert(
                        recipeID: newRecipe.id,
                        name: $0.name,
                        quantity: $0.quantity,
                        unit: $0.unit
                    )
                }

                try await supabase
                    .from("recipe_ingredients")
                    .insert(ingredientsWithRecipeID)
                    .execute()
            }

            // Refresh the list.
            await fetchRecipes()
            isLoading = false
            return newRecipe
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
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
