//
//  JSONLDRecipeParserTests.swift
//  Family Meal PlannerTests
//

import XCTest
@testable import Family_Meal_Planner

final class JSONLDRecipeParserTests: XCTestCase {

    // MARK: - Helpers

    /// Wrap a JSON-LD object in a minimal HTML page.
    private func html(withJSONLD json: String) -> String {
        """
        <html><head>
        <script type="application/ld+json">\(json)</script>
        </head><body></body></html>
        """
    }

    /// Minimal valid Recipe JSON-LD — name + one ingredient.
    private var minimalRecipeJSON: String {
        """
        {
          "@type": "Recipe",
          "name": "Test Recipe",
          "recipeIngredient": ["1 cup flour"],
          "recipeInstructions": ["Mix well"]
        }
        """
    }

    // MARK: - Basic extraction

    func testValidRecipeExtraction() {
        let result = JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: minimalRecipeJSON))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Test Recipe")
    }

    func testMissingRecipeSchemaReturnsNil() {
        let json = """
        {"@type": "Organization", "name": "Acme"}
        """
        XCTAssertNil(JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json)))
    }

    func testEmptyHTMLReturnsNil() {
        XCTAssertNil(JSONLDRecipeParser.extractRecipe(from: ""))
    }

    func testNonRecipeTypeReturnsNil() {
        let json = """
        {"@type": "Article", "name": "How to Cook"}
        """
        XCTAssertNil(JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json)))
    }

    // MARK: - JSON-LD structure variations

    func testGraphArrayExtraction() {
        let json = """
        {
          "@graph": [
            {"@type": "WebPage", "name": "Blog"},
            {"@type": "Recipe", "name": "Graph Recipe",
             "recipeIngredient": ["2 cups sugar"],
             "recipeInstructions": ["Stir"]}
          ]
        }
        """
        let result = JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json))
        XCTAssertEqual(result?.name, "Graph Recipe")
    }

    func testTopLevelArrayExtraction() {
        let json = """
        [
          {"@type": "WebSite", "name": "My Blog"},
          {"@type": "Recipe", "name": "Array Recipe",
           "recipeIngredient": ["1 tsp salt"],
           "recipeInstructions": ["Season"]}
        ]
        """
        let result = JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json))
        XCTAssertEqual(result?.name, "Array Recipe")
    }

    func testTypeAsArrayOfStrings() {
        let json = """
        {
          "@type": ["Recipe"],
          "name": "Multi-Type Recipe",
          "recipeIngredient": ["1 egg"],
          "recipeInstructions": ["Crack egg"]
        }
        """
        let result = JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json))
        XCTAssertEqual(result?.name, "Multi-Type Recipe")
    }

    // MARK: - Ingredient parsing

    func testIngredientCupFlour() {
        let json = """
        {"@type": "Recipe", "name": "R",
         "recipeIngredient": ["1 cup flour"],
         "recipeInstructions": ["Mix"]}
        """
        let result = JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json))
        XCTAssertEqual(result?.ingredients.count, 1)
        XCTAssertEqual(result?.ingredients.first?.amount, "1")
        XCTAssertEqual(result?.ingredients.first?.unit, "cup")
        XCTAssertEqual(result?.ingredients.first?.name, "flour")
    }

    func testIngredientMixedNumber() {
        let json = """
        {"@type": "Recipe", "name": "R",
         "recipeIngredient": ["1 1/2 cups sugar"],
         "recipeInstructions": ["Mix"]}
        """
        let result = JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json))
        XCTAssertEqual(result?.ingredients.first?.amount, "1 1/2")
    }

    func testIngredientSimpleFraction() {
        let json = """
        {"@type": "Recipe", "name": "R",
         "recipeIngredient": ["1/2 teaspoon salt"],
         "recipeInstructions": ["Mix"]}
        """
        let result = JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json))
        XCTAssertEqual(result?.ingredients.first?.amount, "1/2")
        XCTAssertEqual(result?.ingredients.first?.unit, "teaspoon")
    }

    func testIngredientNoNumber() {
        let json = """
        {"@type": "Recipe", "name": "R",
         "recipeIngredient": ["salt to taste"],
         "recipeInstructions": ["Season"]}
        """
        let result = JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json))
        // No leading number — whole string becomes the name
        XCTAssertEqual(result?.ingredients.first?.name, "salt to taste")
        XCTAssertEqual(result?.ingredients.first?.amount, "1")
    }

    func testIngredientPriceStripping() {
        let json = """
        {"@type": "Recipe", "name": "R",
         "recipeIngredient": ["1 cup flour ($0.20)"],
         "recipeInstructions": ["Mix"]}
        """
        let result = JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json))
        // Price should be stripped — name should not contain ($0.20)
        let name = result?.ingredients.first?.name ?? ""
        XCTAssertFalse(name.contains("$"), "Price info should be stripped from ingredient")
    }

    // MARK: - ISO 8601 duration parsing

    func testISO8601PT30M() {
        let json = """
        {"@type": "Recipe", "name": "R",
         "prepTime": "PT30M",
         "recipeIngredient": ["1 cup flour"],
         "recipeInstructions": ["Mix"]}
        """
        let result = JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json))
        XCTAssertEqual(result?.prepTime, "30 minutes")
    }

    func testISO8601PT1H() {
        let json = """
        {"@type": "Recipe", "name": "R",
         "prepTime": "PT1H",
         "recipeIngredient": ["1 egg"],
         "recipeInstructions": ["Cook"]}
        """
        let result = JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json))
        XCTAssertEqual(result?.prepTime, "1 hour")
    }

    func testISO8601PT1H30M() {
        let json = """
        {"@type": "Recipe", "name": "R",
         "cookTime": "PT1H30M",
         "recipeIngredient": ["1 egg"],
         "recipeInstructions": ["Cook"]}
        """
        let result = JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json))
        XCTAssertEqual(result?.cookTime, "1 hour 30 minutes")
    }

    func testISO8601WithDayPrefix() {
        let json = """
        {"@type": "Recipe", "name": "R",
         "prepTime": "P0DT0H30M",
         "recipeIngredient": ["1 egg"],
         "recipeInstructions": ["Cook"]}
        """
        let result = JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json))
        XCTAssertEqual(result?.prepTime, "30 minutes")
    }

    // MARK: - HTML entity decoding

    func testHTMLEntityDecodingInName() {
        let json = """
        {"@type": "Recipe", "name": "Mac &amp; Cheese",
         "recipeIngredient": ["1 cup pasta"],
         "recipeInstructions": ["Cook"]}
        """
        let result = JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json))
        XCTAssertEqual(result?.name, "Mac & Cheese")
    }

    func testRecipeWithNoIngredientsOrInstructionsReturnsNil() {
        let json = """
        {"@type": "Recipe", "name": "Empty Recipe"}
        """
        XCTAssertNil(JSONLDRecipeParser.extractRecipe(from: html(withJSONLD: json)))
    }
}
