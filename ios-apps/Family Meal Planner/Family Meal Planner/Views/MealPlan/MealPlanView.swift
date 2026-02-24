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
///
/// When a Head Cook is set, non-Head-Cook users create suggestions
/// instead of directly filling meal slots. The Head Cook sees
/// approve/reject controls next to each suggestion.
struct MealPlanView: View {
    @Query private var allMealPlans: [MealPlan]
    @Query private var allSuggestions: [MealSuggestion]
    @Query private var members: [HouseholdMember]
    @Environment(\.modelContext) private var modelContext

    // Device-local identity — matches the "You are" picker in Settings
    @AppStorage("currentUserName") private var currentUserName: String = ""

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

    /// The designated Head Cook, if one is set
    private var headCook: HouseholdMember? {
        members.first(where: { $0.isHeadCook })
    }

    /// Whether the current device user is the Head Cook
    private var isCurrentUserHeadCook: Bool {
        guard let headCook else { return false }
        return !currentUserName.isEmpty
            && headCook.name.lowercased() == currentUserName.lowercased()
    }

    /// Whether the approval flow is active (Head Cook is set)
    private var approvalFlowActive: Bool {
        headCook != nil
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
                            suggestions: suggestions(for: day),
                            isHeadCook: isCurrentUserHeadCook,
                            approvalFlowActive: approvalFlowActive,
                            onSlotTapped: { mealType in
                                selectedSlot = MealSlotSelection(date: day, mealType: mealType)
                                showingSlotOptions = true
                            },
                            onSlotCleared: { mealType in
                                clearMealSlot(date: day, mealType: mealType)
                            },
                            onApproveSuggestion: { suggestion in
                                approveSuggestion(suggestion)
                            },
                            onRejectSuggestion: { suggestion in
                                rejectSuggestion(suggestion)
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
                        handleRecipeSelection(recipe, for: slot)
                    }
                case .surpriseMe(let slot):
                    SurpriseMealView { recipe in
                        handleRecipeSelection(recipe, for: slot)
                    }
                case .suggestWeek:
                    SuggestMealsView(weekStartDate: weekStartDate) { suggestions in
                        for (date, recipe) in suggestions {
                            let slot = MealSlotSelection(date: date, mealType: .dinner)
                            handleRecipeSelection(recipe, for: slot)
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

    /// Get pending suggestions for a specific day
    private func suggestions(for date: Date) -> [MealSuggestion] {
        let dayStart = DateHelper.stripTime(from: date)
        return allSuggestions.filter { DateHelper.stripTime(from: $0.date) == dayStart }
    }

    // MARK: - Recipe Selection Logic

    /// Decides whether to assign directly or create a suggestion based on
    /// whether a Head Cook is set and who the current user is.
    private func handleRecipeSelection(_ recipe: Recipe, for slot: MealSlotSelection) {
        if approvalFlowActive && !isCurrentUserHeadCook {
            // Non-Head-Cook user: create a suggestion for the Head Cook to review
            createSuggestion(recipe, for: slot)
        } else {
            // No Head Cook set, or current user IS the Head Cook: assign directly
            assignRecipe(recipe, to: slot.date, for: slot.mealType)
        }
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

    /// Create a suggestion instead of directly assigning.
    private func createSuggestion(_ recipe: Recipe, for slot: MealSlotSelection) {
        let dayStart = DateHelper.stripTime(from: slot.date)
        let suggestion = MealSuggestion(
            date: dayStart,
            mealType: slot.mealType,
            suggestedBy: currentUserName,
            recipe: recipe
        )
        modelContext.insert(suggestion)
    }

    /// Head Cook approves a suggestion: promotes it to a MealPlan entry.
    private func approveSuggestion(_ suggestion: MealSuggestion) {
        guard let recipe = suggestion.recipe else { return }
        assignRecipe(recipe, to: suggestion.date, for: suggestion.mealType)
        modelContext.delete(suggestion)
    }

    /// Head Cook rejects a suggestion: removes it.
    private func rejectSuggestion(_ suggestion: MealSuggestion) {
        modelContext.delete(suggestion)
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
        .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self, MealSuggestion.self, HouseholdMember.self], inMemory: true)
}
