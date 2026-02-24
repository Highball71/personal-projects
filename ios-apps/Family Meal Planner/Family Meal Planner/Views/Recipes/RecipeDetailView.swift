//
//  RecipeDetailView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import SwiftData

/// Read-only detail view showing a recipe's info, ingredients, and instructions.
/// Has an Edit button that opens AddEditRecipeView in edit mode.
struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \HouseholdMember.name) private var members: [HouseholdMember]

    let recipe: Recipe
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    // Device-local identity — matches the "You are" picker in Settings
    @AppStorage("currentUserName") private var currentUserName: String = ""

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Category", value: recipe.category.rawValue)
                LabeledContent("Servings", value: "\(recipe.servings)")
                LabeledContent("Prep Time", value: "\(recipe.prepTimeMinutes) minutes")
                if recipe.cookTimeMinutes > 0 {
                    LabeledContent("Cook Time", value: "\(recipe.cookTimeMinutes) minutes")
                }
            }

            Section("Ingredients") {
                if recipe.ingredientsList.isEmpty {
                    Text("No ingredients added")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recipe.ingredientsList) { ingredient in
                        Text(formatIngredientDisplay(ingredient))
                    }
                }
            }

            if !recipe.instructions.isEmpty {
                Section("Instructions") {
                    Text(recipe.instructions)
                }
            }

            // Subtle source attribution for imported recipes
            if let sourceText = sourceAttribution {
                Section {
                    Text(sourceText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
            }

            // MARK: - Ratings
            Section("Ratings") {
                if members.isEmpty {
                    // Solo mode — no household members, just show stars
                    HStack {
                        Text("Your Rating")
                            .foregroundStyle(.secondary)
                        Spacer()
                        StarRatingView(rating: currentUserRating) { newRating in
                            setRating(newRating)
                        }
                    }
                } else if !currentUserName.isEmpty {
                    // Household mode with identity set — show "Your Rating" with name
                    HStack {
                        Text(currentUserName)
                        Spacer()
                        StarRatingView(rating: currentUserRating) { newRating in
                            setRating(newRating)
                        }
                    }
                } else {
                    // Household exists but no identity set
                    Text("Set \"You are\" in Settings to rate recipes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Household average
                if let avg = recipe.averageRating {
                    HStack {
                        Text("Household Average")
                            .foregroundStyle(.secondary)
                        Spacer()
                        StarDisplayView(rating: avg)
                        Text(String(format: "%.1f", avg))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }

                // Individual ratings from other household members
                // Hides: the current user's own rating, and the _solo placeholder
                let otherRatings = recipe.ratingsList
                    .filter {
                        $0.raterName != "_solo"
                        && $0.raterName.lowercased() != effectiveRaterName.lowercased()
                    }
                    .sorted { $0.raterName < $1.raterName }
                ForEach(otherRatings) { rating in
                    HStack {
                        Text(rating.raterName)
                        Spacer()
                        StarDisplayView(rating: Double(rating.rating))
                    }
                }
            }

            Section {
                Button("Delete Recipe", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(recipe.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditSheet = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    recipe.isFavorite.toggle()
                } label: {
                    Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(recipe.isFavorite ? .red : .secondary)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditRecipeView(recipeToEdit: recipe)
        }
        .alert("Delete this recipe?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(recipe)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This can't be undone.")
        }
    }

    /// Build a subtle "From: ..." attribution string, or nil for manual recipes.
    private var sourceAttribution: String? {
        guard let sourceType = recipe.sourceType else { return nil }

        switch sourceType {
        case .photo:
            // Photo scan — show cookbook name if Claude identified one
            if let detail = recipe.sourceDetail, !detail.isEmpty {
                return "From: \(detail)"
            }
            return nil
        case .url:
            // URL import or search — extract just the domain name
            if let detail = recipe.sourceDetail, !detail.isEmpty,
               let url = URL(string: detail), let host = url.host {
                // Strip "www." prefix for cleaner display
                let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
                return "From: \(domain)"
            }
            return nil
        case .cookbook:
            if let detail = recipe.sourceDetail, !detail.isEmpty {
                return "From: \(detail)"
            }
            return nil
        case .website, .other:
            if let detail = recipe.sourceDetail, !detail.isEmpty {
                return "From: \(detail)"
            }
            return nil
        }
    }

    /// The name used for storing ratings — uses the device identity if set,
    /// or a fixed solo label when no household members exist.
    private var effectiveRaterName: String {
        if !currentUserName.isEmpty {
            return currentUserName
        }
        // Solo mode: no household, use a fixed key so it persists
        return members.isEmpty ? "_solo" : ""
    }

    /// The current user's rating for this recipe, or 0 if they haven't rated yet.
    private var currentUserRating: Int {
        guard !effectiveRaterName.isEmpty else { return 0 }
        return recipe.ratingsList
            .first { $0.raterName.lowercased() == effectiveRaterName.lowercased() }?
            .rating ?? 0
    }

    /// Creates or updates the current user's rating for this recipe.
    private func setRating(_ newRating: Int) {
        let name = effectiveRaterName
        guard !name.isEmpty else { return }

        // Look for an existing rating from this person
        if let existing = recipe.ratingsList.first(where: {
            $0.raterName.lowercased() == name.lowercased()
        }) {
            existing.rating = newRating
            existing.dateRated = Date()
        } else {
            let newRatingObj = RecipeRating(
                raterName: name,
                rating: newRating,
                recipe: recipe
            )
            modelContext.insert(newRatingObj)
        }
    }

    /// Format a single ingredient for display.
    /// "to taste" items: "Salt, to taste"
    /// "none" unit: "3 eggs"
    /// Normal: "1 1/2 cups all-purpose flour"
    private func formatIngredientDisplay(_ ingredient: Ingredient) -> String {
        if ingredient.unit == .toTaste {
            return "\(ingredient.name), to taste"
        }
        let qty = FractionFormatter.formatAsFraction(ingredient.quantity)
        if ingredient.unit == .none {
            return "\(qty) \(ingredient.name)"
        }
        return "\(qty) \(ingredient.unit.displayName) \(ingredient.name)"
    }
}

// MARK: - Star Views

/// Tappable 1–5 star input. Shows filled stars up to the current rating.
/// Pass rating = 0 to show all empty stars (no rating yet).
private struct StarRatingView: View {
    let rating: Int
    let onRate: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundStyle(.orange)
                    .font(.title3)
                    .onTapGesture { onRate(star) }
            }
        }
    }
}

/// Read-only star display showing a fractional average (e.g. 3.7 fills 3 full + 1 half).
private struct StarDisplayView: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                let starValue = Double(star)
                Image(systemName: starIcon(for: starValue))
                    .foregroundStyle(.orange)
                    .font(.caption2)
            }
        }
    }

    private func starIcon(for starValue: Double) -> String {
        if rating >= starValue {
            return "star.fill"
        } else if rating >= starValue - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(recipe: Recipe(
            name: "Spaghetti Bolognese",
            category: .dinner,
            servings: 4,
            prepTimeMinutes: 45,
            instructions: """
            1. Brown the ground beef in a large pan.
            2. Add diced onions and garlic, cook until soft.
            3. Add crushed tomatoes and Italian seasoning.
            4. Simmer for 20 minutes.
            5. Cook spaghetti according to package directions.
            6. Serve sauce over pasta.
            """,
            ingredients: [
                Ingredient(name: "Spaghetti", quantity: 1, unit: .pound),
                Ingredient(name: "Ground beef", quantity: 1, unit: .pound),
                Ingredient(name: "Crushed tomatoes", quantity: 28, unit: .ounce),
                Ingredient(name: "Onion", quantity: 1, unit: .whole),
                Ingredient(name: "Garlic cloves", quantity: 3, unit: .piece),
            ],
            sourceType: .cookbook,
            sourceDetail: "The Joy of Cooking, p. 312"
        ))
    }
    .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self], inMemory: true)
}
