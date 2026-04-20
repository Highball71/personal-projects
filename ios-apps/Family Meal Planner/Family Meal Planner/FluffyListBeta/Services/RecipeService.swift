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
import UIKit

@MainActor
final class RecipeService: ObservableObject {
    @Published var recipes: [RecipeRow] = []
    /// Map of recipe ID → its ingredient names, lowercased for search.
    /// Populated alongside `recipes` on every `fetchRecipes()` call.
    @Published var ingredientsByRecipeID: [UUID: [String]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Non-error notice raised by background actions (e.g. duplicate
    /// recipe detected on save). UI surfaces should consume this and
    /// reset it to nil after displaying.
    @Published var infoMessage: String?

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

    /// Normalize a recipe name for duplicate detection: trim leading/
    /// trailing whitespace, collapse case. Mirrors the planned DB
    /// uniqueness key `lower(btrim(name))`.
    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Look up an existing recipe in the current household by
    /// normalized name. Queries Supabase directly (not the local
    /// cache) so callers can rely on the result for routing decisions
    /// like the extraction-duplicate dialog. Returns nil if no match
    /// or the lookup fails.
    func findRecipeByName(_ name: String) async -> RecipeRow? {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else { return nil }
        let normalized = Self.normalizedName(name)
        guard !normalized.isEmpty else { return nil }
        do {
            let rows: [RecipeRow] = try await supabase
                .from("recipes")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .execute()
                .value
            return rows.first { Self.normalizedName($0.name) == normalized }
        } catch {
            Logger.supabase.warning("findRecipeByName: lookup failed — \(error.localizedDescription)")
            return nil
        }
    }

    /// Add a new recipe with all structured fields + ingredients.
    ///
    /// **Duplicate prevention:** before inserting, we look up an
    /// existing recipe in the same household whose normalized name
    /// matches. If found, we do **not** insert a second row and we do
    /// **not** merge the incoming fields/ingredients into the existing
    /// recipe — silently overwriting user-edited data would be worse
    /// than the duplicate it prevents. We return the existing row and
    /// raise `infoMessage` so the UI can surface a friendly toast.
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
        sourceImagePath: String? = nil,
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

        // Duplicate check — query the DB rather than the local cache so
        // we catch recipes added in another session/device that haven't
        // been fetched yet. The household-scoped read is cheap.
        let normalized = Self.normalizedName(name)
        if !normalized.isEmpty {
            do {
                let existingForHousehold: [RecipeRow] = try await supabase
                    .from("recipes")
                    .select()
                    .eq("household_id", value: householdID.uuidString)
                    .execute()
                    .value

                if let match = existingForHousehold.first(where: { Self.normalizedName($0.name) == normalized }) {
                    Logger.supabase.info("addRecipe: duplicate detected — returning existing id=\(match.id.uuidString) name=\"\(match.name)\" instead of inserting")
                    infoMessage = "A recipe called \"\(match.name)\" already exists. Opened the existing one."
                    isLoading = false
                    return match
                }
            } catch {
                // A failed lookup shouldn't block the save — log and
                // fall through to insert. The DB-level UNIQUE index
                // (planned migration 010) is the ultimate safety net.
                Logger.supabase.warning("addRecipe: duplicate lookup failed — \(error.localizedDescription); proceeding with insert")
            }
        }

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
                sourceDetail: sourceDetail,
                sourceImagePath: sourceImagePath
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
        sourceImagePath: String? = nil,
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
                sourceDetail: sourceDetail,
                sourceImagePath: sourceImagePath
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

    /// Permanently delete a recipe row from Supabase. Verifies with a
    /// follow-up SELECT that the row is actually gone (catches the
    /// silent-no-op case where RLS grants SELECT but not DELETE, or
    /// where a foreign key from another table blocks the delete).
    /// Refreshes `recipes` from the DB instead of mutating it locally,
    /// so the in-memory list always reflects the authoritative state.
    /// Returns true only when the row is verified gone.
    @discardableResult
    func deleteRecipe(_ id: UUID) async -> Bool {
        Logger.supabase.info("deleteRecipe: requesting delete id=\(id.uuidString)")

        // 1. Issue the delete with .select() so the server returns the
        //    rows it actually removed. Without .select() the call would
        //    succeed silently even when zero rows were affected.
        let deletedIDs: [UUID]
        do {
            let deleted: [RecipeRow] = try await supabase
                .from("recipes")
                .delete()
                .eq("id", value: id.uuidString)
                .select()
                .execute()
                .value
            deletedIDs = deleted.map(\.id)
            Logger.supabase.info("deleteRecipe: server reported \(deletedIDs.count) row(s) deleted for id=\(id.uuidString)")
        } catch {
            // FK violations (e.g., a meal_plans row still referencing
            // this recipe without ON DELETE behavior) land here.
            Logger.supabase.error("deleteRecipe: failed id=\(id.uuidString) — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            await fetchRecipes()
            return false
        }

        // 2. Verify the row is gone by reading it back directly.
        let stillThere: [RecipeRow]
        do {
            stillThere = try await supabase
                .from("recipes")
                .select()
                .eq("id", value: id.uuidString)
                .execute()
                .value
        } catch {
            Logger.supabase.error("deleteRecipe: post-delete verify lookup failed — \(error.localizedDescription)")
            stillThere = []
        }

        if !stillThere.isEmpty {
            Logger.supabase.error("deleteRecipe: row still present after delete id=\(id.uuidString) (likely RLS blocked the DELETE or a foreign key reference is preventing it)")
            errorMessage = "Couldn't delete this recipe. It may be referenced elsewhere or your account doesn't have delete permission."
            await fetchRecipes()
            return false
        }

        Logger.supabase.info("deleteRecipe: verified gone id=\(id.uuidString)")

        // 3. Refresh from DB rather than mutating the cache locally —
        //    fetchRecipes is the single source of truth for `recipes`
        //    and `ingredientsByRecipeID`.
        await fetchRecipes()
        return true
    }

    // MARK: - Update

    // MARK: - Image Upload

    /// Resize an image to max 1200px wide, compress as JPEG, upload to
    /// Supabase Storage, and return the storage path. Returns nil on failure.
    func uploadRecipeImage(_ image: UIImage, recipeID: UUID) async -> String? {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.error("uploadRecipeImage: no household ID")
            return nil
        }

        // Resize to max 1200px wide, preserving aspect ratio.
        let maxWidth: CGFloat = 1200
        let resized: UIImage
        if image.size.width > maxWidth {
            let scale = maxWidth / image.size.width
            let newSize = CGSize(width: maxWidth, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            resized = image
        }

        guard let data = resized.jpegData(compressionQuality: 0.8) else {
            Logger.supabase.error("uploadRecipeImage: JPEG compression failed")
            return nil
        }

        let path = "\(householdID.uuidString)/\(recipeID.uuidString)/source.jpg"
        Logger.supabase.info("uploadRecipeImage: uploading \(data.count) bytes to \(path)")

        do {
            try await supabase.storage
                .from("recipe-images")
                .upload(
                    path,
                    data: data,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )

            Logger.supabase.info("uploadRecipeImage: success")
            return path
        } catch {
            Logger.supabase.error("uploadRecipeImage: failed — \(error.localizedDescription)")
            return nil
        }
    }

    /// Upload a homemade photo for a recipe. Same resize/compress as source
    /// images, but stored at the /homemade.jpg path.
    func uploadHomemadeImage(_ image: UIImage, recipeID: UUID) async -> String? {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.error("uploadHomemadeImage: no household ID")
            return nil
        }

        let maxWidth: CGFloat = 1200
        let resized: UIImage
        if image.size.width > maxWidth {
            let scale = maxWidth / image.size.width
            let newSize = CGSize(width: maxWidth, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            resized = image
        }

        guard let data = resized.jpegData(compressionQuality: 0.8) else {
            Logger.supabase.error("uploadHomemadeImage: JPEG compression failed")
            return nil
        }

        let path = "\(householdID.uuidString)/\(recipeID.uuidString)/homemade.jpg"
        Logger.supabase.info("uploadHomemadeImage: uploading \(data.count) bytes to \(path)")

        do {
            try await supabase.storage
                .from("recipe-images")
                .upload(
                    path,
                    data: data,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )

            Logger.supabase.info("uploadHomemadeImage: success")
            return path
        } catch {
            Logger.supabase.error("uploadHomemadeImage: failed — \(error.localizedDescription)")
            return nil
        }
    }

    /// Set the homemade_image_path on a recipe row.
    func setHomemadeImagePath(_ path: String, recipeID: UUID) async {
        do {
            try await supabase
                .from("recipes")
                .update(["homemade_image_path": path])
                .eq("id", value: recipeID.uuidString)
                .execute()
            Logger.supabase.info("setHomemadeImagePath: set on recipe \(recipeID.uuidString)")
        } catch {
            Logger.supabase.error("setHomemadeImagePath: failed — \(error.localizedDescription)")
        }
    }

    /// Lightweight update to set just the source_image_path on a recipe row.
    func setSourceImagePath(_ path: String, recipeID: UUID) async {
        do {
            try await supabase
                .from("recipes")
                .update(["source_image_path": path])
                .eq("id", value: recipeID.uuidString)
                .execute()
            Logger.supabase.info("setSourceImagePath: set on recipe \(recipeID.uuidString)")
        } catch {
            Logger.supabase.error("setSourceImagePath: failed — \(error.localizedDescription)")
        }
    }

    /// Delete the source image from Supabase Storage for a recipe.
    func deleteRecipeImage(recipeID: UUID) async {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else { return }

        let path = "\(householdID.uuidString)/\(recipeID.uuidString)/source.jpg"
        do {
            try await supabase.storage
                .from("recipe-images")
                .remove(paths: [path])
            Logger.supabase.info("deleteRecipeImage: removed \(path)")
        } catch {
            Logger.supabase.error("deleteRecipeImage: failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Favorite

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
