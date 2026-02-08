//
//  RecipeDetailView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import SwiftData

/// Read-only detail view showing a recipe's info, ingredients, and instructions.
/// Has an Edit button that opens AddEditRecipeView in edit mode.
struct RecipeDetailView: View {
    let recipe: Recipe
    @State private var showingEditSheet = false

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Category", value: recipe.category.rawValue)
                LabeledContent("Servings", value: "\(recipe.servings)")
                LabeledContent("Prep Time", value: "\(recipe.prepTimeMinutes) minutes")
            }

            Section("Ingredients") {
                if recipe.ingredients.isEmpty {
                    Text("No ingredients added")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recipe.ingredients) { ingredient in
                        HStack {
                            Text(formatQuantity(ingredient.quantity))
                                .foregroundStyle(.secondary)
                            Text(ingredient.unit.rawValue)
                                .foregroundStyle(.secondary)
                            Text(ingredient.name)
                        }
                    }
                }
            }

            if !recipe.instructions.isEmpty {
                Section("Instructions") {
                    Text(recipe.instructions)
                }
            }
        }
        .navigationTitle(recipe.name)
        .toolbar {
            Button("Edit") { showingEditSheet = true }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditRecipeView(recipeToEdit: recipe)
        }
    }

    /// Format quantity to avoid ugly decimals: show "2" instead of "2.0"
    private func formatQuantity(_ value: Double) -> String {
        if value == value.rounded() && value < 1000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(recipe: Recipe(
            name: "Preview Recipe",
            category: .dinner,
            servings: 4,
            prepTimeMinutes: 30,
            instructions: "Cook it up!",
            ingredients: [
                Ingredient(name: "Flour", quantity: 2, unit: .cup),
                Ingredient(name: "Eggs", quantity: 3, unit: .piece)
            ]
        ))
    }
    .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self], inMemory: true)
}
