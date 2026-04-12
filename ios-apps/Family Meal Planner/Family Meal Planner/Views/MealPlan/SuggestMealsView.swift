//
//  SuggestMealsView.swift
//  FluffyList
//
//  Created by David Albert on 2/15/26.
//

import SwiftUI
import CoreData

/// The protein options available for filtering recipes.
/// Each case includes keywords that identify it in recipe names and ingredients,
/// so "chicken breast" matches the .chicken option, "ground beef" matches .beef, etc.
enum ProteinOption: String, CaseIterable, Identifiable {
    case chicken = "Chicken"
    case beef = "Beef"
    case pork = "Pork"
    case fish = "Fish"
    case shrimp = "Shrimp"
    case tofu = "Tofu"

    var id: String { rawValue }

    /// Keywords that identify this protein in a recipe name or ingredient.
    /// Matching is case-insensitive substring.
    var keywords: [String] {
        switch self {
        case .chicken: return ["chicken"]
        case .beef: return ["beef", "steak", "sirloin", "chuck", "brisket"]
        case .pork: return ["pork", "bacon", "ham", "sausage", "prosciutto", "pancetta"]
        case .fish: return ["fish", "salmon", "tuna", "cod", "tilapia",
                            "halibut", "trout", "snapper", "catfish", "mahi"]
        case .shrimp: return ["shrimp", "prawn"]
        case .tofu: return ["tofu", "tempeh"]
        }
    }

    /// Words that, when present in an ingredient name, indicate the ingredient
    /// is a flavoring/accent rather than the recipe's main protein. Used so
    /// "beef broth" in a pork stew doesn't misclassify the stew as beef.
    private static let flavoringMarkers: [String] = [
        "broth", "stock", "bouillon", "bouillion",
        "sauce", "paste", "gravy", "dressing", "marinade",
        "seasoning", "rub", "powder", "extract",
        "flavor", "flavoring", "base", "cube", "concentrate"
    ]

    /// Classifies a recipe with its primary protein, if one can be determined.
    ///
    /// Classification order:
    ///   1. Recipe name — users typically name recipes by the main protein
    ///      ("Chicken Parmesan", "Beef Stroganoff"). First match wins,
    ///      iterated in `allCases` declaration order.
    ///   2. Ingredient names — but any ingredient containing a flavoring
    ///      marker ("beef broth", "chicken bouillon") is skipped so it
    ///      can't override the main protein.
    ///
    /// Returns `nil` for recipes with no identifiable animal/tofu protein
    /// (e.g. vegetarian dishes, baked goods).
    static func detect(in recipe: CDRecipe) -> ProteinOption? {
        let name = recipe.name.lowercased()
        for protein in ProteinOption.allCases {
            if protein.keywords.contains(where: { name.contains($0) }) {
                return protein
            }
        }

        for ingredient in recipe.ingredientsList {
            let ingName = ingredient.name.lowercased()
            if flavoringMarkers.contains(where: { ingName.contains($0) }) {
                continue
            }
            for protein in ProteinOption.allCases {
                if protein.keywords.contains(where: { ingName.contains($0) }) {
                    return protein
                }
            }
        }
        return nil
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
    let onApply: ([(Date, CDRecipe)]) -> Void

    @FetchRequest(
        entity: CDRecipe.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CDRecipe.name, ascending: true)]
    ) private var allRecipes: FetchedResults<CDRecipe>

    @Environment(\.dismiss) private var dismiss

    @State private var selectedProteins: Set<ProteinOption> = []
    @State private var surpriseMe = false
    @State private var suggestedMeals: [(date: Date, recipe: CDRecipe)] = []
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
            VStack(spacing: 6) {
                Text("What proteins do you have?")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("We'll fill the week with 7 dinners that match.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
            .padding(.horizontal)

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
                .background(surpriseMe ? Color.fluffyAccent : Color.fluffyNavBar)
                .foregroundStyle(surpriseMe ? .white : Color.fluffyPrimary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            Spacer()

            // Primary action button
            Button(action: generateSuggestions) {
                Text("Suggest 7 Dinners")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSuggest ? Color.fluffyAccent : Color.fluffyBorder)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!canSuggest)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Suggest Week")
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
                .scrollContentBackground(.hidden)
                .background(Color.fluffyBackground)

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
                        .background(Color.fluffyNavBar)
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
                        .background(Color.fluffyAccent)
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
        let recipes = Array(allRecipes)
        guard !recipes.isEmpty else {
            suggestedMeals = []
            showingSuggestions = true
            return
        }

        var pool: [CDRecipe]

        if surpriseMe {
            // Use everything
            pool = recipes
        } else {
            // Match on each recipe's detected primary protein, not on any
            // ingredient containing a protein keyword. This prevents pork
            // stews with "beef broth" from matching the Beef chip.
            let matching = recipes.filter { recipe in
                guard let detected = ProteinOption.detect(in: recipe) else { return false }
                return selectedProteins.contains(detected)
            }
            pool = matching
        }

        // Apply rating-based weighting:
        // - Exclude recipes rated 2 or below by anyone
        // - Give 3x weight to recipes rated 4+ average (family favorites)
        let weightedPool = pool.flatMap { recipe -> [CDRecipe] in
            let hasLowRating = recipe.ratingsList.contains { $0.rating <= 2 }
            if hasLowRating { return [] }

            if let avg = recipe.averageRating, avg >= 4.0 {
                return [recipe, recipe, recipe]
            }
            return [recipe]
        }

        // Fall back to unweighted pool if all recipes got excluded
        let effectivePool = weightedPool.isEmpty ? pool : weightedPool

        // Shuffle and deduplicate (weighted entries may repeat)
        var selected: [CDRecipe] = []
        for recipe in effectivePool.shuffled() {
            if !selected.contains(where: { $0.objectID == recipe.objectID }) {
                selected.append(recipe)
            }
            if selected.count >= 7 { break }
        }

        if selected.count < 7 {
            // Not enough matches — fill remaining slots from all recipes
            let usedIDs = Set(selected.map { $0.objectID })
            let extras = recipes
                .filter { !usedIDs.contains($0.objectID) }
                .shuffled()
            selected.append(contentsOf: extras.prefix(7 - selected.count))
        }

        // Pair each selected recipe with a day of the week
        suggestedMeals = zip(weekDays, selected).map { (date: $0, recipe: $1) }
        showingSuggestions = true
    }

    private func applyPlan() {
        onApply(suggestedMeals.map { ($0.date, $0.recipe as CDRecipe) })
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
                .background(isSelected ? Color.fluffyAccent : Color.fluffyNavBar)
                .foregroundStyle(isSelected ? .white : Color.fluffyPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    SuggestMealsView(
        weekStartDate: DateHelper.startOfWeek(containing: Date()),
        onApply: { _ in }
    )
    .environment(\.managedObjectContext, context)
}
