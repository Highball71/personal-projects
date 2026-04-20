//
//  ExtractedRecipe.swift
//  FluffyList
//

import Foundation

/// The JSON shape Claude returns when extracting a recipe from a photo.
/// Field names and types match the prompt spec exactly.
/// Computed properties convert these into the app's internal form types.
struct ExtractedRecipe: Codable {
    let name: String
    let category: String
    let servingSize: String?
    let prepTime: String?
    let cookTime: String?
    let ingredients: [ExtractedIngredient]
    let instructions: [String]
    let source: String?
    // The fields below are `var` instead of `let` because Swift's
    // synthesized Codable decoder warns that "let foo: T? = nil"
    // properties are skipped at decode time (the default is treated
    // as a permanent assignment). With `var` the decoder writes the
    // JSON value, and the memberwise init keeps the `= nil` default
    // so existing positional callers (JSONLDRecipeParser) still work.
    /// Recipe headnote / intro paragraph above the ingredients block.
    var description: String? = nil
    /// Total time as printed on the page when separately stated
    /// ("Total: 35 min"). Captured for future surfacing; the form
    /// doesn't expose a totalTime field today, so this lives in the
    /// in-memory model only.
    var totalTime: String? = nil
    /// Combined Notes / Tips / Storage / Make-Ahead / Substitutions
    /// text. The prompt asks Claude to merge these into a single
    /// string with section labels preserved inline so downstream code
    /// has only one notes field to think about.
    var notes: String? = nil
    /// Course / cuisine / keyword tags. Captured for future surfacing;
    /// the schema has no tags column today.
    var tags: [String]? = nil

    /// Map Claude's category string to the app's RecipeCategory enum.
    /// Falls back to .dinner if no match.
    var recipeCategory: RecipeCategory {
        switch category.lowercased() {
        case "breakfast":  return .breakfast
        case "lunch":      return .lunch
        case "dinner":     return .dinner
        case "snack":      return .snack
        case "dessert":    return .dessert
        case "side":       return .side
        case "drink":      return .drink
        default:           return .dinner
        }
    }

    /// Parse servingSize string (e.g. "4", "4 servings", "4-6") into an Int.
    /// Extracts the first number found; defaults to 4.
    var servingsInt: Int {
        guard let text = servingSize else { return 4 }
        // Find the first sequence of digits in the string
        let digits = text.prefix(while: { $0.isNumber || $0 == " " })
            .trimmingCharacters(in: .whitespaces)
        if let value = Int(digits), value > 0 {
            return value
        }
        // Try extracting any number from the string
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = CharacterSet.decimalDigits.inverted
        if let value = scanner.scanInt(), value > 0 {
            return value
        }
        return 4
    }

    /// Parse prepTime string (e.g. "30 minutes", "1 hour", "1 hour 30 minutes")
    /// into total minutes. Defaults to 30.
    var prepTimeMinutesInt: Int {
        parseMinutes(from: prepTime) ?? 30
    }

    /// Parse cookTime string into total minutes. Defaults to 0 (unknown).
    var cookTimeMinutesInt: Int {
        parseMinutes(from: cookTime) ?? 0
    }

    /// Join the instructions array into a single string for the form's TextEditor.
    /// Numbers each step for readability.
    var instructionsText: String {
        if instructions.count == 1 {
            return instructions[0]
        }
        return instructions.enumerated().map { index, step in
            "\(index + 1). \(step)"
        }.joined(separator: "\n")
    }

    /// Convert extracted ingredients to IngredientFormData for the
    /// recipe form. Section headers and preparation notes — which
    /// don't have dedicated DB columns — are folded into the displayed
    /// name string so the information isn't dropped on save.
    ///
    /// Display format: `[Section] Name, preparation`
    var ingredientFormRows: [IngredientFormData] {
        ingredients.map { extracted in
            IngredientFormData(
                name: foldedIngredientName(extracted),
                quantity: extracted.quantityDouble,
                unit: extracted.ingredientUnit,
                quantityText: FractionFormatter.formatAsFraction(extracted.quantityDouble)
            )
        }
    }

    private func foldedIngredientName(_ ingredient: ExtractedIngredient) -> String {
        var pieces: [String] = []
        if let section = ingredient.section?.trimmingCharacters(in: .whitespacesAndNewlines),
           !section.isEmpty {
            pieces.append("[\(section)]")
        }
        let baseName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let prep = ingredient.preparation?.trimmingCharacters(in: .whitespacesAndNewlines)
        // If the extractor produced an empty `name` but did produce a
        // preparation note (Claude occasionally does this with loosely
        // structured recipes), promote the preparation into the name
        // slot so the row doesn't render blank. Without this guard
        // URL-imported ingredients could land in the form with only a
        // unit pill visible.
        if baseName.isEmpty, let prep, !prep.isEmpty {
            pieces.append(prep)
        } else if let prep, !prep.isEmpty {
            pieces.append("\(baseName), \(prep)")
        } else {
            pieces.append(baseName)
        }
        return pieces.joined(separator: " ")
    }

    /// Parse a time string like "30 minutes", "1 hour", "1 hour 30 minutes" into minutes.
    private func parseMinutes(from text: String?) -> Int? {
        guard let text = text?.lowercased() else { return nil }

        var totalMinutes = 0
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = .whitespaces

        while !scanner.isAtEnd {
            guard let number = scanner.scanInt() else {
                // Skip one character and try again
                _ = scanner.scanCharacter()
                continue
            }

            // Look ahead for a unit word
            let remaining = String(text[scanner.currentIndex...]).trimmingCharacters(in: .whitespaces)
            if remaining.hasPrefix("hour") {
                totalMinutes += number * 60
                // Skip past the unit word
                scanner.currentIndex = text.index(scanner.currentIndex, offsetBy: min(remaining.count, remaining.hasPrefix("hours") ? 5 : 4), limitedBy: text.endIndex) ?? scanner.currentIndex
            } else {
                // Default: treat bare numbers or "minutes"/"min" as minutes
                totalMinutes += number
                if remaining.hasPrefix("min") {
                    scanner.currentIndex = text.index(scanner.currentIndex, offsetBy: min(remaining.count, remaining.hasPrefix("minutes") ? 7 : 3), limitedBy: text.endIndex) ?? scanner.currentIndex
                }
            }
        }

        return totalMinutes > 0 ? totalMinutes : nil
    }
}

/// A single ingredient as extracted by Claude.
struct ExtractedIngredient: Codable {
    let name: String
    let amount: String
    let unit: String
    // `var` so Codable's synthesized decoder will populate these from
    // JSON — `let foo: T? = nil` would silently skip them. See note
    // on ExtractedRecipe's optional fields above.
    /// Section header this ingredient sits under in the recipe — e.g.
    /// "Sauce", "Sauce (optional)", "For the topping". Nil when the
    /// recipe has a single flat ingredient list. Folded into the
    /// display name in `ExtractedRecipe.ingredientFormRows` so it
    /// survives into the form without a DB schema change.
    var section: String? = nil
    /// Preparation / state note that printed alongside the ingredient
    /// (e.g. "sliced and divided", "softened, room temperature"). Same
    /// folding strategy as `section` — appended to the form name.
    var preparation: String? = nil

    /// Parse the amount string into a Double.
    /// Handles integers ("2"), decimals ("1.5"), and fractions ("1/2", "1 1/2").
    var quantityDouble: Double {
        let trimmed = amount.trimmingCharacters(in: .whitespaces)

        // Try simple number first (e.g. "2", "1.5")
        if let value = Double(trimmed) {
            return value
        }

        // Handle mixed number + fraction like "1 1/2"
        let parts = trimmed.split(separator: " ")
        if parts.count == 2,
           let whole = Double(parts[0]),
           let fraction = parseFraction(String(parts[1])) {
            return whole + fraction
        }

        // Handle simple fraction like "1/2"
        if let fraction = parseFraction(trimmed) {
            return fraction
        }

        return 1.0
    }

    /// Map the unit string to the app's IngredientUnit enum.
    /// Normalizes common API responses (e.g. "whole" → .piece, "cloves" → .clove)
    /// before checking the rawValue or alias table.
    var ingredientUnit: IngredientUnit {
        let normalized = unit.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Check aliases first — this handles plural forms, long names,
        // and remapping legacy units like "whole" to better picker values.
        let aliases: [String: IngredientUnit] = [
            // Claude frequently returns these
            "whole": .piece,
            "medium": .piece,
            "large": .piece,
            "small": .piece,
            "slice": .piece, "slices": .piece,

            // Plural and long forms
            "cups": .cup,
            "tablespoon": .tablespoon, "tablespoons": .tablespoon,
            "tbs": .tablespoon,
            "teaspoon": .teaspoon, "teaspoons": .teaspoon,
            "ounce": .ounce, "ounces": .ounce,
            "pound": .pound, "pounds": .pound,
            "lbs": .pound,
            "gram": .gram, "grams": .gram,
            "kilogram": .kilogram, "kilograms": .kilogram,
            "kg": .kilogram,
            "liter": .liter, "liters": .liter,
            "l": .liter,
            "milliliter": .milliliter, "milliliters": .milliliter,
            "ml": .milliliter,
            "fluid ounce": .fluidOunce, "fluid ounces": .fluidOunce,
            "fl oz": .fluidOunce,
            "pinches": .pinch,
            "clove": .clove, "cloves": .clove,
            "can": .can, "cans": .can,
            "package": .package, "packages": .package, "pkg": .package,
            "bunch": .bunch, "bunches": .bunch,
            "sprig": .sprig, "sprigs": .sprig,
            "dash": .dash, "dashes": .dash,
            "to taste": .toTaste,
            "each": .piece, "item": .piece, "items": .piece,
            "pieces": .piece, "pcs": .piece,
        ]

        if let match = aliases[normalized] {
            return match
        }

        // Fall back to exact rawValue match (e.g. "tsp", "tbsp", "cup")
        if let match = IngredientUnit(rawValue: unit) {
            return match
        }

        return .piece
    }

    private func parseFraction(_ text: String) -> Double? {
        let parts = text.split(separator: "/")
        guard parts.count == 2,
              let numerator = Double(parts[0]),
              let denominator = Double(parts[1]),
              denominator != 0 else {
            return nil
        }
        return numerator / denominator
    }
}
