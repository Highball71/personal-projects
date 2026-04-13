//
//  SupabaseRecipeListView.swift
//  FluffyList
//
//  Recipe list backed by Supabase instead of Core Data @FetchRequest.
//  Tap a recipe to edit, swipe to delete, swipe leading to favorite.
//

import os
import SwiftUI

struct SupabaseRecipeListView: View {
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var householdService: HouseholdService
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var mealPlanService: MealPlanService
    @EnvironmentObject private var groceryService: GroceryService

    @State private var showingAddRecipe = false
    @State private var showingHouseholdInfo = false
    @State private var editingRecipe: RecipeRow?
    @State private var editingIngredients: [RecipeIngredientRow] = []
    @State private var searchText = ""
    /// When non-nil, presents the day picker sheet for adding this
    /// recipe to the meal plan.
    @State private var recipeToPlan: RecipeRow?
    @State private var toastMessage: String?

    /// Recipes filtered by the current search query. Matches recipe
    /// name OR any ingredient name (both lowercased, substring match).
    /// When the query is empty, returns all recipes unchanged.
    private var filteredRecipes: [RecipeRow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return recipeService.recipes }

        return recipeService.recipes.filter { recipe in
            if recipe.name.lowercased().contains(query) {
                return true
            }
            if let ingredientNames = recipeService.ingredientsByRecipeID[recipe.id],
               ingredientNames.contains(where: { $0.contains(query) }) {
                return true
            }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recipeService.isLoading && recipeService.recipes.isEmpty {
                    ProgressView("Loading recipes...")
                } else if recipeService.recipes.isEmpty {
                    emptyState
                } else if filteredRecipes.isEmpty {
                    noMatchesState
                } else {
                    recipeList
                }
            }
            .navigationTitle("Recipes")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search name or ingredient"
            )
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
            .sheet(item: $recipeToPlan) { recipe in
                DayPickerSheet(
                    recipe: recipe,
                    onPick: { date in
                        recipeToPlan = nil
                        Task { await addToMealPlan(recipe: recipe, date: date) }
                    },
                    onCancel: {
                        recipeToPlan = nil
                    }
                )
            }
            .sheet(isPresented: $showingHouseholdInfo) {
                HouseholdInfoView()
            }
            .refreshable {
                await recipeService.fetchRecipes()
            }
            .overlay { toastOverlay }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let message = toastMessage {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                Text(message)
                    .font(.headline)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .transition(.opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { toastMessage = nil }
                }
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

    private var noMatchesState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color.fluffySecondary)

            Text("No matches")
                .font(.title3)
                .foregroundStyle(Color.fluffyPrimary)

            Text("No recipes match “\(searchText)”.")
                .font(.subheadline)
                .foregroundStyle(Color.fluffySecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Recipe List

    private var recipeList: some View {
        List {
            ForEach(filteredRecipes) { recipe in
                Button {
                    Task { await openEdit(recipe) }
                } label: {
                    recipeRow(recipe)
                }
                .tint(Color.fluffyPrimary)
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        recipeToPlan = recipe
                    } label: {
                        Label("Plan", systemImage: "calendar.badge.plus")
                    }
                    .tint(Color.fluffyAccent)
                }
            }
            .onDelete { offsets in
                Task {
                    for index in offsets {
                        let recipe = filteredRecipes[index]
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
    }

    // MARK: - Edit

    private func openEdit(_ recipe: RecipeRow) async {
        editingIngredients = await recipeService.fetchIngredients(for: recipe.id)
        editingRecipe = recipe
    }

    // MARK: - Add to Meal Plan

    /// Assigns the picked recipe to a day using the shared meal-plan
    /// orchestration helper. Shows a day-specific success toast.
    private func addToMealPlan(recipe: RecipeRow, date: Date) async {
        // If that day already has a plan in the loaded week, pass its
        // ID so the helper can subtract its old grocery contributions
        // before replacing. Otherwise nil (helper handles missing).
        let existingPlanID = mealPlanService
            .plansByDate[MealPlanService.isoDate(from: date)]?.id

        Logger.supabase.info("Recipe list: addToMealPlan recipe=\(recipe.id.uuidString) date=\(MealPlanService.isoDate(from: date))")

        let result = await mealPlanService.assignRecipeWithGroceries(
            recipe: recipe,
            on: date,
            existingPlanID: existingPlanID,
            recipeService: recipeService,
            groceryService: groceryService
        )

        guard result != nil else { return }

        // Refresh the meal plan's cached state so the meal plan tab
        // shows the new assignment next time it's viewed.
        await mealPlanService.fetchPlans(
            weekStart: DateHelper.startOfWeek(containing: date)
        )

        // Full day name for the toast
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        withAnimation { toastMessage = "Added to \(f.string(from: date))" }
    }
}

// MARK: - Day Picker Sheet

/// Lightweight sheet that lets the user pick one of the 7 days of the
/// current week to assign a recipe to.
private struct DayPickerSheet: View {
    let recipe: RecipeRow
    let onPick: (Date) -> Void
    let onCancel: () -> Void

    private let weekStart: Date = DateHelper.startOfWeek(containing: Date())

    private var weekDates: [Date] {
        (0..<7).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(recipe.name)
                        .font(.headline)
                        .foregroundStyle(Color.fluffyPrimary)
                } header: {
                    Text("Plan this recipe")
                }

                Section("Choose a Day") {
                    ForEach(weekDates, id: \.self) { date in
                        Button {
                            onPick(date)
                        } label: {
                            HStack {
                                Text(dayName(for: date))
                                    .font(.caption)
                                    .foregroundStyle(Color.fluffySecondary)
                                    .frame(width: 40, alignment: .leading)
                                Text(fullDate(for: date))
                                    .font(.body)
                                    .foregroundStyle(Color.fluffyPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Color.fluffySecondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .tint(Color.fluffyPrimary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add to Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }

    private func dayName(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func fullDate(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }
}
