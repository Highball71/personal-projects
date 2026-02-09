//
//  ClaudeAPIService.swift
//  Family Meal Planner
//

import Foundation
import UIKit

/// Sends images to the Anthropic Claude API (Messages endpoint with Vision)
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
        case httpError(statusCode: Int, message: String)
        case decodingError(String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .imageConversionFailed:
                "Could not convert the photo to a format the API accepts."
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
        // Convert image to base64 JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.imageConversionFailed
        }
        let base64String = imageData.base64EncodedString()

        // Get API key from Keychain (never hardcoded)
        let apiKey = try KeychainHelper.getAnthropicAPIKey()

        // Build and send the request
        let request = try buildRequest(apiKey: apiKey, base64Image: base64String)
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: body)
        }

        // Parse the response
        return try parseRecipeFromResponse(data: data)
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

        // System prompt tells Claude exactly what JSON shape to return,
        // using unit strings that match our IngredientUnit rawValues
        let systemPrompt = """
            You are a recipe extraction assistant. You will be given a photo of a \
            cookbook page or recipe card. Extract the recipe and return ONLY valid \
            JSON (no markdown, no code fences, no extra text) with this exact structure:
            {
              "name": "Recipe Name",
              "category": "dinner",
              "servings": 4,
              "prepTimeMinutes": 30,
              "ingredients": [
                {"name": "Flour", "quantity": 2.0, "unit": "cup"}
              ],
              "instructions": "Step 1...\\nStep 2..."
            }

            Rules:
            - "category" must be one of: breakfast, lunch, dinner, snack, dessert, side
            - "unit" must be one of: piece, cup, tbsp, tsp, oz, lb, g, L, mL, pinch, whole
            - "quantity" must be a number (use decimals: 0.5 for ½, 0.25 for ¼, 0.33 for ⅓, 0.75 for ¾)
            - "instructions" should be the full text with steps separated by newlines
            - If you cannot determine servings or prep time, use reasonable defaults
            - If you cannot read part of the image, do your best with what's visible
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
                            "text": "Please extract the recipe from this photo."
                        ]
                    ]
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
