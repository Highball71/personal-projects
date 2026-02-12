//
//  IngredientUnit.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import Foundation

/// Common measurement units for cooking ingredients.
/// Raw values are persisted in SwiftData — don't change existing ones.
/// The `displayName` property provides human-readable labels for the UI.
enum IngredientUnit: String, Codable, CaseIterable, Identifiable {
    // Volume — small to large
    case teaspoon = "tsp"
    case tablespoon = "tbsp"
    case cup = "cup"
    case fluidOunce = "fl oz"
    case milliliter = "mL"
    case liter = "L"

    // Weight — small to large
    case ounce = "oz"
    case pound = "lb"
    case gram = "g"
    case kilogram = "kg"

    // Count / descriptive
    case none = "—"
    case piece = "piece"
    case pinch = "pinch"
    case clove = "clove"
    case can = "can"
    case package = "package"
    case bunch = "bunch"
    case sprig = "sprig"
    case dash = "dash"
    case toTaste = "to taste"

    // Legacy — kept for backwards compatibility with existing data
    case whole = "whole"

    var id: String { rawValue }

    /// Human-readable name for pickers and display.
    var displayName: String {
        switch self {
        case .none: "(none)"
        case .teaspoon: "tsp"
        case .tablespoon: "tbsp"
        case .cup: "cup"
        case .fluidOunce: "fl oz"
        case .milliliter: "mL"
        case .liter: "L"
        case .ounce: "oz"
        case .pound: "lb"
        case .gram: "g"
        case .kilogram: "kg"
        case .piece: "piece"
        case .pinch: "pinch"
        case .clove: "clove"
        case .can: "can"
        case .package: "package"
        case .bunch: "bunch"
        case .sprig: "sprig"
        case .dash: "dash"
        case .toTaste: "to taste"
        case .whole: "whole"
        }
    }

    /// Units shown in the picker, in cooking-friendly order.
    /// Excludes legacy cases like `.whole`.
    static var pickerCases: [IngredientUnit] {
        [
            .none,
            .teaspoon, .tablespoon, .cup,
            .ounce, .pound,
            .fluidOunce, .milliliter, .liter,
            .gram, .kilogram,
            .piece, .pinch, .clove, .can, .package,
            .bunch, .sprig, .dash, .toTaste,
        ]
    }
}
