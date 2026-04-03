//
//  RecipeListView.swift
//  FluffyList
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import CoreData

/// Shows all recipes in a searchable, scrollable list.
/// This is the main view for the Recipes tab.
struct RecipeListView: View {
    // @FetchRequest automatically fetches all CDRecipe objects from Core Data
    // and re-renders this view whenever recipes change.
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDRecipe.name, ascending: true)]) private var recipes: FetchedResults<CDRecipe>
    @Environment(\.managedObjectContext) private var viewContext

    @State private var searchText = ""
    @State private var showingAddRecipe = false
    @State private var showingSettings = false
    @State private var showingIngredientSearch = false
    @State private var selectedCategory: RecipeCategory? = nil
    @State private var showFavoritesOnly = false

    /// Filter recipes based on search text, category, and favorites
    var filteredRecipes: [CDRecipe] {
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
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                }
                .onDelete(perform: deleteRecipes)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.fluffyBackground)
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
                .background(Color.fluffyNavBar)
            }
            .navigationTitle("Recipes")
            // This tells SwiftUI: "when someone taps a NavigationLink
            // with a CDRecipe value, show RecipeDetailView"
            .navigationDestination(for: CDRecipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }

            .searchable(text: $searchText, prompt: "Search recipes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingIngredientSearch = true }) {
                        Image(systemName: "fork.knife")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddRecipe = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingAddRecipe) {
                AddEditRecipeView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingIngredientSearch) {
                IngredientSearchView()
            }
            // Show a helpful message when there are no recipes
            .overlay { emptyStateOverlay }
        }
    }

    @ViewBuilder
    private var emptyStateOverlay: some View {
        if recipes.isEmpty {
            ContentUnavailableView {
                Label("Start by adding your first recipe", systemImage: "book")
            } description: {
                Text("Scan a cookbook, paste a link, or add one manually")
            } actions: {
                Button("Add Recipe") {
                    showingAddRecipe = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.fluffyAccent)
            }
        } else if filteredRecipes.isEmpty {
            ContentUnavailableView(
                "No Matches",
                systemImage: "magnifyingglass",
                description: Text("Try a different filter or search term")
            )
        }
    }

    private func deleteRecipes(at offsets: IndexSet) {
        for index in offsets {
            viewContext.delete(filteredRecipes[index])
        }
        try? viewContext.save()
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
            .background(isActive ? Color.fluffyAccent : Color.fluffyNavBar)
            .foregroundStyle(isActive ? .white : Color.fluffyPrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A single row in the recipe list — rendered as a card with a category colour stripe.
struct RecipeRowView: View {
    let recipe: CDRecipe

    var body: some View {
        HStack(spacing: 0) {
            // 3 pt left stripe coloured by meal category
            Rectangle()
                .fill(recipe.category.stripeColor)
                .frame(width: 3)

            // Card content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recipe.name)
                        .font(.headline)
                        .foregroundStyle(Color.fluffyPrimary)
                    if recipe.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                HStack {
                    Text(recipe.category.rawValue)
                        .font(.caption)
                        .foregroundStyle(Color.fluffySecondary)
                    if let avg = recipe.averageRating {
                        RecipeRowStarView(rating: avg)
                    }
                    Spacer()
                    Text("\(recipe.ingredientsList.count) ingredients")
                        .font(.caption)
                        .foregroundStyle(Color.fluffySecondary)
                }
                .lineLimit(1)
                // "Added by" byline — shown only for recipes where the creator was recorded.
                if let name = recipe.addedByName, !name.isEmpty {
                    Text("Added by \(name)")
                        .font(.caption2)
                        .foregroundStyle(Color.fluffySecondary.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color.fluffyCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.fluffyBorder, lineWidth: 0.5)
        )
    }
}

/// Small inline star display for recipe list rows.
private struct RecipeRowStarView: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: Double(star) <= rating ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

#Preview {
    RecipeListView()
        .environment(\.managedObjectContext, NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType))
}
