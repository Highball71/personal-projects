//
//  GroceryMerge.swift
//  FluffyList
//
//  Pure merge rules for the grocery list (2026-09-06 Costco report:
//  olive oil appeared three times in different measurements across
//  three recipes). WeekSummary-style: no service or network code, so
//  every rule is unit-testable.
//
//  Rules:
//    - Two rows are the same pantry item when their NORMALIZED names
//      match: trimmed, lowercased, whitespace collapsed, then passed
//      through a small EXPLICIT alias table ("extra-virgin olive oil"
//      → "olive oil"). No fuzzy matching — "green onion" must never
//      merge into "onion".
//    - Compatible units convert within a family and sum: US volume
//      (tsp/tbsp/fl oz/cup), US weight (oz/lb), metric weight (g/kg),
//      metric volume (mL/L). The EXISTING row's unit wins as the
//      display unit — it never changes once the row exists, so
//      grocery_contributions (recorded in the row's unit) stay
//      consistent for the unwind.
//    - Incompatible units ("1 piece" + "2 tbsp") stay ONE row: the
//      row keeps its own amount and the extra amount is appended to
//      the row's `note`, displayed as "1 piece + 2 tbsp". Never a
//      second row, never an invented amount, never a dropped one.
//

import Foundation

enum GroceryMerge {

    // MARK: - Name normalization

    /// Variants that are the same pantry item as their canonical name.
    /// Keys and values are in normalized (lowercased, collapsed) form.
    /// Deliberately tiny and explicit — extend it entry by entry when
    /// real duplicates show up, never with fuzzy matching.
    static let nameAliases: [String: String] = [
        "extra-virgin olive oil": "olive oil",
        "extra virgin olive oil": "olive oil",
        "evoo": "olive oil",
    ]

    /// Trim, lowercase, collapse internal whitespace, then apply the
    /// alias table. This is the entire merge key — unit is NOT part of
    /// it (that's what made three olive-oil rows).
    static func normalizeName(_ name: String) -> String {
        let collapsed = name
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return nameAliases[collapsed] ?? collapsed
    }

    // MARK: - Unit conversion

    /// Unit families, each measured in a base unit (tsp / oz / g / mL).
    /// Only conversions WITHIN a family are allowed.
    private static let unitFactors: [String: (family: String, factor: Double)] = [
        "tsp": ("us-volume", 1), "tbsp": ("us-volume", 3),
        "fl oz": ("us-volume", 6), "cup": ("us-volume", 48),
        "oz": ("us-weight", 1), "lb": ("us-weight", 16),
        "g": ("metric-weight", 1), "kg": ("metric-weight", 1000),
        "ml": ("metric-volume", 1), "l": ("metric-volume", 1000),
    ]

    /// Fold unit spelling variants (legacy rows hold strings like
    /// "cups" or "tablespoons") onto the canonical rawValue spellings
    /// used by unitFactors. Unknown units normalize to their trimmed
    /// lowercased selves — equal strings still merge, different ones
    /// are incompatible.
    private static let unitAliases: [String: String] = [
        "teaspoon": "tsp", "teaspoons": "tsp", "tsps": "tsp",
        "tablespoon": "tbsp", "tablespoons": "tbsp", "tbs": "tbsp",
        "cups": "cup",
        "fluid ounce": "fl oz", "fluid ounces": "fl oz", "floz": "fl oz",
        "ounce": "oz", "ounces": "oz",
        "pound": "lb", "pounds": "lb", "lbs": "lb",
        "gram": "g", "grams": "g",
        "kilogram": "kg", "kilograms": "kg",
        "milliliter": "ml", "milliliters": "ml",
        "liter": "l", "liters": "l",
    ]

    static func normalizeUnit(_ unit: String) -> String {
        let cleaned = unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return unitAliases[cleaned] ?? cleaned
    }

    /// Convert a quantity between two units of the same family.
    /// Returns nil when the units live in different families (or
    /// either is outside every family).
    static func convert(_ quantity: Double, from source: String, to target: String) -> Double? {
        guard let from = unitFactors[normalizeUnit(source)],
              let to = unitFactors[normalizeUnit(target)],
              from.family == to.family else { return nil }
        return quantity * from.factor / to.factor
    }

    // MARK: - Amount combination

    struct Amount {
        var quantity: Double
        var unit: String
    }

    /// The incoming amount expressed in the existing row's unit, or
    /// nil when the units are incompatible. Identical (normalized)
    /// units always combine, even outside the conversion families
    /// ("piece" + "piece").
    static func convertedForRow(existingUnit: String, incoming: Amount) -> Double? {
        if normalizeUnit(existingUnit) == normalizeUnit(incoming.unit) {
            return incoming.quantity
        }
        return convert(incoming.quantity, from: incoming.unit, to: existingUnit)
    }

    /// Human text for an amount that couldn't merge numerically —
    /// appended to the row's note ("2 tbsp", "to taste").
    static func amountText(_ amount: Amount) -> String {
        if normalizeUnit(amount.unit) == IngredientUnit.toTaste.rawValue {
            return "to taste"
        }
        let qty = FractionFormatter.formatAsFraction(amount.quantity)
        let unit = amount.unit.trimmingCharacters(in: .whitespacesAndNewlines)
        return unit.isEmpty || unit == IngredientUnit.none.rawValue ? qty : "\(qty) \(unit)"
    }

    /// Append an amount's text to an existing note (" + "-joined list).
    static func appendedNote(_ existing: String?, adding text: String) -> String {
        guard let existing, !existing.isEmpty else { return text }
        return "\(existing) + \(text)"
    }

    // MARK: - Batch merge

    /// Merge a batch of inserts by normalized NAME. The first item of
    /// each name group is primary: its printed name and unit win.
    /// Later amounts convert into the primary unit and sum; amounts
    /// with incompatible units land in the insert's note.
    static func mergeInserts(_ inserts: [GroceryItemInsert]) -> [GroceryItemInsert] {
        var mergedByKey: [String: GroceryItemInsert] = [:]
        var orderedKeys: [String] = []

        for item in inserts {
            let key = normalizeName(item.name)
            guard let existing = mergedByKey[key] else {
                mergedByKey[key] = item
                orderedKeys.append(key)
                continue
            }

            let incoming = Amount(quantity: item.quantity, unit: item.unit)
            var combinedQuantity = existing.quantity
            var combinedNote = existing.note
            if let converted = convertedForRow(existingUnit: existing.unit, incoming: incoming) {
                combinedQuantity += converted
            } else {
                combinedNote = appendedNote(combinedNote, adding: amountText(incoming))
            }
            // An incoming note (rare — only merge-generated so far)
            // must never be dropped.
            if let note = item.note, !note.isEmpty {
                combinedNote = appendedNote(combinedNote, adding: note)
            }
            mergedByKey[key] = GroceryItemInsert(
                householdID: existing.householdID,
                name: existing.name,
                quantity: combinedQuantity,
                unit: existing.unit,
                note: combinedNote
            )
        }

        return orderedKeys.compactMap { mergedByKey[$0] }
    }
}
