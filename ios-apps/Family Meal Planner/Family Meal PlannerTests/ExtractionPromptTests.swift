//
//  ExtractionPromptTests.swift
//  Family Meal PlannerTests
//
//  The 2026-09-06 accuracy review found the vision extraction reading
//  "3/4 cup" where P05's page prints "1/4 cup", and dropping P02's
//  "unsweetened" / "in pineapple juice" qualifiers. Nothing
//  recipe-specific is hardcoded; instead the prompt demands verbatim
//  transcription and a printedAmount field. These tests pin the prompt
//  wording and prove the schema stayed backward-compatible with every
//  saved fixture.
//

import XCTest
@testable import Family_Meal_Planner

final class ExtractionPromptTests: XCTestCase {

    // MARK: - Prompt wording

    func testPromptDemandsVerbatimFractions() {
        let prompt = RecipeImageExtractor.schemaInstructions
        XCTAssertTrue(prompt.contains("character-for-character"),
                      "Quantities must be transcribed exactly as printed")
        XCTAssertTrue(prompt.contains("round, simplify, convert, or reinterpret a fraction"),
                      "The no-rounding rule must be explicit")
        XCTAssertTrue(prompt.contains("printedAmount"),
                      "The verbatim quantity field must be requested")
    }

    func testPromptDemandsVerbatimQualifiers() {
        let prompt = RecipeImageExtractor.schemaInstructions
        XCTAssertTrue(prompt.contains("VERBATIM"),
                      "Qualifiers must be kept word-for-word")
        XCTAssertTrue(prompt.contains("unsweetened"),
                      "The qualifier rule names the dropped-qualifier failure mode")
        XCTAssertTrue(prompt.contains("must not be dropped"),
                      "Dropping qualifiers must be explicitly forbidden")
    }

    // MARK: - Schema backward compatibility

    /// All twelve bundled fixture files still load: the ten extraction
    /// results decode as ExtractedRecipe (printedAmount is optional —
    /// none of them have it), the snapshot file is its array of ten,
    /// and the P02 reference is well-formed JSON.
    func testAllTwelveFixturesStillDecode() throws {
        let extractionResults = [
            "P02-baseline", "P04-baseline", "P05-4096-diagnostic",
            "P08-baseline", "P09-baseline", "P10-4096-diagnostic",
            "P11-baseline", "P12-baseline", "P13-baseline", "P15-baseline",
        ]
        for fixture in extractionResults {
            let recipe = try PhotoImportFixtures.extractedRecipe(fixture)
            XCTAssertFalse(recipe.ingredients.isEmpty, "\(fixture) decoded but has no ingredients")
            for ingredient in recipe.ingredients {
                XCTAssertNil(ingredient.printedAmount,
                             "\(fixture) predates printedAmount — the optional must decode as nil")
            }
        }

        let snapshots = try PhotoImportFixtures.betaFormSnapshots()
        XCTAssertEqual(snapshots.count, 10)

        let reference = try JSONSerialization.jsonObject(with: PhotoImportFixtures.data("P02-reference")) as? [String: Any]
        XCTAssertNotNil(try XCTUnwrap(reference)["ingredients"], "P02-reference must stay readable")
    }

    // MARK: - printedAmount plumbing

    /// When the model supplies the verbatim text, it wins over the
    /// amount field for parsing and for the preserved note text.
    func testPrintedAmountPreferredOverAmount() throws {
        let ingredient = ExtractedIngredient(
            name: "crushed tomatoes", amount: "1.5", unit: "pounds",
            printedAmount: "1 1/4 to 1 1/2"
        )
        XCTAssertEqual(ingredient.parsedQuantity, .range(1.25, 1.5))

        let recipe = ExtractedRecipe(
            name: "Test", category: "dinner", servingSize: "4",
            prepTime: nil, cookTime: nil,
            ingredients: [ingredient], instructions: ["Step"], source: nil
        )
        let row = recipe.ingredientFormRows[0]
        XCTAssertEqual(row.quantityText, "1 1/4 to 1 1/2")
        XCTAssertEqual(row.note, "1 1/4 to 1 1/2 lb")
    }

    func testPrintedAmountDecodesFromJSON() throws {
        let json = #"{"name":"tomatoes","amount":"0.75","unit":"cup","printedAmount":"3/4"}"#
        let ingredient = try JSONDecoder().decode(ExtractedIngredient.self, from: Data(json.utf8))
        XCTAssertEqual(ingredient.printedAmount, "3/4")
        XCTAssertEqual(ingredient.parsedQuantity, .exact(0.75))
    }
}
