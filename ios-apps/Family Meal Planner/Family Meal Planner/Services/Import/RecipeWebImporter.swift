//
//  RecipeWebImporter.swift
//  FluffyList
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
        // Strip script/style/nav noise and HTML tags before sending so
        // we spend tokens on actual recipe content instead of markup.
        // The 50_000 char cap stays as a safety net; cleaned text from
        // a typical recipe page lands well under it.
        let cleaned = cleanForExtraction(htmlText)
        let maxChars = 50_000
        let trimmedText = cleaned.count > maxChars
            ? String(cleaned.prefix(maxChars))
            : cleaned
        Logger.importPipeline.info("Sending \(trimmedText.count, privacy: .public) chars to Claude API (cleaned from \(htmlText.count, privacy: .public) chars HTML)")

        let userPrompt = """
            This is the readable text extracted from a recipe webpage. \
            Ignore navigation, ads, comments, related-recipes lists, \
            cookie banners, and footer boilerplate. Focus on the recipe \
            content itself.

            \(RecipeImageExtractor.schemaInstructions)

            If you cannot find a clear, complete recipe in this text, \
            respond with exactly this JSON: {"error": "no_recipe_found"}. \
            Do NOT make up or guess a recipe.

            Here is the webpage text:

            \(trimmedText)
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

    /// Phase 1 string-based readability pass. Strips obvious noise
    /// blocks (script/style/nav/header/footer/aside), removes the
    /// remaining HTML tags, decodes a handful of common entities, and
    /// collapses runs of whitespace. Not a full readability port —
    /// just enough to keep token spend on recipe content. JSON-LD
    /// extraction runs against raw HTML and is unaffected.
    private static func cleanForExtraction(_ html: String) -> String {
        var text = html

        let blockTags = ["script", "style", "nav", "header", "footer", "aside", "form", "iframe", "noscript"]
        for tag in blockTags {
            let pattern = "(?is)<\(tag)\\b[^>]*>.*?</\(tag)>"
            text = text.replacingOccurrences(
                of: pattern,
                with: " ",
                options: .regularExpression
            )
        }

        // Strip remaining HTML tags.
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        // Decode the HTML entities that show up in nearly every page.
        // Anything fancier (e.g. numeric entities) is rare enough in
        // recipe body content to skip in Phase 1.
        let entities: [(String, String)] = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&rsquo;", "'"),
            ("&lsquo;", "'"),
            ("&rdquo;", "\""),
            ("&ldquo;", "\""),
            ("&mdash;", "—"),
            ("&ndash;", "–")
        ]
        for (from, to) in entities {
            text = text.replacingOccurrences(of: from, with: to)
        }

        // Collapse whitespace runs to a single space, then trim.
        text = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
