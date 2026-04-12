//
//  SupabaseAddRecipeView.swift
//  FluffyList
//
//  Minimal recipe creation form backed by Supabase.
//  Reuses the existing RecipeCategory enum for category selection.
//

import SwiftUI

struct SupabaseAddRecipeView: View {
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var householdService: HouseholdService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: RecipeCategory = .dinner
    @State private var servings = 4
    @State private var prepTime = 30
    @State private var cookTime = 0
    @State private var instructions = ""
    @State private var ingredients: [IngredientField] = [IngredientField()]

    struct IngredientField: Identifiable {
        let id = UUID()
        var name = ""
        var quantity = 1.0
        var unit = "piece"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe Info") {
                    TextField("Recipe name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(RecipeCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue.capitalized).tag(cat)
                        }
                    }
                    Stepper("Servings: \(servings)", value: $servings, in: 1...20)
                    Stepper("Prep: \(prepTime) min", value: $prepTime, in: 0...240, step: 5)
                    Stepper("Cook: \(cookTime) min", value: $cookTime, in: 0...480, step: 5)
                }

                Section("Ingredients") {
                    ForEach($ingredients) { $ingredient in
                        HStack {
                            TextField("Name", text: $ingredient.name)
                            TextField("Qty", value: $ingredient.quantity, format: .number)
                                .frame(width: 50)
                                .keyboardType(.decimalPad)
                        }
                    }
                    Button("Add Ingredient") {
                        ingredients.append(IngredientField())
                    }
                }

                Section("Instructions") {
                    TextEditor(text: $instructions)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveRecipe() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveRecipe() async {
        // Find the current member's display name.
        let memberName = householdService.members
            .first { $0.userID == SupabaseManager.shared.currentUserID }?
            .displayName

        let ingredientInserts = ingredients
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { RecipeIngredientInsert(name: $0.name, quantity: $0.quantity, unit: $0.unit) }

        let result = await recipeService.addRecipe(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category.rawValue,
            servings: servings,
            prepTimeMinutes: prepTime,
            cookTimeMinutes: cookTime,
            instructions: instructions,
            addedByName: memberName,
            ingredients: ingredientInserts
        )

        if result != nil {
            dismiss()
        }
    }
}
