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
    @State private var toastMessage: String?

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
            .navigationTitle("This Week")
            .navigationBarTitleDisplayMode(.inline)
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
                        pickerDate = nil  // close picker immediately
                        Task { await assignRecipe(recipe, to: date) }
                    },
                    onCancel: {
                        pickerDate = nil
                    }
                )
            }
            .overlay { assigningOverlay }
            .overlay { toastOverlay }
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
            Section {
                Text(weekHeader)
                    .font(.subheadline)
                    .foregroundStyle(Color.fluffySecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

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
    private var toastOverlay: some View {
        if let message = toastMessage {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                Text(message)
                    .font(.headline)
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

    // MARK: - Helpers

    private func dayName(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    /// Full day name for toast messages ("Monday", "Tuesday", ...).
    private func fullDayName(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
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

    /// Delegates to MealPlanService's full assign-and-groceries pipeline.
    /// Shows a day-specific success toast on success.
    private func assignRecipe(_ recipe: RecipeRow, to date: Date) async {
        isAssigning = true
        defer { isAssigning = false }

        let existingPlanID = plan(for: date)?.id

        let result = await mealPlanService.assignRecipeWithGroceries(
            recipe: recipe,
            on: date,
            existingPlanID: existingPlanID,
            recipeService: recipeService,
            groceryService: groceryService
        )

        guard result != nil else { return }

        // Refresh meal plan UI
        await mealPlanService.fetchPlans(weekStart: weekStart)

        // Success feedback with the target day's name
        let message = "Added to \(fullDayName(for: date))"
        withAnimation { toastMessage = message }
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
                        Section {
                            Button {
                                // Random pick — reuses onPick so the parent's
                                // full assignment + grocery pipeline fires.
                                if let pick = recipes.randomElement() {
                                    Logger.supabase.info("Surprise Me: picked \"\(pick.name)\" id=\(pick.id.uuidString)")
                                    onPick(pick)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "dice.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.fluffyAccent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Surprise Me")
                                            .font(.headline)
                                            .foregroundStyle(Color.fluffyPrimary)
                                        Text("Pick a random recipe")
                                            .font(.caption)
                                            .foregroundStyle(Color.fluffySecondary)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .tint(Color.fluffyPrimary)
                        }

                        Section("All Recipes") {
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
                    }
                    .listStyle(.insetGrouped)
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
