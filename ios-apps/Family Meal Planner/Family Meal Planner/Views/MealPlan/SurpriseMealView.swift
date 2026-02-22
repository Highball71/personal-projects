//
//  SurpriseMealView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/15/26.
//

import SwiftUI
import SwiftData

/// Suggests a single random recipe for one meal slot.
///
/// Two-phase flow:
/// 1. Optional protein preference — select proteins or tap "No Preference" to skip
/// 2. Single recipe suggestion — shows a recipe card with Use This / Shuffle / Cancel
///
/// Reuses ProteinOption and ProteinChip from SuggestMealsView.swift.
struct SurpriseMealView: View {
    /// Called with the chosen recipe when the user taps "Use This"
    let onRecipeSelected: (Recipe) -> Void

    @Query(sort: \Recipe.name) private var allRecipes: [Recipe]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProteins: Set<ProteinOption> = []
    @State private var suggestedRecipe: Recipe?
    @State private var showingSuggestion = false
    // The filtered pool we're drawing from, so Shuffle stays consistent
    @State private var currentPool: [Recipe] = []

    var body: some View {
        NavigationStack {
            if showingSuggestion {
                suggestionView
            } else {
                proteinSelectionView
            }
        }
    }

    // MARK: - Phase 1: Protein Preference

    private var proteinSelectionView: some View {
        VStack(spacing: 24) {
            Text("Any protein preference?")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 8)

            // 2-column grid of protein chips (multi-select)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ProteinOption.allCases) { protein in
                    ProteinChip(
                        label: protein.rawValue,
                        isSelected: selectedProteins.contains(protein)
                    ) {
                        if selectedProteins.contains(protein) {
                            selectedProteins.remove(protein)
                        } else {
                            selectedProteins.insert(protein)
                        }
                    }
                }
            }
            .padding(.horizontal)

            // "No Preference" skips straight to a random suggestion
            Button(action: suggestWithNoPreference) {
                Text("No Preference")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            Spacer()

            // "Suggest" with protein filter — only enabled when proteins are selected
            Button(action: suggestWithProteins) {
                Text("Suggest")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(!selectedProteins.isEmpty ? Color.accentColor : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(selectedProteins.isEmpty)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Surprise Me")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    // MARK: - Phase 2: Recipe Suggestion

    private var suggestionView: some View {
        VStack(spacing: 20) {
            if let recipe = suggestedRecipe {
                Spacer()

                // Recipe card
                VStack(spacing: 12) {
                    Text(recipe.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(recipe.category.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Prep/cook time
                    if recipe.prepTimeMinutes > 0 || recipe.cookTimeMinutes > 0 {
                        HStack(spacing: 16) {
                            if recipe.prepTimeMinutes > 0 {
                                Label("\(recipe.prepTimeMinutes) min prep",
                                      systemImage: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if recipe.cookTimeMinutes > 0 {
                                Label("\(recipe.cookTimeMinutes) min cook",
                                      systemImage: "flame")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Ingredient preview — first few ingredients for a quick glance
                    let ingredients = recipe.ingredientsList
                    if !ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(ingredients.prefix(4)) { ingredient in
                                Text("• \(ingredient.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if ingredients.count > 4 {
                                Text("+ \(ingredients.count - 4) more")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        onRecipeSelected(recipe)
                        dismiss()
                    }) {
                        Text("Use This")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button(action: shuffle) {
                        HStack {
                            Image(systemName: "shuffle")
                            Text("Shuffle")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.bottom)
            } else {
                // No recipes in the library at all
                ContentUnavailableView(
                    "No Recipes Yet",
                    systemImage: "book",
                    description: Text("Add some recipes first, then come back for suggestions!")
                )
            }
        }
        .navigationTitle("How About...")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    // MARK: - Suggestion Logic

    private func suggestWithNoPreference() {
        currentPool = allRecipes
        pickRandomRecipe()
    }

    private func suggestWithProteins() {
        let keywords = selectedProteins.flatMap { $0.keywords }
        let matching = allRecipes.filter { recipe in
            recipe.ingredientsList.contains { ingredient in
                keywords.contains { keyword in
                    ingredient.name.localizedCaseInsensitiveContains(keyword)
                }
            }
        }
        // If no matches for the selected proteins, fall back to all recipes
        currentPool = matching.isEmpty ? allRecipes : matching
        pickRandomRecipe()
    }

    private func shuffle() {
        pickRandomRecipe()
    }

    /// Picks a random recipe from currentPool using rating-weighted selection.
    /// - Recipes rated 4+ average get 3x weight (family favorites)
    /// - Recipes rated 2.5–3.9 or unrated get 1x weight (neutral)
    /// - Recipes rated below 2.5 are excluded (disliked)
    private func pickRandomRecipe() {
        guard !allRecipes.isEmpty else {
            suggestedRecipe = nil
            showingSuggestion = true
            return
        }

        // Build a weighted pool: exclude low-rated, boost high-rated
        let weightedPool = currentPool.flatMap { recipe -> [Recipe] in
            let avg = recipe.averageRating
            if let avg, avg < 2.5 {
                return []              // excluded — disliked
            } else if let avg, avg >= 4.0 {
                return [recipe, recipe, recipe]  // 3x weight — family favorite
            } else {
                return [recipe]        // 1x weight — neutral or unrated
            }
        }

        // Fall back to the unweighted pool if everything got filtered out
        let pool = weightedPool.isEmpty ? currentPool : weightedPool

        if pool.count > 1, let current = suggestedRecipe {
            // Avoid showing the same recipe twice in a row
            let others = pool.filter {
                $0.persistentModelID != current.persistentModelID
            }
            suggestedRecipe = others.randomElement() ?? pool.randomElement()
        } else {
            suggestedRecipe = pool.randomElement()
        }

        showingSuggestion = true
    }
}

#Preview {
    SurpriseMealView { recipe in
        print("Selected: \(recipe.name)")
    }
    .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self], inMemory: true)
}
