//
//  RecipeResponseParser.swift
//  Family Meal Planner
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

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw ParseError.decodingFailed("Could not convert response to data")
        }

        // Check for the "no recipe found" sentinel
        if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           jsonObject["error"] != nil {
            throw ParseError.noRecipeFound
        }

        do {
            return try JSONDecoder().decode(ExtractedRecipe.self, from: jsonData)
        } catch {
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
