//
//  ExtractedIngredientTests.swift
//  Family Meal PlannerTests
//

import XCTest
@testable import Family_Meal_Planner

final class ExtractedIngredientTests: XCTestCase {

    // MARK: - Helpers

    private func makeIngredient(
        name: String = "flour",
        amount: String = "1",
        unit: String = "cup"
    ) -> ExtractedIngredient {
        ExtractedIngredient(name: name, amount: amount, unit: unit)
    }

    // MARK: - quantityDouble

    func testQuantityInteger() {
        XCTAssertEqual(makeIngredient(amount: "2").quantityDouble, 2.0)
    }

    func testQuantityDecimal() {
        XCTAssertEqual(makeIngredient(amount: "1.5").quantityDouble, 1.5)
    }

    func testQuantitySimpleFraction() {
        XCTAssertEqual(makeIngredient(amount: "1/2").quantityDouble, 0.5)
    }

    func testQuantityMixedNumber() {
        XCTAssertEqual(makeIngredient(amount: "1 1/2").quantityDouble, 1.5)
    }

    func testQuantityThirdFraction() {
        XCTAssertEqual(makeIngredient(amount: "1/3").quantityDouble, 1.0 / 3.0, accuracy: 0.001)
    }

    func testQuantityUnparseableDefaultsTo1() {
        XCTAssertEqual(makeIngredient(amount: "some").quantityDouble, 1.0)
    }

    func testQuantityEmptyDefaultsTo1() {
        XCTAssertEqual(makeIngredient(amount: "").quantityDouble, 1.0)
    }

    func testQuantityWhitespace() {
        XCTAssertEqual(makeIngredient(amount: "  2  ").quantityDouble, 2.0)
    }

    // MARK: - ingredientUnit — exact rawValue matches

    func testUnitExactRawValueTsp() {
        XCTAssertEqual(makeIngredient(unit: "tsp").ingredientUnit, .teaspoon)
    }

    func testUnitExactRawValueTbsp() {
        XCTAssertEqual(makeIngredient(unit: "tbsp").ingredientUnit, .tablespoon)
    }

    func testUnitExactRawValueCup() {
        XCTAssertEqual(makeIngredient(unit: "cup").ingredientUnit, .cup)
    }

    func testUnitExactRawValueOz() {
        XCTAssertEqual(makeIngredient(unit: "oz").ingredientUnit, .ounce)
    }

    func testUnitExactRawValueLb() {
        XCTAssertEqual(makeIngredient(unit: "lb").ingredientUnit, .pound)
    }

    // MARK: - ingredientUnit — plural and long forms

    func testUnitPluralCups() {
        XCTAssertEqual(makeIngredient(unit: "cups").ingredientUnit, .cup)
    }

    func testUnitLongTablespoon() {
        XCTAssertEqual(makeIngredient(unit: "tablespoon").ingredientUnit, .tablespoon)
    }

    func testUnitLongTablespoons() {
        XCTAssertEqual(makeIngredient(unit: "tablespoons").ingredientUnit, .tablespoon)
    }

    func testUnitLongTeaspoon() {
        XCTAssertEqual(makeIngredient(unit: "teaspoon").ingredientUnit, .teaspoon)
    }

    func testUnitPluralOunces() {
        XCTAssertEqual(makeIngredient(unit: "ounces").ingredientUnit, .ounce)
    }

    func testUnitPluralPounds() {
        XCTAssertEqual(makeIngredient(unit: "pounds").ingredientUnit, .pound)
    }

    func testUnitLbs() {
        XCTAssertEqual(makeIngredient(unit: "lbs").ingredientUnit, .pound)
    }

    // MARK: - ingredientUnit — size words map to piece

    func testUnitWholeToPiece() {
        XCTAssertEqual(makeIngredient(unit: "whole").ingredientUnit, .piece)
    }

    func testUnitMediumToPiece() {
        XCTAssertEqual(makeIngredient(unit: "medium").ingredientUnit, .piece)
    }

    func testUnitLargeToPiece() {
        XCTAssertEqual(makeIngredient(unit: "large").ingredientUnit, .piece)
    }

    func testUnitSmallToPiece() {
        XCTAssertEqual(makeIngredient(unit: "small").ingredientUnit, .piece)
    }

    // MARK: - ingredientUnit — weight/volume/count aliases

    func testUnitGrams() {
        XCTAssertEqual(makeIngredient(unit: "grams").ingredientUnit, .gram)
    }

    func testUnitKg() {
        XCTAssertEqual(makeIngredient(unit: "kg").ingredientUnit, .kilogram)
    }

    func testUnitMl() {
        XCTAssertEqual(makeIngredient(unit: "ml").ingredientUnit, .milliliter)
    }

    func testUnitFlOz() {
        XCTAssertEqual(makeIngredient(unit: "fl oz").ingredientUnit, .fluidOunce)
    }

    func testUnitCans() {
        XCTAssertEqual(makeIngredient(unit: "cans").ingredientUnit, .can)
    }

    func testUnitCloves() {
        XCTAssertEqual(makeIngredient(unit: "cloves").ingredientUnit, .clove)
    }

    func testUnitSprigs() {
        XCTAssertEqual(makeIngredient(unit: "sprigs").ingredientUnit, .sprig)
    }

    // MARK: - ingredientUnit — special values

    func testUnitToTaste() {
        XCTAssertEqual(makeIngredient(unit: "to taste").ingredientUnit, .toTaste)
    }

    func testUnitUnknownDefaultsToPiece() {
        XCTAssertEqual(makeIngredient(unit: "handful").ingredientUnit, .piece)
    }

    func testUnitCaseInsensitive() {
        XCTAssertEqual(makeIngredient(unit: "CUPS").ingredientUnit, .cup)
        XCTAssertEqual(makeIngredient(unit: "Tablespoon").ingredientUnit, .tablespoon)
    }

    func testUnitWhitespaceTrimming() {
        // Trimming applies to the alias lookup — "cups" is in aliases, so padded "cups" works
        XCTAssertEqual(makeIngredient(unit: "  cups  ").ingredientUnit, .cup)
    }
}
