//
//  RecipeListView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import SwiftData

/// Shows all recipes in a searchable, scrollable list.
/// This is the main view for the Recipes tab.
struct RecipeListView: View {
    // @Query automatically fetches all Recipe objects from SwiftData
    // and re-renders this view whenever recipes change.
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var showingAddRecipe = false

    /// Filter recipes based on the search bar text
    var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return recipes
        }
        return recipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredRecipes) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeRowView(recipe: recipe)
                    }
                }
                .onDelete(perform: deleteRecipes)
            }
            .navigationTitle("Recipes")
            // This tells SwiftUI: "when someone taps a NavigationLink
            // with a Recipe value, show RecipeDetailView"
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .searchable(text: $searchText, prompt: "Search recipes")
            .toolbar {
                Button(action: { showingAddRecipe = true }) {
                    Label("Add Recipe", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAddRecipe) {
                AddEditRecipeView()
            }
            // Show a helpful message when there are no recipes
            .overlay {
                if recipes.isEmpty {
                    ContentUnavailableView(
                        "No Recipes Yet",
                        systemImage: "book",
                        description: Text("Tap + to add your first recipe")
                    )
                }
            }
        }
    }

    private func deleteRecipes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredRecipes[index])
        }
    }
}

/// A single row in the recipe list, showing name, category, and ingredient count.
struct RecipeRowView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading) {
            Text(recipe.name)
                .font(.headline)
            HStack {
                Text(recipe.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(recipe.ingredientsList.count) ingredients")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    RecipeListView()
        .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self], inMemory: true)
}
