//
//  RecipeResponseParser.swift
//  FluffyList
//
//  Shared parsing logic for Claude API responses that contain recipe JSON.
//  Used by both RecipeImageExtractor and RecipeWebImporter.

import Foundation

enum RecipeResponseParser {

    enum ParseError: LocalizedError {
        case noRecipeFound
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .noRecipeFound:
                "Couldn't find a recipe on that page."
            case .decodingFailed(let detail):
                "Could not read the recipe from the response: \(detail)"
            }
        }
    }

    /// Parse an ExtractedRecipe from a Claude API response text string.
    /// Handles markdown code fences and the "no_recipe_found" sentinel.
    static func parse(response: String) throws -> ExtractedRecipe {
        let cleaned = stripCodeFences(from: response)
        print("[DEBUG RecipeResponseParser] Cleaned response (\(cleaned.count) chars):\n\(String(cleaned.prefix(500)))")

        guard let jsonData = cleaned.data(using: .utf8) else {
            print("[DEBUG RecipeResponseParser] Could not convert cleaned response to Data")
            throw ParseError.decodingFailed("Could not convert response to data")
        }

        // Check for the "no recipe found" sentinel
        if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           jsonObject["error"] != nil {
            print("[DEBUG RecipeResponseParser] Claude returned 'no recipe found' sentinel")
            throw ParseError.noRecipeFound
        }

        do {
            let recipe = try JSONDecoder().decode(ExtractedRecipe.self, from: jsonData)
            print("[DEBUG RecipeResponseParser] Successfully decoded: \"\(recipe.name)\"")
            return recipe
        } catch {
            print("[DEBUG RecipeResponseParser] DECODING FAILED: \(error)")
            throw ParseError.decodingFailed(error.localizedDescription)
        }
    }

    /// Try to extract a recipe from JSON-LD structured data in HTML.
    /// Returns nil if no Recipe schema is found — caller should fall back to Claude API.
    static func extractJSONLD(from html: String) -> ExtractedRecipe? {
        JSONLDRecipeParser.extractRecipe(from: html)
    }

    /// Remove markdown code fences (```json ... ```) if present.
    static func stripCodeFences(from text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```") {
            if let firstNewline = result.firstIndex(of: "\n") {
                result = String(result[result.index(after: firstNewline)...])
            }
        }
        if result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
