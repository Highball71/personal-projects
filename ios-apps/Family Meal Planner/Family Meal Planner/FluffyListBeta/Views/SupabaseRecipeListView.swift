//
//  SupabaseRecipeListView.swift
//  FluffyList
//
//  Recipe list backed by Supabase instead of Core Data @FetchRequest.
//  Tap a recipe to edit, swipe to delete, swipe leading to favorite.
//

import SwiftUI

struct SupabaseRecipeListView: View {
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var householdService: HouseholdService
    @EnvironmentObject private var authService: AuthService

    @State private var showingAddRecipe = false
    @State private var showingHouseholdInfo = false
    @State private var editingRecipe: RecipeRow?
    @State private var editingIngredients: [RecipeIngredientRow] = []

    var body: some View {
        NavigationStack {
            Group {
                if recipeService.isLoading && recipeService.recipes.isEmpty {
                    ProgressView("Loading recipes...")
                } else if recipeService.recipes.isEmpty {
                    emptyState
                } else {
                    recipeList
                }
            }
            .navigationTitle("Recipes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingHouseholdInfo = true
                    } label: {
                        Image(systemName: "house.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddRecipe = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRecipe) {
                SupabaseAddRecipeView()
            }
            .sheet(item: $editingRecipe) { recipe in
                SupabaseAddRecipeView(recipe: recipe, ingredients: editingIngredients)
            }
            .sheet(isPresented: $showingHouseholdInfo) {
                HouseholdInfoView()
            }
            .refreshable {
                await recipeService.fetchRecipes()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(Color.fluffySecondary)

            Text("No recipes yet")
                .font(.title3)
                .foregroundStyle(Color.fluffyPrimary)

            Text("Tap + to add your first recipe.")
                .font(.subheadline)
                .foregroundStyle(Color.fluffySecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Recipe List

    private var recipeList: some View {
        List {
            ForEach(recipeService.recipes) { recipe in
                Button {
                    Task { await openEdit(recipe) }
                } label: {
                    recipeRow(recipe)
                }
                .tint(Color.fluffyPrimary)
            }
            .onDelete { offsets in
                Task {
                    for index in offsets {
                        let recipe = recipeService.recipes[index]
                        await recipeService.deleteRecipe(recipe.id)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func recipeRow(_ recipe: RecipeRow) -> some View {
        HStack(spacing: 12) {
            // Category stripe
            RoundedRectangle(cornerRadius: 2)
                .fill(recipe.recipeCategory.stripeColor)
                .frame(width: 3, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.headline)
                    .foregroundStyle(Color.fluffyPrimary)

                Text(recipe.category.capitalized)
                    .font(.caption)
                    .foregroundStyle(Color.fluffySecondary)
            }

            Spacer()

            if recipe.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.fluffyAccent)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .leading) {
            Button {
                Task { await recipeService.toggleFavorite(recipe) }
            } label: {
                Image(systemName: recipe.isFavorite ? "heart.slash" : "heart.fill")
            }
            .tint(Color.fluffyAccent)
        }
    }

    // MARK: - Edit

    private func openEdit(_ recipe: RecipeRow) async {
        editingIngredients = await recipeService.fetchIngredients(for: recipe.id)
        editingRecipe = recipe
    }
}
