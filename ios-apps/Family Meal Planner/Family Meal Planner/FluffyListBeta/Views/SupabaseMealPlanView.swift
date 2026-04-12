//
//  SupabaseMealPlanView.swift
//  FluffyList
//
//  Phase 1 meal plan: 7 days, one recipe per day, no meal types.
//  Assigning a recipe to a day fetches its ingredients and inserts
//  them into the household's grocery list (no dedup, no merging).
//

import os
import SwiftUI

struct SupabaseMealPlanView: View {
    @EnvironmentObject private var mealPlanService: MealPlanService
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var groceryService: GroceryService

    @State private var weekStart: Date = DateHelper.startOfWeek(containing: Date())
    @State private var pickerDate: Date?
    @State private var isAssigning = false
    @State private var showingAddedToGrocery = false

    /// The 7 dates of the current week.
    private var weekDates: [Date] {
        (0..<7).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if mealPlanService.isLoading && mealPlanService.plansByDate.isEmpty {
                    ProgressView("Loading meal plan...")
                } else {
                    dayList
                }
            }
            .navigationTitle("Meal Plan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(weekHeader)
                        .font(.caption)
                        .foregroundStyle(Color.fluffySecondary)
                }
            }
            .refreshable {
                await mealPlanService.fetchPlans(weekStart: weekStart)
            }
            .task {
                await mealPlanService.fetchPlans(weekStart: weekStart)
                if recipeService.recipes.isEmpty {
                    await recipeService.fetchRecipes()
                }
            }
            .sheet(item: $pickerDate) { date in
                RecipePickerSheet(
                    recipes: recipeService.recipes,
                    onPick: { recipe in
                        Task { await assignRecipe(recipe, to: date) }
                        pickerDate = nil
                    },
                    onCancel: {
                        pickerDate = nil
                    }
                )
            }
            .overlay { assigningOverlay }
            .overlay { addedToGroceryOverlay }
        }
    }

    // MARK: - Week header

    private var weekHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: weekStart)
        let end = formatter.string(from: weekDates.last ?? weekStart)
        return "\(start) – \(end)"
    }

    // MARK: - Day list

    private var dayList: some View {
        List {
            ForEach(weekDates, id: \.self) { date in
                dayRow(date)
                    .swipeActions(edge: .trailing) {
                        if let existing = plan(for: date) {
                            Button("Clear", role: .destructive) {
                                Task { await clearDay(date: date, planID: existing.id) }
                            }
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    private func dayRow(_ date: Date) -> some View {
        Button {
            pickerDate = date
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayName(for: date))
                        .font(.caption)
                        .foregroundStyle(Color.fluffySecondary)
                    Text(dayNumber(for: date))
                        .font(.title3.bold())
                        .foregroundStyle(Color.fluffyPrimary)
                }
                .frame(width: 52, alignment: .leading)

                if let recipe = recipeFor(date: date) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recipe.name)
                            .font(.headline)
                            .foregroundStyle(Color.fluffyPrimary)
                        Text(recipe.category.capitalized)
                            .font(.caption)
                            .foregroundStyle(Color.fluffySecondary)
                    }
                } else {
                    Text("Tap to add a recipe")
                        .font(.subheadline)
                        .foregroundStyle(Color.fluffySecondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.fluffySecondary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .tint(Color.fluffyPrimary)
    }

    // MARK: - Overlays

    @ViewBuilder
    private var assigningOverlay: some View {
        if isAssigning {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView().scaleEffect(1.3)
                    Text("Adding to meal plan...")
                        .font(.headline)
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    @ViewBuilder
    private var addedToGroceryOverlay: some View {
        if showingAddedToGrocery {
            VStack(spacing: 8) {
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.fluffyAccent)
                Text("Ingredients added\nto grocery list")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .transition(.opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showingAddedToGrocery = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func dayName(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func dayNumber(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func plan(for date: Date) -> MealPlanRow? {
        mealPlanService.plansByDate[MealPlanService.isoDate(from: date)]
    }

    private func recipeFor(date: Date) -> RecipeRow? {
        guard let plan = plan(for: date),
              let recipeID = plan.recipeID else { return nil }
        return recipeService.recipes.first { $0.id == recipeID }
    }

    // MARK: - Orchestration

    /// Upsert a meal plan row, then fetch the recipe's ingredients and
    /// bulk-insert them as grocery items. No deduping in Phase 1.
    private func assignRecipe(_ recipe: RecipeRow, to date: Date) async {
        isAssigning = true
        defer { isAssigning = false }

        // 1. If this day already has a recipe, remove its old grocery
        //    contributions first. The upsert below may reuse the same
        //    meal plan row ID, so the old contributions would end up
        //    linked to the wrong recipe if we didn't clean them up.
        if let existing = plan(for: date) {
            Logger.supabase.info("MealPlan assign: day already has plan \(existing.id.uuidString), removing contributions first")
            _ = await groceryService.removeContributions(forMealPlan: existing.id)
        }

        // 2. Upsert meal plan row and get its ID
        guard let newPlanID = await mealPlanService.assignRecipe(recipeID: recipe.id, on: date) else {
            return
        }

        // 3. Refresh the meal plan so the UI updates
        await mealPlanService.fetchPlans(weekStart: weekStart)

        // 4. Fetch the recipe's ingredients
        let ingredients = await recipeService.fetchIngredients(for: recipe.id)
        Logger.supabase.info("MealPlan assign: fetched \(ingredients.count) ingredient(s) for recipe \(recipe.id.uuidString)")

        guard !ingredients.isEmpty else {
            Logger.supabase.info("MealPlan assign: no ingredients to add to grocery list")
            return
        }

        // 5. Insert grocery items with contributions linked to the new plan
        guard let householdID = SupabaseManager.shared.currentHouseholdID else { return }
        let inserts = ingredients
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { ing in
                GroceryItemInsert(
                    householdID: householdID,
                    name: ing.name,
                    quantity: ing.quantity,
                    unit: ing.unit
                )
            }

        Logger.supabase.info("MealPlan assign: inserting \(inserts.count) grocery item(s) for plan \(newPlanID.uuidString)")
        let added = await groceryService.addItemsForMealPlan(mealPlanID: newPlanID, items: inserts)
        if added {
            withAnimation { showingAddedToGrocery = true }
        }
    }

    /// Clear a day's meal plan and remove its grocery contributions.
    /// Order matters: remove contributions first (they need the meal
    /// plan ID), then delete the meal plan row.
    private func clearDay(date: Date, planID: UUID) async {
        Logger.supabase.info("MealPlan clearDay: planID=\(planID.uuidString)")

        // 1. Remove grocery contributions (subtracts quantities, deletes
        //    items that would go to zero)
        _ = await groceryService.removeContributions(forMealPlan: planID)

        // 2. Delete the meal plan row itself
        _ = await mealPlanService.clearSlot(on: date)
    }
}

// MARK: - Recipe Picker Sheet

private struct RecipePickerSheet: View {
    let recipes: [RecipeRow]
    let onPick: (RecipeRow) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.fluffySecondary)
                        Text("No recipes yet")
                            .font(.headline)
                        Text("Add recipes in the Recipes tab first.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(recipes) { recipe in
                            Button {
                                onPick(recipe)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(recipe.name)
                                            .font(.headline)
                                            .foregroundStyle(Color.fluffyPrimary)
                                        Text(recipe.category.capitalized)
                                            .font(.caption)
                                            .foregroundStyle(Color.fluffySecondary)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .tint(Color.fluffyPrimary)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Choose a Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }
}

// MARK: - Date Identifiable

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}
