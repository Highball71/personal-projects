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

/// Tracks which sheet to present from the meal plan view.
/// Using a single enum avoids conflicts from multiple .sheet modifiers.
enum MealPlanSheet: Identifiable {
    case pickRecipe(MealSlotSelection)
    case surpriseMe(MealSlotSelection)
    case suggestWeek

    var id: String {
        switch self {
        case .pickRecipe(let s): return "pick-\(s.id)"
        case .surpriseMe(let s): return "surprise-\(s.id)"
        case .suggestWeek: return "suggest"
        }
    }

    /// The slot this sheet action is targeting (nil for week-level suggestions)
    var slot: MealSlotSelection? {
        switch self {
        case .pickRecipe(let s), .surpriseMe(let s): return s
        case .suggestWeek: return nil
        }
    }
}

/// The weekly meal planning view. Shows 7 days in a vertical scroll,
/// each with breakfast/lunch/dinner slots. Navigate between weeks
/// with the arrow buttons at the top.
struct MealPlanView: View {
    @Query private var allMealPlans: [MealPlan]
    @Environment(\.modelContext) private var modelContext

    // The first day of the currently displayed week
    @State private var weekStartDate = DateHelper.startOfWeek(containing: Date())

    // The slot the user just tapped — drives the confirmation dialog
    @State private var selectedSlot: MealSlotSelection?
    @State private var showingSlotOptions = false

    // Drives whichever sheet is currently presented
    @State private var activeSheet: MealPlanSheet?

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
                                showingSlotOptions = true
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { activeSheet = .suggestWeek }) {
                        Image(systemName: "die.face.5")
                    }
                }
            }
            // "Pick a Recipe" vs "Surprise Me" choice when tapping a slot
            .confirmationDialog(
                "",
                isPresented: $showingSlotOptions,
                presenting: selectedSlot
            ) { slot in
                Button("Pick a Recipe") {
                    activeSheet = .pickRecipe(slot)
                }
                Button("Surprise Me") {
                    activeSheet = .surpriseMe(slot)
                }
            }
            // Single sheet modifier handles all presentation
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .pickRecipe(let slot):
                    RecipePickerView { recipe in
                        assignRecipe(recipe, to: slot.date, for: slot.mealType)
                    }
                case .surpriseMe(let slot):
                    SurpriseMealView { recipe in
                        assignRecipe(recipe, to: slot.date, for: slot.mealType)
                    }
                case .suggestWeek:
                    SuggestMealsView(weekStartDate: weekStartDate) { suggestions in
                        for (date, recipe) in suggestions {
                            assignRecipe(recipe, to: date, for: .dinner)
                        }
                    }
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
