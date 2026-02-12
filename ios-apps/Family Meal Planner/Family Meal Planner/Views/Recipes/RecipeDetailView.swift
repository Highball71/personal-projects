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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Category", value: recipe.category.rawValue)
                LabeledContent("Servings", value: "\(recipe.servings)")
                LabeledContent("Prep Time", value: "\(recipe.prepTimeMinutes) minutes")
                if recipe.cookTimeMinutes > 0 {
                    LabeledContent("Cook Time", value: "\(recipe.cookTimeMinutes) minutes")
                }
            }

            Section("Ingredients") {
                if recipe.ingredientsList.isEmpty {
                    Text("No ingredients added")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recipe.ingredientsList) { ingredient in
                        Text(formatIngredientDisplay(ingredient))
                    }
                }
            }

            if !recipe.instructions.isEmpty {
                Section("Instructions") {
                    Text(recipe.instructions)
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

            Section {
                Button("Delete Recipe", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(recipe.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditSheet = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    recipe.isFavorite.toggle()
                } label: {
                    Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(recipe.isFavorite ? .red : .secondary)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditRecipeView(recipeToEdit: recipe)
        }
        .alert("Delete this recipe?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(recipe)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This can't be undone.")
        }
    }

    /// Format a single ingredient for display.
    /// "to taste" items: "Salt, to taste"
    /// "none" unit: "3 eggs"
    /// Normal: "1 1/2 cups all-purpose flour"
    private func formatIngredientDisplay(_ ingredient: Ingredient) -> String {
        if ingredient.unit == .toTaste {
            return "\(ingredient.name), to taste"
        }
        let qty = FractionFormatter.formatAsFraction(ingredient.quantity)
        if ingredient.unit == .none {
            return "\(qty) \(ingredient.name)"
        }
        return "\(qty) \(ingredient.unit.displayName) \(ingredient.name)"
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
