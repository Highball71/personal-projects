//
//  ClaudeAPIService.swift
//  Family Meal Planner
//

import Foundation
import UIKit

/// Sends images and text to the Anthropic Claude API (Messages endpoint)
/// and parses structured recipe data from the response.
///
/// This is the app's only networking code. Uses URLSession directly
/// with Swift async/await — no third-party HTTP libraries.
enum ClaudeAPIService {

    // MARK: - Configuration

    /// Claude model for vision-based recipe extraction
    static let modelID = "claude-sonnet-4-20250514"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let maxTokens = 2048

    // MARK: - Errors

    enum APIError: LocalizedError {
        case imageConversionFailed
        case urlFetchFailed(String)
        case webpageEmpty
        case noRecipeFound
        case httpError(statusCode: Int, message: String)
        case decodingError(String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .imageConversionFailed:
                "Could not convert the photo to a format the API accepts."
            case .urlFetchFailed(let detail):
                "Could not load the webpage: \(detail)"
            case .webpageEmpty:
                "The webpage didn't contain any readable text."
            case .noRecipeFound:
                "Couldn't find a recipe on that page."
            case .httpError(let code, let message):
                "API error (\(code)): \(message)"
            case .decodingError(let detail):
                "Could not read the recipe from the response: \(detail)"
            case .emptyResponse:
                "The API returned an empty response. Try a clearer photo."
            }
        }
    }

    // MARK: - Public

    /// Extract recipe data from a photo of a cookbook page.
    ///
    /// - Parameter image: A UIImage from the camera or photo library
    /// - Returns: An ExtractedRecipe with parsed fields
    /// - Throws: APIError or KeychainHelper.KeychainError
    static func extractRecipe(from image: UIImage) async throws -> ExtractedRecipe {
        print("[RecipeScan] Starting recipe extraction...")

        // Convert image to base64 JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("[RecipeScan] ERROR: Failed to convert image to JPEG data")
            throw APIError.imageConversionFailed
        }
        let base64String = imageData.base64EncodedString()
        print("[RecipeScan] Image data size: \(imageData.count) bytes (\(String(format: "%.1f", Double(imageData.count) / 1_000_000)) MB)")

        // Get API key from Keychain (never hardcoded)
        let apiKey: String
        do {
            apiKey = try KeychainHelper.getAnthropicAPIKey()
            print("[RecipeScan] API key found in Keychain (\(apiKey.prefix(8))...)")
        } catch {
            #if DEBUG
            // In the Simulator, the iOS Keychain is separate from macOS and won't
            // have the key. Fall back to the ANTHROPIC_API_KEY environment variable
            // (set in the Xcode scheme under Run > Arguments > Environment Variables).
            if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
                apiKey = envKey
                print("[RecipeScan] Keychain unavailable, using ANTHROPIC_API_KEY env var (\(envKey.prefix(8))...)")
            } else {
                print("[RecipeScan] ERROR: Keychain lookup failed and ANTHROPIC_API_KEY env var not set — \(error)")
                throw error
            }
            #else
            print("[RecipeScan] ERROR: Keychain lookup failed — \(error)")
            throw error
            #endif
        }

        // Build and send the request
        let request = try buildRequest(apiKey: apiKey, base64Image: base64String)
        print("[RecipeScan] Sending request to \(endpoint) (model: \(modelID))...")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("[RecipeScan] ERROR: Network request failed — \(error)")
            throw error
        }

        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            print("[RecipeScan] HTTP status: \(httpResponse.statusCode)")
            if !(200...299).contains(httpResponse.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? "No response body"
                print("[RecipeScan] ERROR: API returned error — \(body)")
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: body)
            }
        }

        // Log raw response body
        let rawBody = String(data: data, encoding: .utf8) ?? "<unreadable>"
        print("[RecipeScan] Raw response body:\n\(rawBody)")

        // Parse the response
        do {
            let recipe = try parseRecipeFromResponse(data: data)
            print("[RecipeScan] Successfully parsed recipe: \"\(recipe.name)\"")
            return recipe
        } catch {
            print("[RecipeScan] ERROR: Failed to parse response — \(error)")
            throw error
        }
    }

    /// Extract recipe data from a webpage URL.
    ///
    /// Fetches the page HTML, sends it to Claude as text, and parses the
    /// same ExtractedRecipe JSON structure.
    ///
    /// - Parameter url: The recipe page URL
    /// - Returns: An ExtractedRecipe with parsed fields
    /// - Throws: APIError or KeychainHelper.KeychainError
    static func extractRecipe(fromURL url: URL) async throws -> ExtractedRecipe {
        print("[URLImport] ======= Starting URL import =======")
        print("[URLImport] URL: \(url.absoluteString)")

        // --- STEP 1: Fetch the webpage ---
        print("[URLImport] STEP 1: Fetching webpage...")
        let htmlText: String
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? -1
            let finalURL = httpResponse?.url?.absoluteString ?? "unknown"
            let contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type") ?? "unknown"

            print("[URLImport] STEP 1 result: HTTP \(statusCode)")
            print("[URLImport]   Final URL: \(finalURL)")
            print("[URLImport]   Content-Type: \(contentType)")
            print("[URLImport]   Response size: \(data.count) bytes")

            if !(200...299).contains(statusCode) {
                let body = String(data: data, encoding: .utf8) ?? "<unreadable>"
                print("[URLImport] STEP 1 FAILED: Non-success status code")
                print("[URLImport]   Response body preview: \(String(body.prefix(500)))")
                throw APIError.urlFetchFailed("HTTP \(statusCode)")
            }

            htmlText = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .ascii)
                ?? ""

            // Show the first 500 chars so we can tell if it's real content or a block page
            print("[URLImport]   HTML preview (first 500 chars):")
            print("[URLImport]   \(String(htmlText.prefix(500)))")
        } catch let error as APIError {
            throw error
        } catch {
            print("[URLImport] STEP 1 FAILED: Network error — \(error)")
            throw APIError.urlFetchFailed(error.localizedDescription)
        }

        guard !htmlText.isEmpty else {
            print("[URLImport] STEP 1 FAILED: Response body was empty")
            throw APIError.webpageEmpty
        }

        // Truncate to ~50 KB to keep token usage reasonable
        let maxChars = 50_000
        let trimmedHTML = htmlText.count > maxChars
            ? String(htmlText.prefix(maxChars))
            : htmlText
        print("[URLImport] STEP 1 OK: Fetched \(htmlText.count) chars, sending \(trimmedHTML.count) chars to Claude")

        // --- STEP 2: Get API key ---
        print("[URLImport] STEP 2: Getting API key...")
        let apiKey: String
        do {
            apiKey = try KeychainHelper.getAnthropicAPIKey()
            print("[URLImport] STEP 2 OK: API key found in Keychain (\(apiKey.prefix(8))...)")
        } catch {
            #if DEBUG
            if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
                apiKey = envKey
                print("[URLImport] STEP 2 OK: Using ANTHROPIC_API_KEY env var (\(envKey.prefix(8))...)")
            } else {
                print("[URLImport] STEP 2 FAILED: No API key — Keychain: \(error)")
                throw error
            }
            #else
            print("[URLImport] STEP 2 FAILED: Keychain lookup failed — \(error)")
            throw error
            #endif
        }

        // --- STEP 3: Send to Claude API ---
        print("[URLImport] STEP 3: Sending HTML to Claude API (model: \(modelID))...")
        let request = try buildTextRequest(apiKey: apiKey, webpageHTML: trimmedHTML)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("[URLImport] STEP 3 FAILED: Network error calling Claude — \(error)")
            throw error
        }

        if let httpResponse = response as? HTTPURLResponse {
            print("[URLImport] STEP 3 result: Claude API HTTP \(httpResponse.statusCode)")
            if !(200...299).contains(httpResponse.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? "No response body"
                print("[URLImport] STEP 3 FAILED: Claude API error — \(body)")
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: body)
            }
        }

        let rawBody = String(data: data, encoding: .utf8) ?? "<unreadable>"
        print("[URLImport] STEP 3 OK: Claude response (\(data.count) bytes)")
        print("[URLImport]   Response preview: \(String(rawBody.prefix(500)))")

        // --- STEP 4: Parse extracted recipe ---
        print("[URLImport] STEP 4: Parsing recipe JSON from Claude response...")
        do {
            let recipe = try parseRecipeFromResponse(data: data)
            print("[URLImport] STEP 4 OK: Parsed recipe \"\(recipe.name)\"")
            print("[URLImport] ======= URL import succeeded =======")
            return recipe
        } catch {
            print("[URLImport] STEP 4 FAILED: Could not parse recipe — \(error)")
            throw error
        }
    }

    // MARK: - Private

    /// Build the URLRequest with a vision message containing the base64 image.
    private static func buildRequest(apiKey: String, base64Image: String) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60

        // System prompt: return only valid JSON, no markdown fences
        let systemPrompt = """
            You are a recipe extraction assistant. Return ONLY valid JSON \
            (no markdown, no code fences, no extra text).
            """

        // User prompt matches the exact spec for the expected JSON schema
        let userPrompt = """
            Extract the recipe from this image. Return JSON with these fields: \
            name (string), category (string - one of: breakfast, lunch, dinner, \
            snack, dessert, side, drink), servingSize (string), prepTime (string), \
            cookTime (string), ingredients (array of objects with: name, amount, \
            unit), instructions (array of strings), and sourceDescription (string \
            - describe what this appears to be, like 'Cookbook page' or 'Screenshot \
            of recipe blog')
            """

        let body: [String: Any] = [
            "model": modelID,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": userPrompt
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Build a text-only URLRequest to extract a recipe from webpage HTML.
    private static func buildTextRequest(apiKey: String, webpageHTML: String) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60

        let systemPrompt = """
            You are a recipe extraction assistant. Return ONLY valid JSON \
            (no markdown, no code fences, no extra text).
            """

        let userPrompt = """
            Extract the recipe from this webpage HTML. Return JSON with these fields: \
            name (string), category (string - one of: breakfast, lunch, dinner, \
            snack, dessert, side, drink), servingSize (string), prepTime (string), \
            cookTime (string), ingredients (array of objects with: name, amount, \
            unit), instructions (array of strings), and sourceDescription (string \
            - the name of the website or blog this recipe is from).

            If you cannot find a clear, complete recipe in this text, respond with \
            exactly this JSON: {"error": "no_recipe_found"}. Do NOT make up or guess \
            a recipe.

            Here is the webpage HTML:

            \(webpageHTML)
            """

        let body: [String: Any] = [
            "model": modelID,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Parse the Messages API response, extract the text content,
    /// and decode the JSON into an ExtractedRecipe.
    private static func parseRecipeFromResponse(data: Data) throws -> ExtractedRecipe {
        let apiResponse = try JSONDecoder().decode(ClaudeMessagesResponse.self, from: data)

        guard let textBlock = apiResponse.content.first(where: { $0.type == "text" }),
              let jsonString = textBlock.text else {
            throw APIError.emptyResponse
        }

        // Strip code fences if Claude adds them despite instructions
        let cleaned = stripCodeFences(from: jsonString)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw APIError.decodingError("Could not convert response to data")
        }

        // Check for the "no recipe found" sentinel before attempting recipe decode.
        // The URL extraction prompt tells Claude to return {"error": "no_recipe_found"}
        // when the page doesn't contain a real recipe (e.g. 404 pages, login walls).
        if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           jsonObject["error"] != nil {
            print("[URLImport] Claude reported no recipe found in the page content")
            throw APIError.noRecipeFound
        }

        do {
            return try JSONDecoder().decode(ExtractedRecipe.self, from: jsonData)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    /// Remove markdown code fences (```json ... ```) if present.
    private static func stripCodeFences(from text: String) -> String {
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
