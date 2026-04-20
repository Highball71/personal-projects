//
//  RecipeImageExtractor.swift
//  FluffyList
//
//  Extracts recipe data from photos of cookbook pages using the Claude Vision API.

import Foundation
import os
import UIKit

enum RecipeImageExtractor {

    enum ExtractionError: LocalizedError {
        case imageConversionFailed

        var errorDescription: String? {
            "Could not convert the photo to a format the API accepts."
        }
    }

    // MARK: - Prompts

    private static let systemPrompt = """
        You are a recipe extraction assistant. Return ONLY valid JSON \
        (no markdown, no code fences, no extra text).
        """

    /// Shared field-list and rules block. Used by both prompts so the
    /// schema and completeness expectations stay in sync. Exposed
    /// (non-private) so RecipeWebImporter can reuse it for the URL-
    /// import Claude fallback prompt — same schema, different framing.
    static let schemaInstructions = """
        Extract ALL recipe content visible in the image(s), including:
          - Recipe headnote / intro / description paragraph above the ingredients
          - Section headers within the ingredient list (e.g. "Sauce", \
            "Sauce (optional)", "For the topping", "For the dressing")
          - Preparation notes printed alongside ingredients (e.g. \
            "sliced and divided", "softened", "room temperature, divided")
          - "Notes", "Tips", "Storage", "Make-Ahead", "Substitutions", \
            "Serving suggestions", "Variations" sections — these are \
            often at the bottom of the page or on a continuation page
          - Total time when separately stated
          - Course / cuisine / keyword tags when present
          - Any source attribution: book title, cookbook name, website \
            name, watermark, header, footer, margin

        Return JSON with these fields:
          name (string),
          category (one of: breakfast, lunch, dinner, snack, dessert, side, drink),
          description (string or null) — the headnote / intro paragraph,
          servingSize (string),
          prepTime (string),
          cookTime (string),
          totalTime (string or null) — only if separately stated,
          ingredients (array of objects, each with):
            name (string),
            amount (string),
            unit (string),
            section (string or null) — header this ingredient sits under, \
              such as "Sauce", "Sauce (optional)", "Topping", \
              "For the marinade"; null if the recipe has a single flat list,
            preparation (string or null) — preparation note printed with \
              the ingredient, e.g. "sliced", "softened, divided"
          instructions (array of strings),
          notes (string or null) — combined Notes / Tips / Storage / \
            Make-Ahead / Substitutions text. Preserve section labels \
            inline (e.g. "Notes:\\n...\\n\\nStorage:\\n..."). Join \
            multiple sections with a blank line between them,
          tags (array of strings or null) — course, cuisine, keyword tags,
          source (string or null) — book title or website name; if you \
            can't find one, set null.

        Rules:
          - Return ONLY valid JSON (no markdown, no code fences, no extra text).
          - Do NOT stop after the first complete-looking recipe body. \
            Read every image edge-to-edge for additional sections.
          - When the same content appears in more than one image \
            (e.g. an ingredient list that runs across two photos), \
            deduplicate intelligently and keep the more complete version.
          - Prefer null over guessing. Empty strings are fine for \
            required string fields when the page truly doesn't say.
        """

    private static let singleImagePrompt = """
        Extract the recipe from this image.

        \(schemaInstructions)
        """

    private static let multiPagePrompt = """
        These are consecutive pages or screens of ONE recipe (often \
        spanning a recipe body + a sauce/topping/notes spread). \
        Combine them into one complete recipe.

        \(schemaInstructions)
        """

    // MARK: - Public

    /// Extract recipe data from one or more photos of cookbook pages.
    static func extract(from images: [UIImage]) async throws -> ExtractedRecipe {
        guard !images.isEmpty else { throw ExtractionError.imageConversionFailed }

        if images.count == 1 {
            return try await extractSingle(from: images[0])
        } else {
            return try await extractMultiPage(from: images)
        }
    }

    // MARK: - Private

    private static func extractSingle(from image: UIImage) async throws -> ExtractedRecipe {
        Logger.importPipeline.info("Starting recipe extraction...")

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            Logger.importPipeline.error("Failed to convert image to JPEG data")
            throw ExtractionError.imageConversionFailed
        }
        let base64String = imageData.base64EncodedString()
        Logger.importPipeline.info("Image data size: \(imageData.count, privacy: .public) bytes")

        Logger.importPipeline.info("Sending request to Claude API...")
        let response = try await AnthropicClient.sendImageMessage(
            systemPrompt: systemPrompt,
            userPrompt: singleImagePrompt,
            base64Image: base64String,
            timeout: 120
        )

        let text = try AnthropicClient.extractText(from: response)
        #if DEBUG
        Logger.importPipeline.debug("Raw response body:\n\(text, privacy: .public)")
        #endif

        let recipe = try RecipeResponseParser.parse(response: text)
        Logger.importPipeline.info("Successfully parsed recipe: \"\(recipe.name)\"")
        return recipe
    }

    private static func extractMultiPage(from images: [UIImage]) async throws -> ExtractedRecipe {
        Logger.importPipeline.info("Starting multi-page extraction (\(images.count, privacy: .public) pages)...")

        var imageContents: [[String: Any]] = []
        for (index, image) in images.enumerated() {
            guard let data = image.jpegData(compressionQuality: 0.8) else {
                Logger.importPipeline.error("Failed to convert page \(index + 1, privacy: .public) to JPEG")
                throw ExtractionError.imageConversionFailed
            }
            Logger.importPipeline.info("Page \(index + 1, privacy: .public): \(data.count, privacy: .public) bytes")
            imageContents.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": data.base64EncodedString()
                ]
            ])
        }

        Logger.importPipeline.info("Sending multi-page request to Claude API...")
        let response = try await AnthropicClient.sendMultiImageMessage(
            systemPrompt: systemPrompt,
            userPrompt: multiPagePrompt,
            imageContents: imageContents,
            timeout: 90
        )

        let text = try AnthropicClient.extractText(from: response)
        #if DEBUG
        Logger.importPipeline.debug("Raw response body:\n\(text, privacy: .public)")
        #endif

        let recipe = try RecipeResponseParser.parse(response: text)
        Logger.importPipeline.info("Successfully parsed multi-page recipe: \"\(recipe.name)\"")
        return recipe
    }
}
