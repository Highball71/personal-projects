//
//  SupabaseRecipeFormViewModel.swift
//  FluffyList
//
//  Owns all form state for adding or editing a recipe via Supabase.
//  Reuses the shared IngredientFormData struct for ingredient rows
//  and the shared enums (RecipeCategory, RecipeSource, IngredientUnit).
//

import Foundation
import os
import UIKit

@MainActor @Observable
final class SupabaseRecipeFormViewModel {
    // Form fields
    var name: String = ""
    var category: RecipeCategory = .dinner
    var servings: Int = 4
    var prepTimeMinutes: Int = 30
    var cookTimeMinutes: Int = 0
    var instructions: String = ""
    var notes: String = ""
    var ingredientRows: [IngredientFormData] = [IngredientFormData()]
    var sourceType: RecipeSource?
    var sourceDetail: String = ""

    // Image state
    /// A new image picked by the user (not yet uploaded).
    var sourceImage: UIImage?
    /// The current storage path for the source image (from DB or after upload).
    var sourceImagePath: String?
    /// True if the user explicitly removed the image.
    var sourceImageRemoved = false

    // Save state
    var isSaving: Bool = false
    var saveError: String?

    // Edit mode
    private(set) var recipeID: UUID?
    var isEditing: Bool { recipeID != nil }

    // MARK: - Init

    /// Add mode — blank form.
    init() {}

    /// Edit mode — populate from an existing recipe + its ingredients.
    init(recipe: RecipeRow, ingredients: [RecipeIngredientRow]) {
        recipeID = recipe.id
        name = recipe.name
        category = RecipeCategory(rawValue: recipe.category) ?? .dinner
        servings = recipe.servings
        prepTimeMinutes = recipe.prepTimeMinutes
        cookTimeMinutes = recipe.cookTimeMinutes
        instructions = recipe.instructions
        notes = recipe.notes
        sourceType = recipe.sourceType.flatMap { RecipeSource(rawValue: $0) }
        sourceDetail = recipe.sourceDetail ?? ""
        sourceImagePath = recipe.sourceImagePath

        let sorted = ingredients.sorted { $0.sortOrder < $1.sortOrder }
        if sorted.isEmpty {
            ingredientRows = [IngredientFormData()]
        } else {
            ingredientRows = sorted.map { row in
                IngredientFormData(
                    name: row.name,
                    quantity: row.quantity,
                    unit: IngredientUnit(rawValue: row.unit) ?? .piece,
                    quantityText: FractionFormatter.formatAsFraction(row.quantity)
                )
            }
        }
    }

    // MARK: - Populate from extraction

    /// Fill the form from a Claude Vision API extraction result.
    /// Uses ExtractedRecipe's existing conversion helpers.
    func populateFrom(_ extracted: ExtractedRecipe, sourceType: RecipeSource? = nil) {
        name = extracted.name
        category = extracted.recipeCategory
        servings = extracted.servingsInt
        prepTimeMinutes = extracted.prepTimeMinutesInt
        cookTimeMinutes = extracted.cookTimeMinutesInt
        instructions = extracted.instructionsText
        ingredientRows = extracted.ingredientFormRows.isEmpty
            ? [IngredientFormData()]
            : extracted.ingredientFormRows

        // Populate the notes field from the extracted description
        // (recipe headnote) and notes (Notes/Tips/Storage/etc.). Both
        // are optional. When both are present, separate with a blank
        // line. Earlier the form's notes field stayed blank even when
        // the source page had a clearly labeled Notes section.
        notes = composedNotes(
            description: extracted.description,
            notes: extracted.notes
        )

        if let sourceType {
            self.sourceType = sourceType
        }
        if let source = extracted.source, !source.isEmpty {
            self.sourceDetail = source
        }
    }

    private func composedNotes(description: String?, notes: String?) -> String {
        let parts: [String] = [description, notes]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: "\n\n")
    }

    // MARK: - Switch into edit mode (extraction-duplicate flow)

    /// Convert the form into edit mode pointing at an existing recipe,
    /// preserving any fields the extraction did not provide. Used when
    /// the user chose "Update Existing Recipe" after an import detected
    /// a name collision — we want the extracted name/category/servings/
    /// times/instructions/ingredients to overwrite, but the user's
    /// previously-entered notes, source detail, and card image to stay.
    func switchToUpdate(of existing: RecipeRow) {
        recipeID = existing.id
        if notes.isEmpty { notes = existing.notes }
        if sourceImagePath == nil { sourceImagePath = existing.sourceImagePath }
        if sourceDetail.isEmpty { sourceDetail = existing.sourceDetail ?? "" }
    }

    // MARK: - Validation

    func validate() -> Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && servings >= 1
    }

    // MARK: - Save

    /// Save the recipe to Supabase via RecipeService.
    /// Handles both create (new) and update (edit) paths.
    /// Returns true on success, false on failure.
    func save(recipeService: RecipeService) async -> Bool {
        guard validate() else { return false }

        isSaving = true
        saveError = nil

        let validIngredients = ingredientRows
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }

        let ingredientInserts = validIngredients.enumerated().map { index, row in
            RecipeIngredientInsert(
                name: row.name.trimmingCharacters(in: .whitespaces),
                quantity: row.quantity,
                unit: row.unit.rawValue,
                sortOrder: index
            )
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        // Resolve the image path to save:
        //   - If user removed the image, clear it
        //   - If user picked a new image, upload after we have a recipe ID
        //   - Otherwise, keep the existing path
        let imagePath = sourceImageRemoved ? nil : sourceImagePath

        Logger.supabase.info("SupabaseRecipeFormVM: \(self.isEditing ? "updating" : "creating") \"\(trimmedName)\" category=\(self.category.rawValue) ingredients=\(ingredientInserts.count)")

        let success: Bool

        if let editID = recipeID {
            // Upload new image first if we have one (we already know the recipe ID).
            var pathForUpdate = imagePath
            if let newImage = sourceImage {
                if let uploaded = await recipeService.uploadRecipeImage(newImage, recipeID: editID) {
                    pathForUpdate = uploaded
                    sourceImagePath = uploaded
                    sourceImage = nil
                }
            }

            // If image was removed, also delete from storage.
            if sourceImageRemoved {
                await recipeService.deleteRecipeImage(recipeID: editID)
            }

            success = await recipeService.updateRecipe(
                id: editID,
                name: trimmedName,
                category: category.rawValue,
                servings: servings,
                prepTimeMinutes: prepTimeMinutes,
                cookTimeMinutes: cookTimeMinutes,
                instructions: trimmedInstructions,
                notes: trimmedNotes,
                sourceType: sourceType?.rawValue,
                sourceDetail: sourceDetail.isEmpty ? nil : sourceDetail,
                sourceImagePath: pathForUpdate,
                ingredients: ingredientInserts
            )
        } else {
            // Create new recipe (no image path yet — we need the ID first).
            let result = await recipeService.addRecipe(
                name: trimmedName,
                category: category.rawValue,
                servings: servings,
                prepTimeMinutes: prepTimeMinutes,
                cookTimeMinutes: cookTimeMinutes,
                instructions: trimmedInstructions,
                notes: trimmedNotes,
                sourceType: sourceType?.rawValue,
                sourceDetail: sourceDetail.isEmpty ? nil : sourceDetail,
                ingredients: ingredientInserts
            )
            success = result != nil
            if let result {
                recipeID = result.id
                Logger.supabase.info("SupabaseRecipeFormVM: transitioned to edit mode id=\(result.id.uuidString)")

                // Now upload the image if one was picked and update the recipe with the path.
                if let newImage = sourceImage {
                    if let uploaded = await recipeService.uploadRecipeImage(newImage, recipeID: result.id) {
                        sourceImagePath = uploaded
                        sourceImage = nil
                        await recipeService.setSourceImagePath(uploaded, recipeID: result.id)
                    }
                }
            }
        }

        if success {
            Logger.supabase.info("SupabaseRecipeFormVM: save succeeded")
        } else {
            Logger.supabase.error("SupabaseRecipeFormVM: save failed — \(recipeService.errorMessage ?? "unknown")")
            saveError = recipeService.errorMessage ?? "Failed to save recipe."
        }

        isSaving = false
        return success
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
