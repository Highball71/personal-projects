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
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let sourceType = recipe.sourceType {
                Section("Source") {
                    LabeledContent("Type", value: sourceType.rawValue)
                    if let detail = recipe.sourceDetail, !detail.isEmpty {
                        LabeledContent("Details", value: detail)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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
            name: "Spaghetti Bolognese",
            category: .dinner,
            servings: 4,
            prepTimeMinutes: 45,
            instructions: """
            1. Brown the ground beef in a large pan.
            2. Add diced onions and garlic, cook until soft.
            3. Add crushed tomatoes and Italian seasoning.
            4. Simmer for 20 minutes.
            5. Cook spaghetti according to package directions.
            6. Serve sauce over pasta.
            """,
            ingredients: [
                Ingredient(name: "Spaghetti", quantity: 1, unit: .pound),
                Ingredient(name: "Ground beef", quantity: 1, unit: .pound),
                Ingredient(name: "Crushed tomatoes", quantity: 28, unit: .ounce),
                Ingredient(name: "Onion", quantity: 1, unit: .whole),
                Ingredient(name: "Garlic cloves", quantity: 3, unit: .piece),
            ],
            sourceType: .cookbook,
            sourceDetail: "The Joy of Cooking, p. 312"
        ))
    }
    .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self], inMemory: true)
}
