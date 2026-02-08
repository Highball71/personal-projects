//
//  MealPlan.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import Foundation
import SwiftData

/// Assigns a recipe to a specific date and meal slot.
/// Example: "Monday dinner = Spaghetti Bolognese"
@Model
final class MealPlan {
    var date: Date
    var mealType: MealType

    // .nullify means: if the linked recipe is deleted, this meal plan
    // entry stays but its recipe becomes nil (an empty slot).
    var recipe: Recipe?

    init(date: Date, mealType: MealType, recipe: Recipe? = nil) {
        self.date = date
        self.mealType = mealType
        self.recipe = recipe
    }
}
