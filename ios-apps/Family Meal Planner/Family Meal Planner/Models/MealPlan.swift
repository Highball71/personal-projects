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
    var date: Date = Date()
    var mealType: MealType = MealType.dinner

    // Explicit inverse of Recipe.mealPlans — CloudKit requires
    // every relationship to declare its inverse.
    @Relationship(inverse: \Recipe.mealPlans)
    var recipe: Recipe?

    init(date: Date, mealType: MealType, recipe: Recipe? = nil) {
        self.date = date
        self.mealType = mealType
        self.recipe = recipe
    }
}
