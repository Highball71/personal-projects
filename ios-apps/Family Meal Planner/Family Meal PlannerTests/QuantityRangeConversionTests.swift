//
//  QuantityRangeConversionTests.swift
//  Family Meal PlannerTests
//
//  Fix 2 from the 2026-09-06 photo-import test report: printed quantity
//  ranges ("1 1/4 to 1 1/2 pounds") used to collapse to quantity 1.
//  They now parse as ParsedQuantity.range, the form row carries the
//  upper bound as its number (so grocery aggregation never under-buys),
//  and the printed range text stays visible.

import XCTest
@testable import Family_Meal_Planner

final class QuantityRangeConversionTests: XCTestCase {

    // MARK: - Parser shapes

    func testRangeSpellings() {
        XCTAssertEqual(ExtractedIngredient.parseQuantity(from: "1 1/4 to 1 1/2"), .range(1.25, 1.5))
        XCTAssertEqual(ExtractedIngredient.parseQuantity(from: "1¼–1½"), .range(1.25, 1.5))
        XCTAssertEqual(ExtractedIngredient.parseQuantity(from: "1-2"), .range(1.0, 2.0))
        XCTAssertEqual(ExtractedIngredient.parseQuantity(from: "2 to 3"), .range(2.0, 3.0))
    }

    func testMixedNumberIsNotMisreadAsRange() {
        // The space and slash in "1 1/2" must never split into a range.
        XCTAssertEqual(ExtractedIngredient.parseQuantity(from: "1 1/2"), .exact(1.5))
        XCTAssertEqual(ExtractedIngredient.parseQuantity(from: "3/4"), .exact(0.75))
    }

    // MARK: - Fixture round-trips (P04 baseline, P10 diagnostic)

    /// The P04 beef: "1 1/4 to 1 1/2" pounds of sirloin/round steak.
    @MainActor
    func testP04BeefRangeRoundTripsThroughForm() throws {
        try assertMeatRange(
            fixture: "P04-baseline",
            nameFragment: "beef sirloin"
        )
    }

    /// The P10 chicken thighs: same printed range.
    @MainActor
    func testP10ChickenThighRangeRoundTripsThroughForm() throws {
        try assertMeatRange(
            fixture: "P10-4096-diagnostic",
            nameFragment: "chicken thighs"
        )
    }

    @MainActor
    private func assertMeatRange(fixture: String, nameFragment: String) throws {
        let extracted = try PhotoImportFixtures.extractedRecipe(fixture)

        let meatIndex = try XCTUnwrap(
            extracted.ingredients.firstIndex { $0.name.contains(nameFragment) },
            "\(fixture) should contain \(nameFragment)"
        )
        let meat = extracted.ingredients[meatIndex]
        XCTAssertEqual(meat.amount, "1 1/4 to 1 1/2", "Fixture ground truth")
        XCTAssertEqual(meat.parsedQuantity, .range(1.25, 1.5))
        XCTAssertEqual(meat.ingredientUnit, .pound)

        let form = SupabaseRecipeFormViewModel()
        form.populateFrom(extracted)
        let row = form.ingredientRows[meatIndex]

        XCTAssertEqual(row.quantity, 1.5, "Numeric quantity is the upper bound, never 1")
        XCTAssertEqual(row.unit, .pound)
        XCTAssertEqual(row.quantityText, "1 1/4 to 1 1/2",
                       "The form's quantity field shows the printed range")
        XCTAssertTrue(row.name.contains("(1 1/4 to 1 1/2 lb)"),
                      "The printed range rides in the name so saved recipe and grocery rows keep it; got \(row.name)")
    }
}
