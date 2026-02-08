//
//  AddEditRecipeView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import SwiftData

/// Handles both adding a new recipe and editing an existing one.
/// When `recipeToEdit` is nil → add mode (form starts empty).
/// When `recipeToEdit` has a value → edit mode (form pre-populates).
struct AddEditRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing recipe here to edit it. Leave nil to add a new one.
    var recipeToEdit: Recipe?

    // Form state — these are local copies. Nothing is saved to the
    // database until the user taps "Save".
    @State private var name = ""
    @State private var category: RecipeCategory = .dinner
    @State private var servings = 4
    @State private var prepTimeMinutes = 30
    @State private var instructions = ""
    @State private var ingredientRows: [IngredientFormData] = []

    var isEditing: Bool { recipeToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Recipe Info Section
                Section("Recipe Info") {
                    TextField("Recipe Name", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(RecipeCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }

                    Stepper("Servings: \(servings)", value: $servings, in: 1...20)

                    Stepper(
                        "Prep Time: \(prepTimeMinutes) min",
                        value: $prepTimeMinutes,
                        in: 5...480,
                        step: 5
                    )
                }

                // MARK: - Ingredients Section
                Section("Ingredients") {
                    ForEach($ingredientRows) { $row in
                        IngredientRowView(data: $row)
                    }
                    .onDelete { indexSet in
                        ingredientRows.remove(atOffsets: indexSet)
                    }

                    Button("Add Ingredient") {
                        ingredientRows.append(IngredientFormData())
                    }
                }

                // MARK: - Instructions Section
                Section("Instructions") {
                    // TextEditor gives multi-line text input
                    // (TextField is single-line only)
                    TextEditor(text: $instructions)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle(isEditing ? "Edit Recipe" : "New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRecipe() }
                        // Disable Save if the name is blank
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                // If editing, populate the form with the existing recipe's data
                if let recipe = recipeToEdit {
                    name = recipe.name
                    category = recipe.category
                    servings = recipe.servings
                    prepTimeMinutes = recipe.prepTimeMinutes
                    instructions = recipe.instructions
                    ingredientRows = recipe.ingredients.map { ingredient in
                        IngredientFormData(
                            name: ingredient.name,
                            quantity: ingredient.quantity,
                            unit: ingredient.unit
                        )
                    }
                }
            }
        }
    }

    private func saveRecipe() {
        // Filter out any blank ingredient rows
        let validIngredients = ingredientRows
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { Ingredient(name: $0.name, quantity: $0.quantity, unit: $0.unit) }

        if let recipe = recipeToEdit {
            // Update existing recipe
            recipe.name = name
            recipe.category = category
            recipe.servings = servings
            recipe.prepTimeMinutes = prepTimeMinutes
            recipe.instructions = instructions

            // Replace all ingredients: delete old, add new
            for ingredient in recipe.ingredients {
                modelContext.delete(ingredient)
            }
            recipe.ingredients = validIngredients
        } else {
            // Create brand new recipe
            let recipe = Recipe(
                name: name,
                category: category,
                servings: servings,
                prepTimeMinutes: prepTimeMinutes,
                instructions: instructions,
                ingredients: validIngredients
            )
            modelContext.insert(recipe)
        }

        dismiss()
    }
}

#Preview("Add Recipe") {
    AddEditRecipeView()
        .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self], inMemory: true)
}
