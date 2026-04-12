//
//  SupabaseRecipeListView.swift
//  FluffyList
//
//  Recipe list backed by Supabase instead of Core Data @FetchRequest.
//  Minimal first pass — shows recipes, allows adding and deleting.
//

import SwiftUI

struct SupabaseRecipeListView: View {
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var householdService: HouseholdService
    @EnvironmentObject private var authService: AuthService

    @State private var showingAddRecipe = false
    @State private var showingHouseholdInfo = false

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
                recipeRow(recipe)
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
            Text(recipe.name)
                .font(.headline)
                .foregroundStyle(Color.fluffyPrimary)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
