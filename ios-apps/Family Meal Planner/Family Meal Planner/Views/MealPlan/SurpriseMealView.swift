//
//  SurpriseMealView.swift
//  FluffyList
//
//  Created by David Albert on 2/15/26.
//

import SwiftUI
import CoreData

/// Suggests a single random recipe for one meal slot.
///
/// Two-phase flow:
/// 1. Optional protein preference — select proteins or tap "No Preference" to skip
/// 2. Single recipe suggestion — shows a recipe card with Use This / Shuffle / Cancel
///
/// Reuses ProteinOption and ProteinChip from SuggestMealsView.swift.
struct SurpriseMealView: View {
    /// Called with the chosen recipe when the user taps "Use This"
    let onRecipeSelected: (CDRecipe) -> Void

    @FetchRequest(
        entity: CDRecipe.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CDRecipe.name, ascending: true)]
    ) private var allRecipes: FetchedResults<CDRecipe>

    @Environment(\.dismiss) private var dismiss

    @State private var selectedProteins: Set<ProteinOption> = []
    @State private var suggestedRecipe: CDRecipe?
    @State private var showingSuggestion = false
    // The filtered pool we're drawing from, so Shuffle stays consistent
    @State private var currentPool: [CDRecipe] = []

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
                    .background(Color.fluffyNavBar)
                    .foregroundStyle(Color.fluffyPrimary)
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
                    .background(!selectedProteins.isEmpty ? Color.fluffyAccent : Color.fluffyBorder)
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
                .background(Color.fluffyCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.fluffyBorder, lineWidth: 0.5)
                )
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
                            .background(Color.fluffyAccent)
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
                        .background(Color.fluffyNavBar)
                        .foregroundStyle(Color.fluffyPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.bottom)
            } else if allRecipes.isEmpty {
                // No recipes in the library at all
                ContentUnavailableView(
                    "No Recipes Yet",
                    systemImage: "book",
                    description: Text("Add some recipes first, then come back for suggestions!")
                )
            } else {
                // Library has recipes, but none match the selected protein(s)
                let phrase = selectedProteinsPhrase
                ContentUnavailableView(
                    "No \(phrase) recipes in your library",
                    systemImage: "magnifyingglass",
                    description: Text("Try another protein or add a recipe with \(phrase).")
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

    /// Human-readable list of the currently selected proteins, e.g.
    /// "Beef", "Beef or Chicken", "Beef, Chicken, or Pork".
    /// Used in the no-match empty state.
    private var selectedProteinsPhrase: String {
        let names = selectedProteins.map(\.rawValue).sorted()
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) or \(names[1])"
        default:
            let head = names.dropLast().joined(separator: ", ")
            return "\(head), or \(names.last!)"
        }
    }

    private func suggestWithNoPreference() {
        currentPool = Array(allRecipes)
        pickRandomRecipe()
    }

    private func suggestWithProteins() {
        let recipes = Array(allRecipes)
        // Match on each recipe's detected primary protein (see
        // ProteinOption.detect) rather than any keyword hit in any
        // ingredient, so flavorings like "beef broth" can't misclassify.
        let selected = selectedProteins
        // TEMP DEBUG — remove before release
        print("[TEMP DEBUG] Surprise Me filter — selected=\(selected.map(\.rawValue).sorted()) library=\(recipes.count) recipes")
        let matching = recipes.filter { recipe in
            let detected = ProteinOption.detect(in: recipe)
            let didMatch = detected.map { selected.contains($0) } ?? false
            // TEMP DEBUG — remove before release
            print("[TEMP DEBUG]   \"\(recipe.name)\" detected=\(detected?.rawValue ?? "nil") matched=\(didMatch)")
            return didMatch
        }
        // TEMP DEBUG — remove before release
        print("[TEMP DEBUG] Surprise Me filter — \(matching.count) of \(recipes.count) matched; showing empty state if zero")

        // No fallback to the full library — if nothing matches the selected
        // protein, show an empty state. Falling back would surface any recipe
        // (including the wrong proteins), which is the exact bug being fixed.
        currentPool = matching
        pickRandomRecipe()
    }

    private func shuffle() {
        pickRandomRecipe()
    }

    /// Picks a random recipe from currentPool using rating-weighted selection.
    /// - Recipes rated 4+ average get 3x weight (family favorites)
    /// - Recipes rated 2.5–3.9 or unrated get 1x weight (neutral)
    /// - Recipes rated 2 or below by ANY member are excluded
    private func pickRandomRecipe() {
        guard !currentPool.isEmpty else {
            suggestedRecipe = nil
            showingSuggestion = true
            return
        }

        // Build a weighted pool: exclude low-rated, boost high-rated
        let weightedPool = currentPool.flatMap { recipe -> [CDRecipe] in
            // Exclude if anyone rated it 2 or below
            let hasLowRating = recipe.ratingsList.contains { $0.rating <= 2 }
            if hasLowRating {
                return []              // excluded — someone dislikes it
            }

            let avg = recipe.averageRating
            if let avg, avg >= 4.0 {
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
                $0.objectID != current.objectID
            }
            suggestedRecipe = others.randomElement() ?? pool.randomElement()
        } else {
            suggestedRecipe = pool.randomElement()
        }

        showingSuggestion = true
    }
}

#Preview {
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    SurpriseMealView { recipe in
        print("Selected: \(recipe.name)")
    }
    .environment(\.managedObjectContext, context)
}
