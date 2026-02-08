//
//  IngredientUnit.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import Foundation

/// Common measurement units for cooking ingredients.
enum IngredientUnit: String, Codable, CaseIterable, Identifiable {
    case piece = "piece"
    case cup = "cup"
    case tablespoon = "tbsp"
    case teaspoon = "tsp"
    case ounce = "oz"
    case pound = "lb"
    case gram = "g"
    case liter = "L"
    case milliliter = "mL"
    case pinch = "pinch"
    case whole = "whole"

    var id: String { rawValue }
}
