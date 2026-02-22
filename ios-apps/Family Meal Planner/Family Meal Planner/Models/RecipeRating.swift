//
//  RecipeRating.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/22/26.
//

import Foundation
import SwiftData

/// A single person's 1–5 star rating of a recipe.
/// Each household member can rate each recipe independently.
/// CloudKit syncs ratings so everyone sees each other's scores.
@Model
final class RecipeRating {
    var raterName: String = ""
    var rating: Int = 3          // 1-5
    var dateRated: Date = Date()

    @Relationship(inverse: \Recipe.ratings)
    var recipe: Recipe?

    init(raterName: String, rating: Int, recipe: Recipe) {
        self.raterName = raterName
        self.rating = rating
        self.dateRated = Date()
        self.recipe = recipe
    }
}
