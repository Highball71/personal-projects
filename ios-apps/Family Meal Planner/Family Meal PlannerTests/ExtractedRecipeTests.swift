//
//  ExtractedRecipeTests.swift
//  Family Meal PlannerTests
//

import XCTest
@testable import Family_Meal_Planner

final class ExtractedRecipeTests: XCTestCase {

    // MARK: - Helpers

    /// Build an ExtractedRecipe with sensible defaults; override only what you need.
    private func makeRecipe(
        name: String = "Test",
        category: String = "dinner",
        servingSize: String? = "4",
        prepTime: String? = "30 minutes",
        cookTime: String? = "45 minutes",
        ingredients: [ExtractedIngredient] = [],
        instructions: [String] = ["Step one"]
    ) -> ExtractedRecipe {
        ExtractedRecipe(
            name: name,
            category: category,
            servingSize: servingSize,
            prepTime: prepTime,
            cookTime: cookTime,
            ingredients: ingredients,
            instructions: instructions,
            source: nil
        )
    }

    // MARK: - recipeCategory

    func testCategoryBreakfast() {
        XCTAssertEqual(makeRecipe(category: "breakfast").recipeCategory, .breakfast)
    }

    func testCategoryLunch() {
        XCTAssertEqual(makeRecipe(category: "lunch").recipeCategory, .lunch)
    }

    func testCategoryDinner() {
        XCTAssertEqual(makeRecipe(category: "dinner").recipeCategory, .dinner)
    }

    func testCategorySnack() {
        XCTAssertEqual(makeRecipe(category: "snack").recipeCategory, .snack)
    }

    func testCategoryDessert() {
        XCTAssertEqual(makeRecipe(category: "dessert").recipeCategory, .dessert)
    }

    func testCategorySide() {
        XCTAssertEqual(makeRecipe(category: "side").recipeCategory, .side)
    }

    func testCategoryDrink() {
        XCTAssertEqual(makeRecipe(category: "drink").recipeCategory, .drink)
    }

    func testCategoryUnknownDefaultsToDinner() {
        XCTAssertEqual(makeRecipe(category: "appetizer").recipeCategory, .dinner)
    }

    func testCategoryCaseInsensitive() {
        XCTAssertEqual(makeRecipe(category: "BREAKFAST").recipeCategory, .breakfast)
        XCTAssertEqual(makeRecipe(category: "Lunch").recipeCategory, .lunch)
    }

    // MARK: - servingsInt

    func testServingsPlainNumber() {
        XCTAssertEqual(makeRecipe(servingSize: "4").servingsInt, 4)
    }

    func testServingsWithText() {
        XCTAssertEqual(makeRecipe(servingSize: "4 servings").servingsInt, 4)
    }

    func testServingsRange() {
        // "4-6" — the leading digits before the dash should give us 4
        XCTAssertEqual(makeRecipe(servingSize: "4-6").servingsInt, 4)
    }

    func testServingsNilDefaults() {
        XCTAssertEqual(makeRecipe(servingSize: nil).servingsInt, 4)
    }

    func testServingsEmptyDefaults() {
        XCTAssertEqual(makeRecipe(servingSize: "").servingsInt, 4)
    }

    // MARK: - prepTimeMinutesInt

    func testPrepTimeMinutes() {
        XCTAssertEqual(makeRecipe(prepTime: "30 minutes").prepTimeMinutesInt, 30)
    }

    func testPrepTimeHour() {
        XCTAssertEqual(makeRecipe(prepTime: "1 hour").prepTimeMinutesInt, 60)
    }

    func testPrepTimeHourAndMinutes() {
        XCTAssertEqual(makeRecipe(prepTime: "1 hour 30 minutes").prepTimeMinutesInt, 90)
    }

    func testPrepTimeMinAbbreviation() {
        XCTAssertEqual(makeRecipe(prepTime: "30 min").prepTimeMinutesInt, 30)
    }

    func testPrepTimeBareNumber() {
        // Bare number treated as minutes
        XCTAssertEqual(makeRecipe(prepTime: "15").prepTimeMinutesInt, 15)
    }

    func testPrepTimeNilDefaultsTo30() {
        XCTAssertEqual(makeRecipe(prepTime: nil).prepTimeMinutesInt, 30)
    }

    // MARK: - cookTimeMinutesInt

    func testCookTimeMinutes() {
        XCTAssertEqual(makeRecipe(cookTime: "45 minutes").cookTimeMinutesInt, 45)
    }

    func testCookTimeNilDefaultsTo0() {
        XCTAssertEqual(makeRecipe(cookTime: nil).cookTimeMinutesInt, 0)
    }

    // MARK: - instructionsText

    func testInstructionsSingleStepNoNumbering() {
        let recipe = makeRecipe(instructions: ["Mix everything together"])
        XCTAssertEqual(recipe.instructionsText, "Mix everything together")
    }

    func testInstructionsMultipleStepsNumbered() {
        let recipe = makeRecipe(instructions: ["Preheat oven", "Mix ingredients", "Bake"])
        let expected = "1. Preheat oven\n2. Mix ingredients\n3. Bake"
        XCTAssertEqual(recipe.instructionsText, expected)
    }

    func testInstructionsEmpty() {
        let recipe = makeRecipe(instructions: [])
        XCTAssertEqual(recipe.instructionsText, "")
    }
}
