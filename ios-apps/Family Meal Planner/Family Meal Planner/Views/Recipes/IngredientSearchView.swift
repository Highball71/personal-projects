//
//  IngredientSearchView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/15/26.
//

import SwiftUI
import SwiftData

/// A recipe matched against the user's selected ingredients,
/// tracking which and how many ingredients were found.
struct RecipeMatch: Identifiable {
    let recipe: Recipe
    let matchCount: Int
    let matchedIngredients: [String]

    var id: PersistentIdentifier { recipe.persistentModelID }
}

/// Search saved recipes by ingredients you have on hand.
///
/// Type ingredient names into the text field to build a search list.
/// Results are split into two sections:
/// - "Exact Matches" — recipes that use ALL of your ingredients
/// - "Partial Matches" — recipes that use SOME, ranked by match count
///
/// Tap a result to view the recipe. Swipe left to add it to your meal plan.
struct IngredientSearchView: View {
    @Query(sort: \Recipe.name) private var allRecipes: [Recipe]
    @Environment(\.dismiss) private var dismiss

    @State private var ingredientInput = ""
    @State private var selectedIngredients: [String] = []
    @State private var recipeToAddToPlan: Recipe?

    // MARK: - Search Logic

    /// Find recipes that contain any of the selected ingredients,
    /// sorted by how many ingredients match (most matches first).
    private var searchResults: [RecipeMatch] {
        guard !selectedIngredients.isEmpty else { return [] }

        return allRecipes.compactMap { recipe in
            let matched = selectedIngredients.filter { searchIngredient in
                recipe.ingredientsList.contains { recipeIngredient in
                    recipeIngredient.name.localizedCaseInsensitiveContains(searchIngredient)
                }
            }
            guard !matched.isEmpty else { return nil }
            return RecipeMatch(
                recipe: recipe,
                matchCount: matched.count,
                matchedIngredients: matched
            )
        }.sorted { $0.matchCount > $1.matchCount }
    }

    /// Recipes that contain ALL of the selected ingredients
    private var exactMatches: [RecipeMatch] {
        searchResults.filter { $0.matchCount == selectedIngredients.count }
    }

    /// Recipes that contain SOME of the selected ingredients
    private var partialMatches: [RecipeMatch] {
        searchResults.filter { $0.matchCount < selectedIngredients.count }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ingredientInputArea

                if selectedIngredients.isEmpty {
                    ContentUnavailableView(
                        "Search by Ingredients",
                        systemImage: "fork.knife",
                        description: Text("Add ingredients you have on hand to find matching recipes")
                    )
                } else if searchResults.isEmpty {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text("No recipes use those ingredients. Try different ones!")
                    )
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search by Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .sheet(item: $recipeToAddToPlan) { recipe in
                AddToMealPlanSheet(recipe: recipe)
            }
        }
    }

    // MARK: - Ingredient Input

    private var ingredientInputArea: some View {
        VStack(spacing: 8) {
            // Text field + add button
            HStack {
                TextField("Add an ingredient...", text: $ingredientInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { addIngredient() }

                Button(action: addIngredient) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .disabled(ingredientInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Selected ingredients as removable chips
            if !selectedIngredients.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedIngredients, id: \.self) { ingredient in
                            HStack(spacing: 4) {
                                Text(ingredient)
                                    .font(.subheadline)
                                Button {
                                    removeIngredient(ingredient)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(.bar)
    }

    private func addIngredient() {
        let trimmed = ingredientInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !selectedIngredients.contains(trimmed) else { return }
        selectedIngredients.append(trimmed)
        ingredientInput = ""
    }

    private func removeIngredient(_ ingredient: String) {
        selectedIngredients.removeAll { $0 == ingredient }
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            if !exactMatches.isEmpty {
                Section {
                    ForEach(exactMatches) { match in
                        matchRow(for: match)
                    }
                } header: {
                    Text("Exact Matches")
                } footer: {
                    Text("Recipes that use all \(selectedIngredients.count) ingredient\(selectedIngredients.count == 1 ? "" : "s")")
                }
            }

            if !partialMatches.isEmpty {
                Section {
                    ForEach(partialMatches) { match in
                        matchRow(for: match)
                    }
                } header: {
                    Text("Partial Matches")
                } footer: {
                    Text("Recipes that use some of your ingredients")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// A single result row: tap to view the recipe, swipe left to add to meal plan.
    private func matchRow(for match: RecipeMatch) -> some View {
        NavigationLink(value: match.recipe) {
            VStack(alignment: .leading, spacing: 4) {
                Text(match.recipe.name)
                    .font(.headline)

                Text(match.recipe.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(match.matchCount) of \(selectedIngredients.count): \(match.matchedIngredients.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .swipeActions(edge: .trailing) {
            Button {
                recipeToAddToPlan = match.recipe
            } label: {
                Label("Add to Plan", systemImage: "calendar.badge.plus")
            }
            .tint(.blue)
        }
    }
}

/// Small sheet for quickly adding a recipe to a specific day and meal slot.
/// Checks for an existing entry and replaces it rather than creating duplicates.
struct AddToMealPlanSheet: View {
    let recipe: Recipe

    @Query private var allMealPlans: [MealPlan]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var selectedMealType: MealType = .dinner

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)

                Picker("Meal", selection: $selectedMealType) {
                    ForEach(MealType.allCases) { mealType in
                        Text(mealType.rawValue).tag(mealType)
                    }
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle("Add to Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addToMealPlan()
                        dismiss()
                    }
                }
            }
        }
    }

    /// Creates or replaces the meal plan entry for the selected date and meal type.
    private func addToMealPlan() {
        let dayStart = DateHelper.stripTime(from: selectedDate)

        if let existing = allMealPlans.first(where: {
            DateHelper.stripTime(from: $0.date) == dayStart && $0.mealType == selectedMealType
        }) {
            existing.recipe = recipe
        } else {
            let mealPlan = MealPlan(date: dayStart, mealType: selectedMealType, recipe: recipe)
            modelContext.insert(mealPlan)
        }
    }
}

#Preview {
    IngredientSearchView()
        .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self], inMemory: true)
}
