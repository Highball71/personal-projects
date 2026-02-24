//
//  MealSuggestion.swift
//  Family Meal Planner
//

import Foundation
import SwiftData

/// A recipe suggestion from a household member for a specific meal slot.
/// When a Head Cook is set, non-Head-Cook members create suggestions
/// instead of directly assigning recipes to the meal plan.
/// The Head Cook can then approve (promotes to MealPlan) or reject them.
///
/// Syncs via CloudKit so the Head Cook sees suggestions from all devices.
@Model
final class MealSuggestion {
    var date: Date = Date()
    var mealType: MealType = MealType.dinner
    var suggestedBy: String = ""
    var dateCreated: Date = Date()

    // Explicit inverse of Recipe.suggestions — CloudKit requires
    // every relationship to declare its inverse.
    @Relationship(inverse: \Recipe.suggestions)
    var recipe: Recipe?

    init(date: Date, mealType: MealType, suggestedBy: String, recipe: Recipe) {
        self.date = date
        self.mealType = mealType
        self.suggestedBy = suggestedBy
        self.dateCreated = Date()
        self.recipe = recipe
    }
}
