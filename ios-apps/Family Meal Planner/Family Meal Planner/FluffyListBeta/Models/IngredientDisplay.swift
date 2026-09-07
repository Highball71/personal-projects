//
//  IngredientDisplay.swift
//  FluffyList
//
//  The ONE place ingredient/grocery row wording lives (round-3 review
//  polish). Recipe-detail rows and grocery rows both render through
//  `render`, which turns a stored (quantity, unit, note) triple into:
//
//    - a quantity label: "1 can (14.5 oz)" for containers with a size
//      note; "8 slices" / "1 medium" when the note carries a size
//      descriptor rescued from a piece unit; "to taste"; "1 1/2 lb".
//    - detail text: the remaining note fragments — section context,
//      preparation, printed ranges — joined with " · " ("Marinade ·
//      thinly sliced"), never with the old " + " that read like an
//      extra quantity.
//
//  Display only: stored notes and quantity/unit values are never
//  changed here. A fragment that would just repeat the quantity
//  already on the row (note "14.5 ounces" on a 14.5 oz row) is
//  suppressed from that row's rendering; the stored note keeps it.
//

import Foundation

enum IngredientDisplay {

    struct Rendering: Equatable {
        let quantityLabel: String
        let detailText: String?

        /// Single-line form for views with one text slot:
        /// "1 can (14.5 oz)" or "1 1/2 lb · 1¼ to 1½ lb".
        var combined: String {
            guard let detailText else { return quantityLabel }
            return "\(quantityLabel) · \(detailText)"
        }
    }

    private static let containerUnits: Set<IngredientUnit> = [.bag, .can, .package]

    static func render(
        quantity: Double,
        unit unitText: String,
        note: String?,
        scale: Double = 1
    ) -> Rendering {
        let unit = IngredientUnit(rawValue: unitText)
        var fragments = noteFragments(from: note)
        let qty = FractionFormatter.formatAsFraction(quantity * scale)

        var label: String
        var consumed: Int? = nil

        if unit == .toTaste {
            label = "to taste"
        } else if let unit, containerUnits.contains(unit),
                  let index = fragments.firstIndex(where: { parsedSize($0) != nil }),
                  let size = parsedSize(fragments[index]) {
            // "1 can (14.5 oz)": count, container word, size in
            // parentheses with the app's unit abbreviation.
            label = "\(qty) \(unit.displayName) (\(size.display))"
            consumed = index
        } else if unit == .piece,
                  let index = fragments.firstIndex(where: {
                      ExtractedIngredient.sizeDescriptorWords.contains($0.lowercased())
                  }) {
            // "8 slices", "1 medium" — the rescued unit word replaces
            // the generic "piece".
            label = "\(qty) \(fragments[index])"
            consumed = index
        } else if unitText.trimmingCharacters(in: .whitespaces).isEmpty || unit == IngredientUnit.none {
            label = qty
        } else {
            label = "\(qty) \(unit?.displayName ?? unitText)"
        }
        if let consumed { fragments.remove(at: consumed) }

        // Suppress fragments that only repeat the quantity already on
        // the row (display-only — the stored note is untouched).
        let rowUnitCanonical = GroceryMerge.normalizeUnit(unitText)
        fragments.removeAll { fragment in
            if fragment == label { return true }
            if let size = parsedSize(fragment) {
                return size.canonicalUnit == rowUnitCanonical
                    && abs(size.value - quantity * scale) < 0.0001
            }
            return false
        }

        return Rendering(
            quantityLabel: label,
            detailText: fragments.isEmpty ? nil : fragments.joined(separator: " · ")
        )
    }

    // MARK: - Note decomposition

    /// Break a stored note into fragments: an optional leading
    /// "Section: " prefix (no digits — "For the Chicken: 1¼…" splits,
    /// "1 1/4 to 1 1/2 lb" doesn't) followed by "; "-joined parts.
    private static func noteFragments(from note: String?) -> [String] {
        guard let note = note?.trimmingCharacters(in: .whitespacesAndNewlines),
              !note.isEmpty else { return [] }

        var fragments: [String] = []
        var body = note
        if let colon = note.range(of: ": "),
           !note[..<colon.lowerBound].contains(where: { $0.isNumber }) {
            fragments.append(String(note[..<colon.lowerBound]))
            body = String(note[colon.upperBound...])
        }
        fragments.append(contentsOf: body
            .components(separatedBy: "; ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
        return fragments
    }

    /// "14.5 ounces" → (14.5, "oz", "14.5 oz"): exactly one number
    /// followed by a known measurement word. The display keeps the
    /// number as printed (14.5 stays decimal, never "14 1/2").
    /// Anything else — "about 1 pound total", ranges, words — is nil
    /// and stays as printed.
    private static func parsedSize(_ fragment: String) -> (value: Double, canonicalUnit: String, display: String)? {
        let tokens = fragment.split(separator: " ")
        guard tokens.count >= 2 else { return nil }
        let numberText = String(tokens[0])
        guard let value = Double(numberText) ?? FractionFormatter.parseFraction(numberText)
        else { return nil }

        let word = tokens.dropFirst().joined(separator: " ")
        let canonical = GroceryMerge.normalizeUnit(word)
        let known: Set<String> = ["tsp", "tbsp", "cup", "fl oz", "oz", "lb", "g", "kg", "ml", "l"]
        guard known.contains(canonical) else { return nil }

        let displayUnit = ["ml": "mL", "l": "L"][canonical] ?? canonical
        return (value, canonical, "\(tokens[0]) \(displayUnit)")
    }
}
