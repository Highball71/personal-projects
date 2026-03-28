//
//  MealPlan.swift
//  FluffyList
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
    var mealTypeRaw: String = MealType.dinner.rawValue

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .dinner }
        set { mealTypeRaw = newValue.rawValue }
    }

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
