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
    @State private var selectedCategory: RecipeCategory? = nil
    @State private var showFavoritesOnly = false

    /// Filter recipes based on search text, category, and favorites
    var filteredRecipes: [Recipe] {
        recipes.filter { recipe in
            // Search text filter
            if !searchText.isEmpty &&
                !recipe.name.localizedCaseInsensitiveContains(searchText) {
                return false
            }
            // Category filter
            if let category = selectedCategory, recipe.category != category {
                return false
            }
            // Favorites filter
            if showFavoritesOnly && !recipe.isFavorite {
                return false
            }
            return true
        }
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
            .listStyle(.plain)
            // Filter chips pinned above the list
            .safeAreaInset(edge: .top) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "All" chip
                        FilterChip(
                            label: "All",
                            isActive: selectedCategory == nil && !showFavoritesOnly
                        ) {
                            selectedCategory = nil
                            showFavoritesOnly = false
                        }

                        // One chip per category
                        ForEach(RecipeCategory.allCases) { category in
                            FilterChip(
                                label: category.rawValue,
                                isActive: selectedCategory == category && !showFavoritesOnly
                            ) {
                                selectedCategory = category
                                showFavoritesOnly = false
                            }
                        }

                        // Favorites chip with heart icon
                        FilterChip(
                            label: "Favorites",
                            systemImage: "heart.fill",
                            isActive: showFavoritesOnly
                        ) {
                            showFavoritesOnly.toggle()
                            if showFavoritesOnly {
                                selectedCategory = nil
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(.bar)
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
                } else if filteredRecipes.isEmpty {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different filter or search term")
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

/// A filter chip button used in the horizontal category bar.
struct FilterChip: View {
    let label: String
    var systemImage: String? = nil
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2)
                }
                Text(label)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color.accentColor : Color(.systemGray5))
            .foregroundStyle(isActive ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A single row in the recipe list, showing name, category, and ingredient count.
struct RecipeRowView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(recipe.name)
                    .font(.headline)
                if recipe.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
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
