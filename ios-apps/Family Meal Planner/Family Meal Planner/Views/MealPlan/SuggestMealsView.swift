//
//  SuggestMealsView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/15/26.
//

import SwiftUI
import SwiftData

/// The protein options available for filtering recipes.
/// Each case includes keywords that match against ingredient names,
/// so "chicken breast" matches the .chicken option, "ground beef" matches .beef, etc.
enum ProteinOption: String, CaseIterable, Identifiable {
    case chicken = "Chicken"
    case beef = "Beef"
    case pork = "Pork"
    case fish = "Fish"
    case shrimp = "Shrimp"
    case tofu = "Tofu"

    var id: String { rawValue }

    /// Keywords to search for in ingredient names (case-insensitive).
    /// A recipe matches if any of its ingredients contain any of these keywords.
    var keywords: [String] {
        switch self {
        case .chicken: return ["chicken"]
        case .beef: return ["beef", "steak", "sirloin", "chuck", "brisket"]
        case .pork: return ["pork", "bacon", "ham", "sausage"]
        case .fish: return ["fish", "salmon", "tuna", "cod", "tilapia",
                            "halibut", "trout", "snapper", "catfish", "mahi"]
        case .shrimp: return ["shrimp", "prawn"]
        case .tofu: return ["tofu", "tempeh"]
        }
    }
}

/// Suggests a week of dinner recipes based on the user's protein selections.
///
/// Two-phase flow:
/// 1. User selects which proteins they have on hand (or taps "Surprise Me")
/// 2. View shows 7 suggested dinners — user can shuffle or apply them
///
/// Matching logic: scans each recipe's ingredients for protein keywords.
/// If fewer than 7 recipes match, the remaining slots are filled randomly
/// from all saved recipes.
struct SuggestMealsView: View {
    let weekStartDate: Date
    let onApply: ([(Date, Recipe)]) -> Void

    @Query(sort: \Recipe.name) private var allRecipes: [Recipe]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProteins: Set<ProteinOption> = []
    @State private var surpriseMe = false
    @State private var suggestedMeals: [(date: Date, recipe: Recipe)] = []
    @State private var showingSuggestions = false

    private var weekDays: [Date] {
        DateHelper.weekDays(startingFrom: weekStartDate)
    }

    /// User needs to pick at least one protein or tap "Surprise Me"
    private var canSuggest: Bool {
        !selectedProteins.isEmpty || surpriseMe
    }

    var body: some View {
        NavigationStack {
            if showingSuggestions {
                suggestionsView
            } else {
                proteinSelectionView
            }
        }
    }

    // MARK: - Phase 1: Protein Selection

    private var proteinSelectionView: some View {
        VStack(spacing: 24) {
            Text("What proteins do you have?")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 8)

            // 2-column grid of protein chips
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ProteinOption.allCases) { protein in
                    ProteinChip(
                        label: protein.rawValue,
                        isSelected: selectedProteins.contains(protein)
                    ) {
                        toggleProtein(protein)
                    }
                }
            }
            .padding(.horizontal)

            // "Surprise Me" spans full width
            Button(action: toggleSurpriseMe) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Surprise Me!")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(surpriseMe ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(surpriseMe ? .white : .primary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            Spacer()

            // Primary action button
            Button(action: generateSuggestions) {
                Text("Suggest Meals")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSuggest ? Color.accentColor : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!canSuggest)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Suggest Meals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func toggleProtein(_ protein: ProteinOption) {
        // Selecting a protein deselects "Surprise Me"
        surpriseMe = false
        if selectedProteins.contains(protein) {
            selectedProteins.remove(protein)
        } else {
            selectedProteins.insert(protein)
        }
    }

    private func toggleSurpriseMe() {
        surpriseMe.toggle()
        if surpriseMe {
            selectedProteins.removeAll()
        }
    }

    // MARK: - Phase 2: Suggested Meals

    private var suggestionsView: some View {
        VStack(spacing: 0) {
            if suggestedMeals.isEmpty {
                // No recipes in the library at all
                ContentUnavailableView(
                    "No Recipes Yet",
                    systemImage: "book",
                    description: Text("Add some recipes first, then come back for suggestions!")
                )
            } else {
                List {
                    ForEach(suggestedMeals, id: \.date) { meal in
                        HStack(spacing: 12) {
                            // Day label (e.g., "Mon\nFeb 10")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DateHelper.shortDayName(for: meal.date))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(DateHelper.dayMonth(for: meal.date))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 50, alignment: .leading)

                            // Recipe info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.recipe.name)
                                    .font(.body)
                                Text(meal.recipe.category.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)

                // Shuffle / Use This Plan buttons
                HStack(spacing: 16) {
                    Button(action: generateSuggestions) {
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

                    Button(action: applyPlan) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Use This Plan")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
        }
        .navigationTitle("Your Week")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {
                    showingSuggestions = false
                }
            }
        }
    }

    // MARK: - Suggestion Logic

    /// Builds a week of dinner suggestions by:
    /// 1. Finding recipes whose ingredients match the selected proteins
    /// 2. Shuffling them randomly
    /// 3. Filling any remaining slots from all saved recipes
    private func generateSuggestions() {
        guard !allRecipes.isEmpty else {
            suggestedMeals = []
            showingSuggestions = true
            return
        }

        var pool: [Recipe]

        if surpriseMe {
            // Use everything
            pool = allRecipes
        } else {
            // Find recipes with at least one matching protein ingredient
            let keywords = selectedProteins.flatMap { $0.keywords }
            let matching = allRecipes.filter { recipe in
                recipe.ingredientsList.contains { ingredient in
                    keywords.contains { keyword in
                        ingredient.name.localizedCaseInsensitiveContains(keyword)
                    }
                }
            }
            pool = matching
        }

        var selected = pool.shuffled()

        if selected.count >= 7 {
            // Plenty of matches — just take 7
            selected = Array(selected.prefix(7))
        } else {
            // Not enough matches — fill remaining slots from all recipes
            let usedIDs = Set(selected.map { $0.persistentModelID })
            let extras = allRecipes
                .filter { !usedIDs.contains($0.persistentModelID) }
                .shuffled()
            selected.append(contentsOf: extras.prefix(7 - selected.count))
        }

        // Pair each selected recipe with a day of the week
        suggestedMeals = zip(weekDays, selected).map { (date: $0, recipe: $1) }
        showingSuggestions = true
    }

    private func applyPlan() {
        onApply(suggestedMeals.map { ($0.date, $0.recipe) })
        dismiss()
    }
}

/// A tappable chip for selecting a protein type.
/// Matches the visual style of FilterChip but sized for a grid layout.
struct ProteinChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SuggestMealsView(
        weekStartDate: DateHelper.startOfWeek(containing: Date()),
        onApply: { _ in }
    )
    .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self], inMemory: true)
}
