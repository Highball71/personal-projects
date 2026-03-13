//
//  RecipeWebImporter.swift
//  Family Meal Planner
//
//  Imports recipe data from a URL: tries JSON-LD first (free, no API call),
//  then falls back to sending the page HTML to Claude.

import Foundation
import os

enum RecipeWebImporter {

    enum ImportError: LocalizedError {
        case urlFetchFailed(String)
        case webpageEmpty
        case noRecipeFound

        var errorDescription: String? {
            switch self {
            case .urlFetchFailed(let detail):
                "Could not load the webpage: \(detail)"
            case .webpageEmpty:
                "The webpage didn't contain any readable text."
            case .noRecipeFound:
                "Couldn't find a recipe on that page."
            }
        }
    }

    private static let systemPrompt = """
        You are a recipe extraction assistant. Return ONLY valid JSON \
        (no markdown, no code fences, no extra text).
        """

    // MARK: - Public

    /// Import a recipe from a URL.
    /// Step 1: Fetch HTML
    /// Step 2: Try JSON-LD extraction (no API call)
    /// Step 3: If JSON-LD fails, send HTML to Claude
    /// Step 4: Parse response into ExtractedRecipe
    static func importRecipe(from url: URL) async throws -> ExtractedRecipe {
        Logger.importPipeline.info("Starting URL import for \(url.absoluteString, privacy: .public)")

        // --- Step 1: Fetch HTML ---
        let htmlText = try await fetchHTML(from: url)

        // --- Step 2: Try JSON-LD (free, no API call) ---
        if let extracted = RecipeResponseParser.extractJSONLD(from: htmlText) {
            Logger.importPipeline.info("URL import succeeded (via JSON-LD)")
            return extracted
        }

        // --- Step 3: Send to Claude ---
        let maxChars = 50_000
        let trimmedHTML = htmlText.count > maxChars
            ? String(htmlText.prefix(maxChars))
            : htmlText
        Logger.importPipeline.info("Sending \(trimmedHTML.count, privacy: .public) chars to Claude API...")

        let userPrompt = """
            Extract the recipe from this webpage HTML. Return JSON with these fields: \
            name (string), category (string - one of: breakfast, lunch, dinner, \
            snack, dessert, side, drink), servingSize (string), prepTime (string), \
            cookTime (string), ingredients (array of objects with: name, amount, \
            unit), instructions (array of strings), and source (string or null \
            - the name of the website or blog this recipe is from).

            If you cannot find a clear, complete recipe in this text, respond with \
            exactly this JSON: {"error": "no_recipe_found"}. Do NOT make up or guess \
            a recipe.

            Here is the webpage HTML:

            \(trimmedHTML)
            """

        let response = try await AnthropicClient.sendTextMessage(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            timeout: 60
        )

        let text = try AnthropicClient.extractText(from: response)
        #if DEBUG
        Logger.importPipeline.debug("Claude response preview: \(String(text.prefix(500)), privacy: .public)")
        #endif

        // --- Step 4: Parse ---
        do {
            let recipe = try RecipeResponseParser.parse(response: text)
            Logger.importPipeline.info("URL import succeeded")
            return recipe
        } catch let error as RecipeResponseParser.ParseError where error == .noRecipeFound {
            throw ImportError.noRecipeFound
        }
    }

    // MARK: - Private

    private static func fetchHTML(from url: URL) async throws -> String {
        Logger.network.info("Fetching webpage...")

        var fetchRequest = URLRequest(url: url)
        fetchRequest.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: fetchRequest)
        } catch {
            Logger.network.error("Network error: \(error.localizedDescription, privacy: .public)")
            throw ImportError.urlFetchFailed(error.localizedDescription)
        }

        let httpResponse = response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? -1
        Logger.network.info("HTTP \(statusCode, privacy: .public), \(data.count, privacy: .public) bytes")

        if !(200...299).contains(statusCode) {
            throw ImportError.urlFetchFailed("HTTP \(statusCode)")
        }

        let htmlText = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .ascii)
            ?? ""

        guard !htmlText.isEmpty else {
            throw ImportError.webpageEmpty
        }

        #if DEBUG
        Logger.network.debug("HTML preview (first 500 chars): \(String(htmlText.prefix(500)), privacy: .public)")
        #endif

        Logger.network.info("Fetched \(htmlText.count, privacy: .public) chars")
        return htmlText
    }
}

// MARK: - Equatable conformance for error matching

extension RecipeResponseParser.ParseError: Equatable {
    static func == (lhs: RecipeResponseParser.ParseError, rhs: RecipeResponseParser.ParseError) -> Bool {
        switch (lhs, rhs) {
        case (.noRecipeFound, .noRecipeFound):
            return true
        case (.decodingFailed(let a), .decodingFailed(let b)):
            return a == b
        default:
            return false
        }
    }
}
