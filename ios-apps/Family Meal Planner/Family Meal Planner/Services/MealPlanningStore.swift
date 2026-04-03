//
//  MealPlanningStore.swift
//  FluffyList
//
//  Central service for meal plan mutations — assigning recipes to
//  meal slots, managing suggestions, and clearing slots.
//
//  Views call these methods instead of doing Core Data persistence
//  directly. Views still own their own @FetchRequest queries for
//  reactive display; this store owns all writes.
//

import CoreData
import Foundation

@MainActor @Observable
final class MealPlanningStore {

    private let persistence: PersistenceController

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    /// Convenience initializer using the shared persistence controller.
    convenience init() {
        self.init(persistence: .shared)
    }

    // MARK: - Meal Assignment

    /// Assigns a recipe to today's dinner slot.
    /// Convenience wrapper around `assignRecipe(_:on:mealType:)`.
    func assignRecipeToTonight(_ recipe: CDRecipe) {
        assignRecipe(recipe, on: Date(), mealType: .dinner)
    }

    /// Assigns a recipe to a specific date and meal type.
    /// If the slot already has a recipe, it gets replaced.
    func assignRecipe(_ recipe: CDRecipe, on date: Date, mealType: MealType) {
        let dayStart = DateHelper.stripTime(from: date)

        if let existing = fetchMealPlan(for: dayStart, mealType: mealType) {
            existing.recipe = recipe
        } else {
            let mealPlan = CDMealPlan(context: viewContext)
            mealPlan.id = UUID()
            mealPlan.date = dayStart
            mealPlan.mealTypeRaw = mealType.rawValue
            mealPlan.recipe = recipe
        }
        try? viewContext.save()
    }

    /// Removes the recipe from a meal slot.
    func clearMealSlot(date: Date, mealType: MealType) {
        let dayStart = DateHelper.stripTime(from: date)
        if let existing = fetchMealPlan(for: dayStart, mealType: mealType) {
            viewContext.delete(existing)
            try? viewContext.save()
        }
    }

    // MARK: - Suggestions (Head Cook Flow)

    /// Creates a suggestion for the Head Cook to review.
    func createSuggestion(
        _ recipe: CDRecipe,
        on date: Date,
        mealType: MealType,
        suggestedBy: String
    ) {
        let dayStart = DateHelper.stripTime(from: date)
        let suggestion = CDMealSuggestion(context: viewContext)
        suggestion.id = UUID()
        suggestion.date = dayStart
        suggestion.mealTypeRaw = mealType.rawValue
        suggestion.suggestedBy = suggestedBy
        suggestion.dateCreated = Date()
        suggestion.recipe = recipe
        try? viewContext.save()
    }

    /// Head Cook approves a suggestion — promotes it to a real MealPlan entry
    /// and deletes the suggestion.
    func approveSuggestion(_ suggestion: CDMealSuggestion) {
        guard let recipe = suggestion.recipe else { return }
        assignRecipe(recipe, on: suggestion.date, mealType: suggestion.mealType)
        viewContext.delete(suggestion)
        try? viewContext.save()
    }

    /// Head Cook rejects a suggestion — deletes it.
    func rejectSuggestion(_ suggestion: CDMealSuggestion) {
        viewContext.delete(suggestion)
        try? viewContext.save()
    }

    // MARK: - Private

    /// Fetches the existing meal plan for a specific day and meal type, if any.
    private func fetchMealPlan(for dayStart: Date, mealType: MealType) -> CDMealPlan? {
        let request = CDMealPlan.fetchRequest()
        request.predicate = NSPredicate(
            format: "date == %@ AND mealTypeRaw == %@",
            dayStart as NSDate,
            mealType.rawValue
        )
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }
}
