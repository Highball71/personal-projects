//
//  RecipeDetailView.swift
//  FluffyList
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import CoreData

/// Read-only detail view showing a recipe's info, ingredients, and instructions.
/// Has an Edit button that opens AddEditRecipeView in edit mode.
/// Primary action: "Add to Tonight" assigns the recipe to today's dinner.
struct RecipeDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(MealPlanningStore.self) private var mealPlanningStore
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDHouseholdMember.name, ascending: true)]) private var members: FetchedResults<CDHouseholdMember>
    // Kept for reactive isAlreadyTonight check — mutations go through the store
    @FetchRequest(
        entity: CDMealPlan.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CDMealPlan.date, ascending: true)]
    ) private var allMealPlans: FetchedResults<CDMealPlan>

    let recipe: CDRecipe
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showAddedConfirmation = false
    @State private var showingMealPlanPicker = false

    // Device-local identity — matches the "You are" picker in Settings
    @AppStorage("currentUserName") private var currentUserName: String = ""

    /// Tags derived from existing recipe data (no new Core Data fields needed)
    private var tags: [String] {
        var result: [String] = [recipe.category.rawValue]
        let totalTime = Int(recipe.prepTimeMinutes) + Int(recipe.cookTimeMinutes)
        if totalTime > 0 && totalTime <= 30 {
            result.append("Quick")
        }
        return result
    }

    /// Whether this recipe is already assigned to tonight's dinner
    private var isAlreadyTonight: Bool {
        let today = DateHelper.stripTime(from: Date())
        return allMealPlans.contains { plan in
            DateHelper.stripTime(from: plan.date) == today
                && plan.mealTypeRaw == MealType.dinner.rawValue
                && plan.recipe == recipe
        }
    }

    /// The meal plan entry for this recipe tomorrow, if any.
    /// Used to offer "Move to Tonight" instead of "Add to Tonight".
    private var tomorrowPlan: CDMealPlan? {
        let today = DateHelper.stripTime(from: Date())
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else {
            return nil
        }
        return allMealPlans.first(where: {
            DateHelper.stripTime(from: $0.date) == tomorrow && $0.recipe == recipe
        })
    }

    /// Label for the primary action button — reflects current planning state.
    private var tonightButtonLabel: String {
        if isAlreadyTonight { return "Tonight's Dinner" }
        if tomorrowPlan != nil { return "Move to Tonight" }
        return "Add to Tonight"
    }

    /// A short status string if this recipe is planned for today or tomorrow.
    /// Returns nil when not planned — the label is hidden entirely.
    private var plannedStatus: String? {
        let today = DateHelper.stripTime(from: Date())
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else {
            return nil
        }

        // Today — dinner first since it's the most prominent slot
        let todayPlans = allMealPlans.filter {
            DateHelper.stripTime(from: $0.date) == today && $0.recipe == recipe
        }
        if let dinner = todayPlans.first(where: { $0.mealType == .dinner }) {
            _ = dinner // prioritize dinner
            return "Planned for tonight"
        }
        if let other = todayPlans.first {
            return "Planned for today's \(other.mealType.rawValue.lowercased())"
        }

        // Tomorrow
        if let tomorrowPlan = allMealPlans.first(where: {
            DateHelper.stripTime(from: $0.date) == tomorrow && $0.recipe == recipe
        }) {
            return "Planned for tomorrow's \(tomorrowPlan.mealType.rawValue.lowercased())"
        }

        return nil
    }

    var body: some View {
        List {
            // MARK: - Tags + planned status
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.fluffyAccent.opacity(0.15))
                                .foregroundStyle(Color.fluffyAccent)
                                .clipShape(Capsule())
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                if let status = plannedStatus {
                    Label(status, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(Color.fluffySecondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
                }
            }

            // MARK: - Actions
            Section {
                // Primary: Add/Move to Tonight
                Button(action: addToTonight) {
                    HStack {
                        Spacer()
                        Label(
                            tonightButtonLabel,
                            systemImage: isAlreadyTonight ? "checkmark.circle.fill" : "moon.stars"
                        )
                        .font(.headline)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .disabled(isAlreadyTonight)
                .listRowBackground(isAlreadyTonight ? Color.fluffySecondary.opacity(0.2) : Color.fluffyAccent)
                .foregroundStyle(isAlreadyTonight ? Color.fluffySecondary : .white)

                // Secondary: Add to Meal Plan (pick date + meal type)
                Button(action: { showingMealPlanPicker = true }) {
                    HStack {
                        Spacer()
                        Label("Add to Meal Plan", systemImage: "calendar.badge.plus")
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                .foregroundStyle(Color.fluffyAccent)
                .listRowBackground(Color.fluffyCard)
            }

            // MARK: - Details
            Section("Details") {
                LabeledContent("Servings", value: "\(recipe.servings)")
                LabeledContent("Prep Time", value: "\(recipe.prepTimeMinutes) min")
                if recipe.cookTimeMinutes > 0 {
                    LabeledContent("Cook Time", value: "\(recipe.cookTimeMinutes) min")
                }
            }

            // MARK: - Ingredients
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

            // MARK: - Instructions
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
                    Text("Set your name in Settings to rate recipes.")
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
        .scrollContentBackground(.hidden)
        .background(Color.fluffyBackground)
        .navigationTitle(recipe.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditSheet = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    recipe.isFavorite.toggle()
                    try? viewContext.save()
                } label: {
                    Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(recipe.isFavorite ? .red : .secondary)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditRecipeView(recipeToEdit: recipe)
        }
        .sheet(isPresented: $showingMealPlanPicker) {
            MealPlanPickerSheet(recipe: recipe)
        }
        .alert("Delete this recipe?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewContext.delete(recipe)
                try? viewContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This can't be undone.")
        }
        // Confirmation toast overlay
        .overlay(alignment: .bottom) {
            if showAddedConfirmation {
                Label("Tonight: \(recipe.name)", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.fluffyPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showAddedConfirmation)
    }

    // MARK: - Add to Tonight

    /// Assigns this recipe to today's dinner slot via the central store.
    /// If the recipe was planned for tomorrow, clears that slot (a "move").
    private func addToTonight() {
        if let plan = tomorrowPlan {
            mealPlanningStore.clearMealSlot(date: plan.date, mealType: plan.mealType)
        }
        mealPlanningStore.assignRecipeToTonight(recipe)

        showAddedConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showAddedConfirmation = false
        }
    }

    // MARK: - Source Attribution

    /// Build a subtle "From: ..." attribution string, or nil for manual recipes.
    private var sourceAttribution: String? {
        guard let sourceType = recipe.sourceType else { return nil }

        switch sourceType {
        case .photo:
            if let detail = recipe.sourceDetail, !detail.isEmpty {
                return "From: \(detail)"
            }
            return nil
        case .url:
            if let detail = recipe.sourceDetail, !detail.isEmpty,
               let url = URL(string: detail), let host = url.host {
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

    // MARK: - Ratings Helpers

    /// The name used for storing ratings — uses the device identity if set,
    /// or a fixed solo label when no household members exist.
    private var effectiveRaterName: String {
        if !currentUserName.isEmpty {
            return currentUserName
        }
        return members.isEmpty ? "_solo" : ""
    }

    /// The current user's rating for this recipe, or 0 if they haven't rated yet.
    private var currentUserRating: Int {
        guard !effectiveRaterName.isEmpty else { return 0 }
        return Int(recipe.ratingsList
            .first { $0.raterName.lowercased() == effectiveRaterName.lowercased() }?
            .rating ?? 0)
    }

    /// Creates or updates the current user's rating for this recipe.
    private func setRating(_ newRating: Int) {
        let name = effectiveRaterName
        guard !name.isEmpty else { return }

        if let existing = recipe.ratingsList.first(where: {
            $0.raterName.lowercased() == name.lowercased()
        }) {
            existing.rating = Int16(newRating)
            existing.dateRated = Date()
        } else {
            let newRatingObj = CDRecipeRating(context: viewContext)
            newRatingObj.id = UUID()
            newRatingObj.raterName = name
            newRatingObj.rating = Int16(newRating)
            newRatingObj.dateRated = Date()
            newRatingObj.recipe = recipe
        }
        try? viewContext.save()
    }

    /// Format a single ingredient for display.
    /// "to taste" items: "Salt, to taste"
    /// "none" unit: "3 eggs"
    /// Normal: "1 1/2 cups all-purpose flour"
    private func formatIngredientDisplay(_ ingredient: CDIngredient) -> String {
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

// MARK: - Meal Plan Picker Sheet

/// Simple sheet for picking a date and meal type to assign a recipe.
private struct MealPlanPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MealPlanningStore.self) private var mealPlanningStore

    let recipe: CDRecipe
    @State private var selectedDate = Date()
    @State private var selectedMealType: MealType = .dinner

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                Picker("Meal", selection: $selectedMealType) {
                    ForEach(MealType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }
            .navigationTitle("Add to Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        mealPlanningStore.assignRecipe(
                            recipe,
                            on: selectedDate,
                            mealType: selectedMealType
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
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
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    let recipe = CDRecipe(context: context)
    recipe.id = UUID()
    recipe.name = "Spaghetti Bolognese"
    recipe.categoryRaw = RecipeCategory.dinner.rawValue
    recipe.servings = 4
    recipe.prepTimeMinutes = 45
    recipe.cookTimeMinutes = 0
    recipe.instructions = """
    1. Brown the ground beef in a large pan.
    2. Add diced onions and garlic, cook until soft.
    3. Add crushed tomatoes and Italian seasoning.
    4. Simmer for 20 minutes.
    5. Cook spaghetti according to package directions.
    6. Serve sauce over pasta.
    """
    recipe.dateCreated = Date()
    recipe.isFavorite = false
    recipe.sourceTypeRaw = RecipeSource.cookbook.rawValue
    recipe.sourceDetail = "The Joy of Cooking, p. 312"

    return NavigationStack {
        RecipeDetailView(recipe: recipe)
    }
    .environment(\.managedObjectContext, context)
}
