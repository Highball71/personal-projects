//
//  RecipeCategory.swift
//  FluffyList
//
//  Created by David Albert on 2/8/26.
//

import Foundation

/// Categories for organizing recipes.
/// - Codable: required by SwiftData's @Model macro — getValue/setValue overload
///   resolution depends on the stored property type conforming to Codable.
/// - CaseIterable: lets us loop over all cases in Pickers
/// - Identifiable: required for SwiftUI's ForEach
enum RecipeCategory: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    case dessert = "Dessert"
    case side = "Side Dish"
    case drink = "Drink"

    var id: String { rawValue }
}
