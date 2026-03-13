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

    private static let singleImagePrompt = """
        Extract the recipe from this image. Return JSON with these fields: \
        name (string), category (string - one of: breakfast, lunch, dinner, \
        snack, dessert, side, drink), servingSize (string), prepTime (string), \
        cookTime (string), ingredients (array of objects with: name, amount, \
        unit), instructions (array of strings), and source (string or null). \
        Look carefully at the entire photo for any book title, cookbook name, \
        website name, or source attribution — check headers, footers, margins, \
        watermarks, and page edges. Include it in the JSON as "source" \
        (e.g. "The Whole30 Slow Cooker"). If you can't find one, set source \
        to null.
        """

    private static let multiPagePrompt = """
        These are photos of consecutive pages from a single recipe. \
        Combine them into one complete recipe. If content overlaps \
        between pages, deduplicate intelligently. Return the unified \
        recipe with JSON fields: name (string), category (string - \
        one of: breakfast, lunch, dinner, snack, dessert, side, drink), \
        servingSize (string), prepTime (string), cookTime (string), \
        ingredients (array of objects with: name, amount, unit), \
        instructions (array of strings), and source (string or null). \
        Look carefully at all photos for any book title, cookbook name, \
        website name, or source attribution — check headers, footers, \
        margins, watermarks, and page edges. Include it in the JSON \
        as "source". If you can't find one, set source to null.
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
            timeout: 60
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
