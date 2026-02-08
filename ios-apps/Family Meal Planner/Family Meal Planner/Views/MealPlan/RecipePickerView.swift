//
//  RecipePickerView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import SwiftData

/// A sheet that lets the user pick a recipe to assign to a meal slot.
/// Presented when the user taps an empty (or filled) meal slot.
struct RecipePickerView: View {
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    /// Called with the selected recipe, then the sheet dismisses.
    let onRecipeSelected: (Recipe) -> Void

    var filteredRecipes: [Recipe] {
        if searchText.isEmpty { return recipes }
        return recipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredRecipes) { recipe in
                Button {
                    onRecipeSelected(recipe)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(recipe.name)
                            .font(.headline)
                        Text(recipe.category.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Choose Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search recipes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if recipes.isEmpty {
                    ContentUnavailableView(
                        "No Recipes",
                        systemImage: "book",
                        description: Text("Add recipes first in the Recipes tab")
                    )
                }
            }
        }
    }
}

#Preview {
    RecipePickerView { recipe in
        print("Selected: \(recipe.name)")
    }
    .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self], inMemory: true)
}
