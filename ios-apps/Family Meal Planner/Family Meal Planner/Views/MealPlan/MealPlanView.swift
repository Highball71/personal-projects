//
//  MealPlanView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import SwiftData

/// Captures the date + meal type for a tapped slot so the recipe picker
/// sheet always has valid data when it renders.
struct MealSlotSelection: Identifiable {
    let id = UUID()
    let date: Date
    let mealType: MealType
}

/// The weekly meal planning view. Shows 7 days in a vertical scroll,
/// each with breakfast/lunch/dinner slots. Navigate between weeks
/// with the arrow buttons at the top.
struct MealPlanView: View {
    @Query private var allMealPlans: [MealPlan]
    @Environment(\.modelContext) private var modelContext

    // The first day of the currently displayed week
    @State private var weekStartDate = DateHelper.startOfWeek(containing: Date())

    // State for the recipe picker sheet — using a single identifiable value
    // so .sheet(item:) guarantees the data is available when the sheet renders
    @State private var selectedSlot: MealSlotSelection?

    /// The 7 days of the currently displayed week
    var weekDays: [Date] {
        DateHelper.weekDays(startingFrom: weekStartDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    weekNavigationHeader

                    ForEach(weekDays, id: \.self) { day in
                        DayColumnView(
                            date: day,
                            mealPlans: mealPlans(for: day),
                            onSlotTapped: { mealType in
                                selectedSlot = MealSlotSelection(date: day, mealType: mealType)
                            },
                            onSlotCleared: { mealType in
                                clearMealSlot(date: day, mealType: mealType)
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Meal Plan")
            .sheet(item: $selectedSlot) { slot in
                RecipePickerView { recipe in
                    assignRecipe(recipe, to: slot.date, for: slot.mealType)
                }
            }
        }
    }

    // MARK: - Week Navigation

    private var weekNavigationHeader: some View {
        HStack {
            Button(action: goToPreviousWeek) {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(weekRangeText)
                .font(.headline)

            Spacer()

            Button(action: goToNextWeek) {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
    }

    /// Displays something like "Feb 3 - Feb 9"
    private var weekRangeText: String {
        let start = DateHelper.dayMonth(for: weekStartDate)
        let end = DateHelper.dayMonth(for: weekDays.last ?? weekStartDate)
        return "\(start) – \(end)"
    }

    private func goToPreviousWeek() {
        weekStartDate = Calendar.current.date(
            byAdding: .weekOfYear, value: -1, to: weekStartDate
        ) ?? weekStartDate
    }

    private func goToNextWeek() {
        weekStartDate = Calendar.current.date(
            byAdding: .weekOfYear, value: 1, to: weekStartDate
        ) ?? weekStartDate
    }

    // MARK: - Meal Plan Data

    /// Get just the meal plans for a specific day
    private func mealPlans(for date: Date) -> [MealPlan] {
        let dayStart = DateHelper.stripTime(from: date)
        return allMealPlans.filter { DateHelper.stripTime(from: $0.date) == dayStart }
    }

    /// Assign a recipe to a specific day and meal type.
    /// If a slot already has a recipe, it gets replaced.
    private func assignRecipe(_ recipe: Recipe, to date: Date, for mealType: MealType) {
        let dayStart = DateHelper.stripTime(from: date)

        // Check if there's already a meal plan for this slot
        if let existing = allMealPlans.first(where: {
            DateHelper.stripTime(from: $0.date) == dayStart && $0.mealType == mealType
        }) {
            existing.recipe = recipe
        } else {
            let mealPlan = MealPlan(date: dayStart, mealType: mealType, recipe: recipe)
            modelContext.insert(mealPlan)
        }
    }

    /// Remove the recipe from a meal slot
    private func clearMealSlot(date: Date, mealType: MealType) {
        let dayStart = DateHelper.stripTime(from: date)
        if let existing = allMealPlans.first(where: {
            DateHelper.stripTime(from: $0.date) == dayStart && $0.mealType == mealType
        }) {
            modelContext.delete(existing)
        }
    }
}

#Preview {
    MealPlanView()
        .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self], inMemory: true)
}
