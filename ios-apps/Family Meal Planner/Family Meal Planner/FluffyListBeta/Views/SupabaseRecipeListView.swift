//
//  SupabaseRecipeListView.swift
//  FluffyList
//
//  Recipe browse view with amber accent, horizontal category filter
//  chips, a featured hero card, and a two-column grid of recipe cards.
//  Figma Heirloom design.
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
    @State private var searchText = ""
    @State private var selectedTag: BrowseTag = .all
    @State private var recipeToPlan: RecipeRow?
    @State private var toastMessage: String?

    // MARK: - Filtering

    /// Recipes filtered by the selected browse tag, then by search text.
    private var displayedRecipes: [RecipeRow] {
        var result = recipeService.recipes

        // Browse tag filter
        if selectedTag != .all {
            result = result.filter { recipe in
                selectedTag.matches(
                    recipe,
                    ingredientNames: recipeService.ingredientsByRecipeID[recipe.id]
                )
            }
        }

        // Search text filter
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { recipe in
                if recipe.name.lowercased().contains(query) { return true }
                if let names = recipeService.ingredientsByRecipeID[recipe.id],
                   names.contains(where: { $0.contains(query) }) { return true }
                return false
            }
        }

        return result
    }

    /// The hero card recipe — first favorite, or newest recipe.
    private var heroRecipe: RecipeRow? {
        displayedRecipes.first { $0.isFavorite } ?? displayedRecipes.first
    }

    /// Grid recipes — everything except the hero.
    private var gridRecipes: [RecipeRow] {
        guard let hero = heroRecipe else { return [] }
        return displayedRecipes.filter { $0.id != hero.id }
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if recipeService.isLoading && recipeService.recipes.isEmpty {
                    ProgressView("Loading recipes...")
                } else if recipeService.recipes.isEmpty {
                    emptyState
                } else if displayedRecipes.isEmpty {
                    noMatchesState
                } else {
                    browseContent
                }
            }
            .animation(.easeInOut(duration: 0.25), value: recipeService.isLoading)
            .background(Color.fluffyBackground)
            .navigationTitle("Recipes")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search name or ingredient"
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingHouseholdInfo = true } label: {
                        Image(systemName: "house.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddRecipe = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRecipe) {
                SupabaseAddRecipeView()
            }
            .sheet(item: $recipeToPlan) { recipe in
                DayPickerSheet(
                    recipe: recipe,
                    onPick: { date in
                        recipeToPlan = nil
                        Task { await addToMealPlan(recipe: recipe, date: date) }
                    },
                    onCancel: { recipeToPlan = nil }
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

    // MARK: - Browse Content

    private var browseContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Category filter chips
                chipBar
                    .padding(.top, 4)
                    .padding(.bottom, 20)

                // Hero card
                if let hero = heroRecipe {
                    NavigationLink {
                        SupabaseRecipeDetailView(recipe: hero)
                    } label: {
                        heroCard(hero)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { recipeContextMenu(hero) }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }

                // Two-column grid
                if !gridRecipes.isEmpty {
                    LazyVGrid(columns: gridColumns, spacing: 14) {
                        ForEach(gridRecipes) { recipe in
                            NavigationLink {
                                SupabaseRecipeDetailView(recipe: recipe)
                            } label: {
                                gridCard(recipe)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { recipeContextMenu(recipe) }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Chip Bar

    private var chipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BrowseTag.allCases) { tag in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTag = tag
                        }
                    } label: {
                        Text(tag.rawValue)
                            .font(.fluffySubheadline)
                            .foregroundStyle(
                                selectedTag == tag ? .white : Color.fluffyAmber
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedTag == tag
                                    ? Color.fluffyAmber
                                    : Color.fluffyAmber.opacity(0.12),
                                in: Capsule()
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Hero Card

    private func heroCard(_ recipe: RecipeRow) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background with category icon
            cardGradient(for: recipe)
                .frame(height: 200)
                .overlay(alignment: .center) {
                    Image(systemName: categoryIcon(for: recipe))
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.15))
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))

            // Bottom scrim + title
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recipe.name)
                        .font(.fluffyDisplay)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer()
                    if recipe.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
                Text(recipeSubtitle(recipe))
                    .font(.fluffyCallout)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 16)
                )
            )
        }
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    // MARK: - Grid Card

    private func gridCard(_ recipe: RecipeRow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Gradient "photo" area
            ZStack {
                cardGradient(for: recipe)
                Image(systemName: categoryIcon(for: recipe))
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .frame(height: 120)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 12,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 12
                )
            )

            // Info area
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(recipe.name)
                        .font(.fluffyHeadline)
                        .foregroundStyle(Color.fluffyPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    if recipe.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(Color.fluffyAmber)
                    }
                }
                Text(recipeSubtitle(recipe))
                    .font(.fluffyCaption)
                    .foregroundStyle(Color.fluffySecondary)
                    .lineLimit(1)
            }
            .padding(10)
        }
        .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }

    // MARK: - Card Helpers

    private func recipeSubtitle(_ recipe: RecipeRow) -> String {
        let total = recipe.prepTimeMinutes + recipe.cookTimeMinutes
        if total > 0 {
            return "\(recipe.category.capitalized) · \(total) min"
        }
        return recipe.category.capitalized
    }

    /// Deterministic warm gradient based on recipe category.
    private func cardGradient(for recipe: RecipeRow) -> LinearGradient {
        let pair: (String, String) = switch recipe.recipeCategory {
        case .breakfast: ("F5C882", "D4A050")
        case .lunch:     ("7DB88F", "5A9E6E")
        case .dinner:    ("D4845A", "B86840")
        case .snack:     ("B5C9A8", "8EB088")
        case .dessert:   ("D4A0B0", "C08098")
        case .side:      ("8AB0A0", "5A9080")
        case .drink:     ("A0B8D0", "7898B8")
        }
        return LinearGradient(
            colors: [Color(hex: pair.0), Color(hex: pair.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// SF Symbol per meal category — used as a placeholder in cards.
    private func categoryIcon(for recipe: RecipeRow) -> String {
        switch recipe.recipeCategory {
        case .breakfast: "sunrise.fill"
        case .lunch:     "sun.max.fill"
        case .dinner:    "moon.stars.fill"
        case .snack:     "leaf.fill"
        case .dessert:   "birthday.cake.fill"
        case .side:      "carrot.fill"
        case .drink:     "cup.and.saucer.fill"
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func recipeContextMenu(_ recipe: RecipeRow) -> some View {
        Button {
            recipeToPlan = recipe
        } label: {
            Label("Add to Meal Plan", systemImage: "calendar.badge.plus")
        }
        Button {
            Task { await recipeService.toggleFavorite(recipe) }
        } label: {
            Label(
                recipe.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: recipe.isFavorite ? "heart.slash" : "heart"
            )
        }
        Button(role: .destructive) {
            Task { await recipeService.deleteRecipe(recipe.id) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Empty / No-Matches

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.fluffyAmberLight)
                    .frame(width: 120, height: 120)
                Image(systemName: "book.closed")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.fluffyAmber)
            }
            .padding(.bottom, 24)
            Text("No recipes yet")
                .font(.fluffyDisplay)
                .foregroundStyle(Color.fluffyPrimary)
                .padding(.bottom, 8)
            Text("Tap + to add your first recipe.")
                .font(.fluffyBody)
                .foregroundStyle(Color.fluffySecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noMatchesState: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.fluffyAmberLight)
                    .frame(width: 120, height: 120)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.fluffyAmber)
            }
            .padding(.bottom, 24)
            Text("No matches")
                .font(.fluffyDisplay)
                .foregroundStyle(Color.fluffyPrimary)
                .padding(.bottom, 8)
            Text("Try a different search or filter.")
                .font(.fluffyBody)
                .foregroundStyle(Color.fluffySecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let message = toastMessage {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.fluffySuccess)
                Text(message)
                    .font(.fluffyHeadline)
                    .foregroundStyle(Color.fluffyPrimary)
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

    // MARK: - Add to Meal Plan

    private func addToMealPlan(recipe: RecipeRow, date: Date) async {
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

        await mealPlanService.fetchPlans(
            weekStart: DateHelper.startOfWeek(containing: date)
        )

        let f = DateFormatter()
        f.dateFormat = "EEEE"
        withAnimation { toastMessage = "Added to \(f.string(from: date))" }
    }
}

// MARK: - Browse Tags

/// Cuisine / ingredient-based filter tags for the recipe browse view.
/// Matches recipes by scanning their name and ingredient list for keywords.
private enum BrowseTag: String, CaseIterable, Identifiable {
    case all        = "All"
    case chicken    = "Chicken"
    case pasta      = "Pasta"
    case fish       = "Fish"
    case vegetarian = "Vegetarian"
    case pork       = "Pork"
    case soups      = "Soups"

    var id: String { rawValue }

    /// Whether a recipe matches this tag based on its name and ingredients.
    func matches(_ recipe: RecipeRow, ingredientNames: [String]?) -> Bool {
        let nameLower = recipe.name.lowercased()
        let ingredients = ingredientNames ?? []

        func containsAny(_ keywords: [String]) -> Bool {
            keywords.contains { kw in
                nameLower.contains(kw) || ingredients.contains { $0.contains(kw) }
            }
        }

        switch self {
        case .all:
            return true
        case .chicken:
            return containsAny(["chicken", "poultry"])
        case .pasta:
            return containsAny([
                "pasta", "spaghetti", "penne", "linguine", "fettuccine",
                "macaroni", "noodle", "lasagna", "rigatoni", "orzo",
                "tortellini", "ravioli", "gnocchi"
            ])
        case .fish:
            return containsAny([
                "fish", "salmon", "tuna", "cod", "tilapia", "shrimp",
                "seafood", "prawn", "crab", "lobster", "scallop",
                "halibut", "mahi", "swordfish", "anchov"
            ])
        case .vegetarian:
            // Negative match: no common meat/fish keywords
            let meatKeywords = [
                "chicken", "beef", "pork", "turkey", "lamb", "bacon",
                "sausage", "ham", "steak", "prosciutto", "fish",
                "salmon", "tuna", "shrimp", "prawn", "crab",
                "lobster", "scallop", "anchov"
            ]
            return !containsAny(meatKeywords)
        case .pork:
            return containsAny([
                "pork", "bacon", "ham", "prosciutto", "pancetta"
            ])
        case .soups:
            return containsAny([
                "soup", "stew", "chowder", "bisque", "broth", "chili"
            ])
        }
    }
}

// MARK: - Day Picker Sheet

/// Lightweight sheet that lets the user pick one of the 7 days of the
/// current week to assign a recipe to.
struct DayPickerSheet: View {
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
                        .font(.fluffyHeadline)
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
                                    .font(.fluffyCaption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.fluffySecondary)
                                    .frame(width: 40, alignment: .leading)
                                Text(fullDate(for: date))
                                    .font(.fluffyBody)
                                    .foregroundStyle(Color.fluffyPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Color.fluffyTertiary)
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
