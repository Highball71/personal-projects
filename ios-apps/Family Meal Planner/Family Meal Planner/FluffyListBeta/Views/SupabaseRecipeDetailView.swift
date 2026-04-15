//
//  SupabaseRecipeDetailView.swift
//  FluffyList
//
//  Read-only recipe detail screen for the Supabase path.
//  Figma spec: Playfair Display bold title, amber section headers,
//  bullet-dot ingredients, bold ingredient names in prep steps,
//  and an amber "Add to This Week" button.
//

import SwiftUI

struct SupabaseRecipeDetailView: View {
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var mealPlanService: MealPlanService
    @EnvironmentObject private var groceryService: GroceryService

    let recipe: RecipeRow

    @State private var ingredients: [RecipeIngredientRow] = []
    @State private var isLoadingIngredients = true
    @State private var showingEdit = false
    @State private var showingDayPicker = false
    @State private var toastMessage: String?

    private var totalMinutes: Int {
        recipe.prepTimeMinutes + recipe.cookTimeMinutes
    }

    /// Ingredient names sorted longest-first so highlighting
    /// doesn't get tripped up by partial substring matches.
    private var ingredientNames: [String] {
        ingredients
            .map(\.name)
            .sorted { $0.count > $1.count }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleSection
                metadataRow
                sectionDivider

                ingredientsSection
                    .padding(.top, 24)

                if !recipe.instructions.isEmpty {
                    sectionDivider.padding(.top, 24)
                    preparationSection
                        .padding(.top, 24)
                }

                if let source = sourceAttribution {
                    Text(source)
                        .font(.fluffyCaption)
                        .foregroundStyle(Color.fluffyTertiary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                }

                // Primary CTA
                FluffyPrimaryButton(
                    "Add to This Week",
                    icon: "calendar.badge.plus",
                    section: .recipes
                ) {
                    showingDayPicker = true
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
        }
        .background(Color.fluffyBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button {
                        Task { await recipeService.toggleFavorite(recipe) }
                    } label: {
                        Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(recipe.isFavorite ? Color.fluffyAmber : Color.fluffySecondary)
                    }
                    Button("Edit") { showingEdit = true }
                        .foregroundStyle(Color.fluffyAmber)
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            SupabaseAddRecipeView(recipe: recipe, ingredients: ingredients)
        }
        .sheet(isPresented: $showingDayPicker) {
            DayPickerSheet(
                recipe: recipe,
                onPick: { date in
                    showingDayPicker = false
                    Task { await addToMealPlan(date: date) }
                },
                onCancel: { showingDayPicker = false }
            )
        }
        .overlay { toastOverlay }
        .task { await loadIngredients() }
    }

    // MARK: - Title

    private var titleSection: some View {
        Text(recipe.name)
            .font(.fluffyDisplay)
            .foregroundStyle(Color.fluffyPrimary)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
    }

    // MARK: - Metadata Chips

    private var metadataRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FluffyMetadataChip(
                    icon: "tag",
                    value: recipe.category.capitalized
                )
                if recipe.servings > 0 {
                    FluffyMetadataChip(
                        icon: "person.2",
                        value: "Serves \(recipe.servings)"
                    )
                }
                if totalMinutes > 0 {
                    FluffyMetadataChip(
                        icon: "clock",
                        value: "\(totalMinutes) min"
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FluffySectionHeader(title: "Ingredients")
                .padding(.horizontal, 20)

            if isLoadingIngredients {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if ingredients.isEmpty {
                Text("No ingredients listed")
                    .font(.fluffyBody)
                    .foregroundStyle(Color.fluffyTertiary)
                    .padding(.horizontal, 20)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(ingredients) { ingredient in
                        FluffyBulletRow(text: formatIngredient(ingredient))
                            .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    // MARK: - Preparation

    private var preparationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FluffySectionHeader(title: "Preparation")
                .padding(.horizontal, 20)

            let steps = recipe.instructions
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    Text(highlightIngredients(in: step))
                        .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Divider

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.fluffyDivider)
            .frame(height: 1)
            .padding(.horizontal, 20)
    }

    // MARK: - Ingredient Formatting

    /// Format a single ingredient for display.
    /// "to taste" → "Salt, to taste"
    /// "—" (none) → "3 eggs"
    /// Normal → "1 1/2 cups all-purpose flour"
    private func formatIngredient(_ ingredient: RecipeIngredientRow) -> String {
        let unit = IngredientUnit(rawValue: ingredient.unit)

        if unit == .toTaste {
            return "\(ingredient.name), to taste"
        }

        let qty = FractionFormatter.formatAsFraction(ingredient.quantity)

        if unit == nil || unit == .none {
            return "\(qty) \(ingredient.name)"
        }

        return "\(qty) \(unit!.displayName) \(ingredient.name)"
    }

    // MARK: - Ingredient Highlighting

    /// Build an AttributedString with ingredient names set to Inter Semi Bold.
    /// This makes ingredient references in instructions pop visually.
    private func highlightIngredients(in text: String) -> AttributedString {
        var result = AttributedString(text)
        result.font = .custom("Inter-Regular", size: 16)
        result.foregroundColor = Color.fluffyPrimary

        for name in ingredientNames {
            // Skip very short names (e.g. "oil") to avoid false positives
            guard name.count >= 3 else { continue }

            var searchStart = result.startIndex
            while searchStart < result.endIndex,
                  let range = result[searchStart...].range(
                      of: name,
                      options: .caseInsensitive
                  ) {
                result[range].font = .custom("Inter-SemiBold", size: 16)
                searchStart = range.upperBound
            }
        }

        return result
    }

    // MARK: - Source Attribution

    private var sourceAttribution: String? {
        guard let sourceType = recipe.sourceType,
              let detail = recipe.sourceDetail,
              !detail.isEmpty else {
            return nil
        }

        if sourceType == "url",
           let url = URL(string: detail),
           let host = url.host {
            let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            return "From: \(domain)"
        }

        return "From: \(detail)"
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

    // MARK: - Actions

    private func loadIngredients() async {
        ingredients = await recipeService.fetchIngredients(for: recipe.id)
        isLoadingIngredients = false
    }

    private func addToMealPlan(date: Date) async {
        let existingPlanID = mealPlanService
            .plansByDate[MealPlanService.isoDate(from: date)]?.id

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
