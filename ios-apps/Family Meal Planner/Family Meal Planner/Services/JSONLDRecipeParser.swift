//
//  JSONLDRecipeParser.swift
//  Family Meal Planner
//
//  Extracts recipe data from JSON-LD structured data (Schema.org Recipe type)
//  embedded in webpage HTML. This avoids a Claude API call for the majority
//  of food blogs that include structured data for SEO.

import Foundation

/// Parses `<script type="application/ld+json">` blocks in HTML to find
/// a Schema.org Recipe object, then converts it to an ExtractedRecipe.
enum JSONLDRecipeParser {

    // MARK: - Public

    /// Try to extract a recipe from JSON-LD structured data in the HTML.
    /// Returns nil if no Recipe schema is found — caller should fall back
    /// to Claude API.
    static func extractRecipe(from html: String) -> ExtractedRecipe? {
        print("[URLImport] JSON-LD: Searching for structured recipe data...")

        let jsonBlocks = findJSONLDBlocks(in: html)
        print("[URLImport] JSON-LD: Found \(jsonBlocks.count) ld+json script block(s)")

        for block in jsonBlocks {
            // Some CMSes HTML-encode "&" as "&amp;" inside script tags.
            // Decode it before JSON parsing so strings like "Mac &amp; Cheese"
            // become "Mac & Cheese" in the parsed JSON values.
            // (We only decode &amp; here — decoding &quot; would break JSON.)
            let cleanedBlock = block.replacingOccurrences(of: "&amp;", with: "&")
            guard let data = cleanedBlock.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else {
                continue
            }

            if let recipe = findRecipeObject(in: json) {
                print("[URLImport] JSON-LD: Found Recipe object")
                if let extracted = convertToExtractedRecipe(recipe) {
                    print("[URLImport] JSON-LD: Successfully parsed \"\(extracted.name)\"")
                    return extracted
                }
            }
        }

        print("[URLImport] JSON-LD: No Recipe schema found, will fall back to Claude API")
        return nil
    }

    // MARK: - HTML Parsing

    /// Find all `<script type="application/ld+json">...</script>` blocks in HTML
    /// and return their text content.
    private static func findJSONLDBlocks(in html: String) -> [String] {
        // Match <script type="application/ld+json"> with flexible whitespace/quoting
        let pattern = #"<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }

        let nsRange = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: nsRange).compactMap { match in
            guard let contentRange = Range(match.range(at: 1), in: html) else { return nil }
            let content = String(html[contentRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return content.isEmpty ? nil : content
        }
    }

    // MARK: - JSON-LD Traversal

    /// Search a parsed JSON value for a Recipe object.
    /// Handles top-level objects, arrays, and @graph arrays.
    private static func findRecipeObject(in json: Any) -> [String: Any]? {
        if let dict = json as? [String: Any] {
            // Direct Recipe object
            if isRecipeType(dict) {
                return dict
            }
            // @graph array (common in food blogs)
            if let graph = dict["@graph"] as? [[String: Any]] {
                return graph.first { isRecipeType($0) }
            }
        }

        // Top-level array of objects
        if let array = json as? [[String: Any]] {
            return array.first { isRecipeType($0) }
        }

        return nil
    }

    /// Check if a JSON-LD object has @type "Recipe" (string or array of strings).
    private static func isRecipeType(_ dict: [String: Any]) -> Bool {
        if let type = dict["@type"] as? String {
            return type == "Recipe"
        }
        if let types = dict["@type"] as? [String] {
            return types.contains("Recipe")
        }
        return false
    }

    // MARK: - Conversion to ExtractedRecipe

    private static func convertToExtractedRecipe(_ json: [String: Any]) -> ExtractedRecipe? {
        guard let rawName = json["name"] as? String, !rawName.isEmpty else {
            print("[URLImport] JSON-LD: Recipe object missing 'name' field")
            return nil
        }

        let name = decodeHTMLEntities(rawName)
        print("[JSONLDParser] Raw name from JSON: \"\(rawName)\"")
        print("[JSONLDParser] Decoded name:       \"\(name)\"")
        if rawName != name {
            print("[JSONLDParser] HTML entities were decoded in recipe name")
        }
        let category = extractCategory(from: json)
        let servingSize = extractString(from: json["recipeYield"])
        let prepTime = parseISO8601Duration(extractString(from: json["prepTime"]))
        let cookTime = parseISO8601Duration(extractString(from: json["cookTime"]))
        let ingredients = extractIngredients(from: json)
        let instructions = extractInstructions(from: json)
        let source = extractSourceDescription(from: json)

        // A recipe should have at least ingredients or instructions to be useful
        guard !ingredients.isEmpty || !instructions.isEmpty else {
            print("[URLImport] JSON-LD: Recipe has no ingredients or instructions, skipping")
            return nil
        }

        return ExtractedRecipe(
            name: name,
            category: category,
            servingSize: servingSize,
            prepTime: prepTime,
            cookTime: cookTime,
            ingredients: ingredients,
            instructions: instructions,
            source: source
        )
    }

    // MARK: - Field Extraction

    /// Extract category — can be a string, array of strings, or missing.
    private static func extractCategory(from json: [String: Any]) -> String {
        if let cat = json["recipeCategory"] as? String {
            return cat
        }
        if let cats = json["recipeCategory"] as? [String], let first = cats.first {
            return first
        }
        return "dinner"
    }

    /// Safely extract a string from a value that might be a string, number, or array.
    private static func extractString(from value: Any?) -> String? {
        if let str = value as? String {
            return str
        }
        if let arr = value as? [String], let first = arr.first {
            return first
        }
        if let num = value as? Int {
            return "\(num)"
        }
        return nil
    }

    /// Extract source description from publisher or author info.
    private static func extractSourceDescription(from json: [String: Any]) -> String? {
        // Try publisher first (usually the blog/site name)
        if let publisher = json["publisher"] as? [String: Any],
           let name = publisher["name"] as? String {
            return name
        }
        // Fall back to author
        if let author = json["author"] as? [String: Any],
           let name = author["name"] as? String {
            return name
        }
        if let author = json["author"] as? String {
            return author
        }
        return nil
    }

    // MARK: - Ingredients

    /// Parse recipeIngredient — an array of strings like "1 cup flour".
    private static func extractIngredients(from json: [String: Any]) -> [ExtractedIngredient] {
        guard let items = json["recipeIngredient"] as? [String] else { return [] }
        return items.map { parseIngredientString($0) }
    }

    /// Parse a single ingredient string like "1 1/2 cups all-purpose flour"
    /// into its component parts (amount, unit, name).
    private static func parseIngredientString(_ text: String) -> ExtractedIngredient {
        // Clean up HTML entities and price annotations before parsing
        let trimmed = stripPriceInfo(decodeHTMLEntities(text))
            .trimmingCharacters(in: .whitespaces)

        // Scan the leading amount: a number, optional fraction (like "1 1/2" or "1/2"),
        // or decimal (like "1.5"). Uses simple character scanning to avoid NSRegularExpression.
        var index = trimmed.startIndex

        // Skip leading digits
        while index < trimmed.endIndex && (trimmed[index].isNumber || trimmed[index] == ".") {
            index = trimmed.index(after: index)
        }

        // Check for fraction part: " 1/2" or "/2"
        var fractionEnd = index
        if fractionEnd < trimmed.endIndex && trimmed[fractionEnd] == " " {
            let afterSpace = trimmed.index(after: fractionEnd)
            if afterSpace < trimmed.endIndex && trimmed[afterSpace].isNumber {
                // Could be "1 1/2" — look for digits/digits
                var scan = afterSpace
                while scan < trimmed.endIndex && trimmed[scan].isNumber { scan = trimmed.index(after: scan) }
                if scan < trimmed.endIndex && trimmed[scan] == "/" {
                    scan = trimmed.index(after: scan)
                    while scan < trimmed.endIndex && trimmed[scan].isNumber { scan = trimmed.index(after: scan) }
                    fractionEnd = scan
                }
            }
        } else if fractionEnd < trimmed.endIndex && trimmed[fractionEnd] == "/" {
            // Simple fraction like "1/2"
            fractionEnd = trimmed.index(after: fractionEnd)
            while fractionEnd < trimmed.endIndex && trimmed[fractionEnd].isNumber {
                fractionEnd = trimmed.index(after: fractionEnd)
            }
        }

        // If we consumed something beyond the initial digits, use the extended range
        if fractionEnd > index { index = fractionEnd }

        guard index > trimmed.startIndex else {
            // No leading number — treat the whole thing as the name
            return ExtractedIngredient(name: trimmed, amount: "1", unit: "piece")
        }

        let amount = String(trimmed[trimmed.startIndex..<index])
            .trimmingCharacters(in: .whitespaces)
        let rest = String(trimmed[index...]).trimmingCharacters(in: .whitespaces)

        // Try to match a known unit at the start of `rest`
        let knownUnits = [
            "tablespoons", "tablespoon", "tbsp", "tbs",
            "teaspoons", "teaspoon", "tsp",
            "cups", "cup",
            "fluid ounces", "fluid ounce", "fl oz",
            "ounces", "ounce", "oz",
            "pounds", "pound", "lbs", "lb",
            "grams", "gram", "g",
            "kilograms", "kilogram", "kg",
            "liters", "liter", "l",
            "milliliters", "milliliter", "ml",
            "pinches", "pinch",
            "quarts", "quart", "qt",
            "pints", "pint", "pt",
            "gallons", "gallon", "gal",
            "cloves", "clove",
            "slices", "slice",
            "cans", "can",
            "packages", "package", "pkg",
            "bunches", "bunch",
            "sprigs", "sprig",
            "pieces", "piece",
            "whole",
            "dash", "dashes",
        ]

        let restLower = rest.lowercased()
        for unit in knownUnits {
            if restLower.hasPrefix(unit) {
                let afterUnit = rest.dropFirst(unit.count)
                    .trimmingCharacters(in: .whitespaces)
                // Make sure we're at a word boundary (not matching "cupboard")
                let charAfter = restLower.dropFirst(unit.count).first
                if charAfter == nil || charAfter == " " || charAfter == "." {
                    let ingredientName = afterUnit.isEmpty ? "unknown" : afterUnit
                    return ExtractedIngredient(name: ingredientName, amount: amount, unit: unit)
                }
            }
        }

        // No recognized unit — treat the rest as the name
        return ExtractedIngredient(name: rest.isEmpty ? "unknown" : rest, amount: amount, unit: "piece")
    }

    // MARK: - Instructions

    /// Parse recipeInstructions — can be an array of strings, an array of
    /// HowToStep objects, or a single string.
    private static func extractInstructions(from json: [String: Any]) -> [String] {
        // Array of strings
        if let steps = json["recipeInstructions"] as? [String] {
            return steps.map { decodeHTMLEntities($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        // Array of HowToStep/HowToSection objects
        if let steps = json["recipeInstructions"] as? [[String: Any]] {
            return steps.flatMap { extractStepText(from: $0) }
        }

        // Single string (split on newlines)
        if let text = json["recipeInstructions"] as? String {
            return decodeHTMLEntities(text).components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return []
    }

    /// Extract text from a HowToStep or HowToSection JSON object.
    private static func extractStepText(from step: [String: Any]) -> [String] {
        // HowToStep — has a "text" field
        if let text = step["text"] as? String {
            return [decodeHTMLEntities(text).trimmingCharacters(in: .whitespacesAndNewlines)]
        }

        // HowToSection — has "itemListElement" with nested steps
        if let items = step["itemListElement"] as? [[String: Any]] {
            return items.flatMap { extractStepText(from: $0) }
        }

        return []
    }

    // MARK: - Text Cleanup

    /// Decode common HTML entities: &amp; &lt; &gt; &quot; &#39; and numeric &#NNN; / &#xHH;
    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        // Named entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&#x27;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        // Decimal numeric entities like &#8217; (right single quote)
        while let range = result.range(of: #"&#(\d+);"#, options: .regularExpression) {
            let entity = String(result[range])
            let digits = entity.dropFirst(2).dropLast(1) // strip &# and ;
            if let code = Int(digits), let scalar = Unicode.Scalar(code) {
                result.replaceSubrange(range, with: String(scalar))
            } else {
                break
            }
        }
        // Hex numeric entities like &#x2019;
        while let range = result.range(of: #"&#[xX]([0-9a-fA-F]+);"#, options: .regularExpression) {
            let entity = String(result[range])
            let hex = entity.dropFirst(3).dropLast(1) // strip &#x and ;
            if let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) {
                result.replaceSubrange(range, with: String(scalar))
            } else {
                break
            }
        }
        return result
    }

    /// Strip parenthetical price info like "($0.20)" or "(about $1.50)" from ingredient strings.
    private static func stripPriceInfo(_ text: String) -> String {
        // Remove any (...$...) pattern — parenthetical text containing a dollar sign
        var result = text
        while let openParen = result.range(of: "("),
              let closeParen = result[openParen.lowerBound...].range(of: ")") {
            let parenContent = result[openParen.lowerBound...closeParen.lowerBound]
            if parenContent.contains("$") {
                // Remove the parenthetical and any trailing whitespace
                let removeRange = openParen.lowerBound..<closeParen.upperBound
                result.removeSubrange(removeRange)
                result = result.trimmingCharacters(in: .whitespaces)
            } else {
                // Not a price — stop searching to avoid infinite loop
                break
            }
        }
        return result
    }

    // MARK: - ISO 8601 Duration

    /// Convert an ISO 8601 duration like "PT1H30M" to a readable string
    /// like "1 hour 30 minutes". Returns nil for unparseable values.
    private static func parseISO8601Duration(_ value: String?) -> String? {
        guard let value = value, value.hasPrefix("P") else { return value }

        // Match hours and minutes from patterns like PT1H30M, PT30M, PT1H, P0DT0H30M
        let pattern = #"(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else {
            return nil
        }

        var parts: [String] = []

        if let hoursRange = Range(match.range(at: 1), in: value),
           let hours = Int(value[hoursRange]), hours > 0 {
            parts.append(hours == 1 ? "1 hour" : "\(hours) hours")
        }

        if let minutesRange = Range(match.range(at: 2), in: value),
           let minutes = Int(value[minutesRange]), minutes > 0 {
            parts.append(minutes == 1 ? "1 minute" : "\(minutes) minutes")
        }

        if let secondsRange = Range(match.range(at: 3), in: value),
           let seconds = Int(value[secondsRange]), seconds > 0, parts.isEmpty {
            // Only include seconds if there are no hours/minutes
            parts.append("\(seconds) seconds")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
