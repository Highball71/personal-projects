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
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Fetch

    /// Load all recipes for the current household.
    func fetchRecipes() async {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.warning("fetchRecipes: no household ID set, returning empty list")
            recipes = []
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
            isLoading = false
        } catch {
            Logger.supabase.error("fetchRecipes: failed — \(error.localizedDescription)")
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

    /// Add a new recipe (name + household_id only — matches actual DB schema).
    /// UI fields like category, servings, etc. are collected by the form
    /// but not sent until the schema supports them.
    func addRecipe(name: String) async -> RecipeRow? {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.error("addRecipe: no household ID — cannot save")
            errorMessage = "No household selected."
            return nil
        }

        Logger.supabase.info("addRecipe: household=\(householdID.uuidString), name=\"\(name)\"")
        isLoading = true
        errorMessage = nil

        do {
            let insert = RecipeInsert(
                householdID: householdID,
                name: name
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

}
