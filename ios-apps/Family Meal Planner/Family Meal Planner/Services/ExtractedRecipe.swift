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

    /// The servings range when the page prints one ("8 to 10", "4-6",
    /// "Serves 8 to 10"): (upper bound, printed text). Nil for a single
    /// number or no servings at all. Uses the same range parser as
    /// ingredient amounts, after skipping any leading label word.
    var servingsRangeInfo: (upperBound: Int, printed: String)? {
        guard let text = servingSize?.trimmingCharacters(in: .whitespacesAndNewlines),
              let firstDigit = text.firstIndex(where: { $0.isNumber }) else { return nil }
        guard case .range(_, let upper) = ExtractedIngredient.parseQuantity(from: String(text[firstDigit...])),
              upper >= 1 else { return nil }
        return (Int(upper.rounded()), text)
    }

    /// Parse servingSize string (e.g. "4", "4 servings", "4-6") into an Int.
    /// A printed range ("8 to 10") yields its UPPER bound — plan for the
    /// bigger table; the printed text is preserved via servingsRangeInfo.
    /// Otherwise extracts the first number found; defaults to 4.
    var servingsInt: Int {
        if let range = servingsRangeInfo { return range.upperBound }
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
    ///
    /// Quantities are handled by shape (see ParsedQuantity):
    ///   - exact: the number, formatted as a cooking fraction.
    ///   - range ("1 1/4 to 1 1/2 pounds"): the DB row persists a
    ///     single Double + unit, so the numeric quantity is the UPPER
    ///     bound (grocery aggregation never under-buys); the printed
    ///     range goes to `note` ("1 1/4 to 1 1/2 lb") and the form's
    ///     quantity text.
    ///   - unspecified (no printed amount, e.g. a garnish): unit
    ///     becomes .toTaste, which the form and grocery list render as
    ///     "to taste" with no number. Never an invented "1 piece".
    ///     If the page DID print something unparseable ("to taste",
    ///     "for garnish"), that text is preserved in `note`.
    ///
    /// A parenthetical package size in the unit ("bag (14 ounces)")
    /// keeps the container word as the unit with the size in `note`.
    ///
    /// The NAME stays clean — no quantity text is ever folded into it,
    /// so the grocery merge (keyed on normalized name) can match a
    /// scanned "olive oil" with a hand-entered one. `note` persists to
    /// recipe_ingredients.note (migration 015).
    var ingredientFormRows: [IngredientFormData] {
        ingredients.map { formRow(for: $0) }
    }

    private func formRow(for extracted: ExtractedIngredient) -> IngredientFormData {
        let resolved = extracted.resolvedQuantity
        let name = cleanIngredientName(extracted)

        switch resolved.quantity {
        case .exact(let value):
            return IngredientFormData(
                name: name,
                quantity: value,
                unit: resolved.unit,
                quantityText: FractionFormatter.formatAsFraction(value),
                note: composedNote(for: extracted, quantityText: resolved.packageSize)
            )

        case .range(_, let upper):
            let printed = extracted.printedQuantityText.trimmingCharacters(in: .whitespaces)
            // Countish units (piece / none) read better without a unit
            // word after the range: "1-2" not "1-2 piece".
            let rangeText = (resolved.unit == .piece || resolved.unit == IngredientUnit.none)
                ? printed
                : "\(printed) \(resolved.unit.displayName)"
            return IngredientFormData(
                name: name,
                quantity: upper,
                unit: resolved.unit,
                quantityText: printed,
                note: composedNote(for: extracted, quantityText: joinedFragments(rangeText, resolved.packageSize))
            )

        case .unspecified:
            // Preserve whatever the page printed ("to taste",
            // "for garnish") — an empty amount leaves no note.
            let printed = extracted.printedQuantityText.trimmingCharacters(in: .whitespacesAndNewlines)
            return IngredientFormData(
                name: name,
                quantity: 1,
                unit: .toTaste,
                quantityText: "",
                note: composedNote(
                    for: extracted,
                    quantityText: joinedFragments(printed.isEmpty ? nil : printed, resolved.packageSize)
                )
            )
        }
    }

    /// The ingredient name with NOTHING folded in — no section, no
    /// preparation, no quantity text — so the grocery merge's
    /// normalized-name key sees the same pantry item whether it came
    /// from a scan, another section, or a hand-entered row. The one
    /// exception: an empty extracted name promotes the preparation
    /// text so the row doesn't render blank (Claude occasionally does
    /// this with loosely structured recipes).
    private func cleanIngredientName(_ ingredient: ExtractedIngredient) -> String {
        let baseName = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if baseName.isEmpty,
           let prep = ingredient.preparation?.trimmingCharacters(in: .whitespacesAndNewlines),
           !prep.isEmpty {
            return prep
        }
        return baseName
    }

    /// The form row's note: quantity-derived text (printed range,
    /// package size, unparseable printed amount) plus the preparation
    /// note, "; "-joined, all behind a "Section: " prefix when the
    /// ingredient sat under a section header. Section and preparation
    /// used to be folded into the NAME, which split identical pantry
    /// items into separate grocery rows.
    private func composedNote(for ingredient: ExtractedIngredient, quantityText: String?) -> String? {
        var prep = ingredient.preparation?.trimmingCharacters(in: .whitespacesAndNewlines)
        // Skip preparation the model duplicated into the empty-name
        // fallback — it would read twice.
        if ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prep = nil
        }
        let body = joinedFragments(quantityText, prep)

        guard let section = ingredient.section?.trimmingCharacters(in: .whitespacesAndNewlines),
              !section.isEmpty else {
            return body
        }
        guard let body else { return section }
        return "\(section): \(body)"
    }

    /// Join up to two note fragments ("1-2 lb" + "14 ounces") with a
    /// separator; nil when both are absent.
    private func joinedFragments(_ first: String?, _ second: String?) -> String? {
        let parts = [first, second].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "; ")
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

/// A quantity as printed on a recipe page. Pages print exact amounts
/// ("2", "1 1/2"), ranges ("1 1/4 to 1 1/2", "1-2", "1¼–1½"), or no
/// amount at all (garnishes, "to taste" items). Collapsing all three
/// into one Double silently invented "1" for ranges and garnishes, so
/// the parser keeps the shape and lets the form conversion decide.
enum ParsedQuantity: Equatable {
    case exact(Double)
    case range(Double, Double)
    case unspecified
}

/// A single ingredient as extracted by Claude.
struct ExtractedIngredient: Codable {
    let name: String
    // amount and unit are optional `var`s: the prompt asks for empty
    // strings when the page prints no quantity, but the model returns
    // JSON null often enough (round-2 P12 sesame oil, P13 parsley)
    // that a required String aborted otherwise complete recipes. Null,
    // missing, and "" all mean the same thing: unspecified.
    var amount: String? = nil
    var unit: String? = nil
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
    /// The quantity text exactly as printed on the page,
    /// character-for-character ("1¼–1½", "3/4"). Requested from the
    /// model since the 2026-09-06 accuracy prompt tightening; optional
    /// so every earlier response and fixture decodes unchanged.
    var printedAmount: String? = nil

    /// The quantity text to trust: the verbatim transcription when the
    /// model provided one, else the amount field. Empty when the page
    /// printed no quantity (or the model returned null).
    var printedQuantityText: String {
        if let printedAmount, !printedAmount.isEmpty { return printedAmount }
        return amount ?? ""
    }

    /// Parse the printed amount into its shape — exact, range, or
    /// unspecified. Handles integers ("2"), decimals ("1.5"), fractions
    /// ("1/2", "1 1/2"), unicode fractions ("1¼"), and ranges joined by
    /// "to", "-", "–", or "—". An empty, null, or unparseable amount is
    /// .unspecified — never a made-up number. Prefers the verbatim
    /// printedAmount over amount when both are present.
    var parsedQuantity: ParsedQuantity {
        resolvedQuantity.quantity
    }

    /// The consolidated quantity picture: shape, display unit, and any
    /// package size, resolved across amount/unit/printedAmount.
    ///
    /// The subtlety is container expressions. The model returns them in
    /// either place:
    ///   - unit: "package (14.4 ounces)", amount "1"  (round-2 P13)
    ///   - printedAmount: "1 bag (14 ounces)", with amount/unit
    ///     holding the CONTENTS ("14" / "ounces")  (round-2 P11)
    /// Since printedAmount wins as the parsing string, the container
    /// parser must run on it too — otherwise "1 bag (14 ounces)" reads
    /// as unparseable and a fully specified package silently became a
    /// "to taste" row.
    var resolvedQuantity: (quantity: ParsedQuantity, unit: IngredientUnit, packageSize: String?) {
        let (unitFromUnit, sizeFromUnit) = unitAndPackageSize
        let parseText = printedQuantityText

        if let container = Self.parseContainerExpression(from: parseText) {
            return (.exact(container.count), container.unit, container.size ?? sizeFromUnit)
        }

        // A nonempty printed string that doesn't parse must not
        // silently unspecify a quantity the structured amount field
        // still carries (round-2 finding: the printed text is
        // evidence, not the only source of truth).
        let printedParse = Self.parseQuantity(from: parseText)
        if printedParse == .unspecified, let amount, !amount.isEmpty {
            let fallback = Self.parseQuantity(from: amount)
            if fallback != .unspecified {
                return (fallback, unitFromUnit, sizeFromUnit)
            }
        }
        return (printedParse, unitFromUnit, sizeFromUnit)
    }

    /// Parse a container expression like "1 bag (14 ounces)",
    /// "2 cans (14.5 ounces)", or "1 package" into count + container
    /// unit + optional size. Only container words (bag/can/package)
    /// qualify — "1 1/2 pounds" must never match. Nil otherwise.
    static func parseContainerExpression(from text: String) -> (count: Double, unit: IngredientUnit, size: String?)? {
        var working = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !working.isEmpty else { return nil }

        // Split off a trailing parenthetical size.
        var size: String? = nil
        if let openParen = working.firstIndex(of: "("),
           let closeParen = working.lastIndex(of: ")"),
           openParen < closeParen {
            let inside = String(working[working.index(after: openParen)..<closeParen])
                .trimmingCharacters(in: .whitespaces)
            size = inside.isEmpty ? nil : inside
            working = String(working[..<openParen]).trimmingCharacters(in: .whitespaces)
        }

        // What's left must be "<count> <container-word>" (count optional
        // → 1). Find the first letter; everything before it is the count.
        guard let firstLetter = working.firstIndex(where: { $0.isLetter }) else { return nil }
        let countText = String(working[..<firstLetter]).trimmingCharacters(in: .whitespaces)
        let word = String(working[firstLetter...]).trimmingCharacters(in: .whitespaces)

        let containerUnits: Set<IngredientUnit> = [.bag, .can, .package]
        let unit = ingredientUnit(fromWord: word)
        guard containerUnits.contains(unit) else { return nil }

        if countText.isEmpty { return (1, unit, size) }
        guard let count = FractionFormatter.parseFraction(normalizeVulgarFractions(in: countText)) else {
            return nil
        }
        return (count, unit, size)
    }

    static func parseQuantity(from text: String) -> ParsedQuantity {
        let normalized = normalizeVulgarFractions(in: text)
            .trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return .unspecified }

        // A single quantity first — this must win before range
        // splitting so the space in "1 1/2" is never misread.
        if let value = FractionFormatter.parseFraction(normalized) {
            return .exact(value)
        }

        // Range: two parseable quantities around a separator.
        // Lowercased so "1 To 2" still matches " to ".
        let lowered = normalized.lowercased()
        for separator in [" to ", "–", "—", "-"] {
            let parts = lowered.components(separatedBy: separator)
            if parts.count == 2,
               let low = FractionFormatter.parseFraction(parts[0].trimmingCharacters(in: .whitespaces)),
               let high = FractionFormatter.parseFraction(parts[1].trimmingCharacters(in: .whitespaces)),
               low <= high {
                return .range(low, high)
            }
        }

        return .unspecified
    }

    /// Rewrite unicode vulgar fractions as ASCII ("1¼" → "1 1/4") so
    /// the ordinary fraction parser can read them.
    private static func normalizeVulgarFractions(in text: String) -> String {
        let map: [Character: String] = [
            "¼": "1/4", "½": "1/2", "¾": "3/4",
            "⅓": "1/3", "⅔": "2/3",
            "⅛": "1/8", "⅜": "3/8", "⅝": "5/8", "⅞": "7/8",
            "⅕": "1/5", "⅖": "2/5", "⅗": "3/5", "⅘": "4/5",
            "⅙": "1/6", "⅚": "5/6",
        ]
        var result = ""
        for character in text {
            if let ascii = map[character] {
                // "1¼" needs the mixed-number space: "1 1/4".
                if let last = result.last, last.isNumber {
                    result.append(" ")
                }
                result.append(ascii)
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// The unit split into the unit word and any parenthetical package
    /// size: "bag (14 ounces)" → (.bag, "14 ounces"). A unit without a
    /// parenthetical returns (unit, nil).
    var unitAndPackageSize: (unit: IngredientUnit, packageSize: String?) {
        let unitText = unit ?? ""
        guard let openParen = unitText.firstIndex(of: "("),
              let closeParen = unitText.lastIndex(of: ")"),
              openParen < closeParen else {
            return (Self.ingredientUnit(fromWord: unitText), nil)
        }
        let word = String(unitText[..<openParen])
        let size = String(unitText[unitText.index(after: openParen)..<closeParen])
            .trimmingCharacters(in: .whitespaces)
        return (Self.ingredientUnit(fromWord: word), size.isEmpty ? nil : size)
    }

    /// Map the unit string to the app's IngredientUnit enum.
    /// Normalizes common API responses (e.g. "whole" → .piece, "cloves" → .clove)
    /// before checking the rawValue or alias table. Any parenthetical
    /// package size is stripped first — see `unitAndPackageSize`.
    var ingredientUnit: IngredientUnit {
        unitAndPackageSize.unit
    }

    private static func ingredientUnit(fromWord unit: String) -> IngredientUnit {
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
            "bag": .bag, "bags": .bag,
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
}
