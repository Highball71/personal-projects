//
//  PackageSizeConversionTests.swift
//  Family Meal PlannerTests
//
//  Fix 3 from the 2026-09-06 photo-import test report:
//    - "1 bag (14 ounces)" / "1 can (14.5 ounces)" / "1 package
//      (14.4 ounces)" used to become "1 piece". The container word is
//      now the unit and the parenthetical size stays on the name.
//    - Ingredients with no printed amount (garnishes) used to become an
//      invented "1 piece". They are now unspecified — rendered as
//      "to taste" with the quantity field blank.

import XCTest
@testable import Family_Meal_Planner

@MainActor
final class PackageSizeConversionTests: XCTestCase {

    private func formRows(_ fixture: String) throws -> (ExtractedRecipe, [IngredientFormData]) {
        let extracted = try PhotoImportFixtures.extractedRecipe(fixture)
        let form = SupabaseRecipeFormViewModel()
        form.populateFrom(extracted)
        return (extracted, form.ingredientRows)
    }

    private func row(named fragment: String, in rows: [IngredientFormData]) throws -> IngredientFormData {
        try XCTUnwrap(rows.first { $0.name.localizedCaseInsensitiveContains(fragment) },
                      "No form row matching \(fragment)")
    }

    // MARK: - Package sizes (P11 bag + can, P13 package)

    func testP11BagAndCanKeepContainerUnitAndSize() throws {
        let (extracted, rows) = try formRows("P11-baseline")

        let bag = try row(named: "bell pepper and onion blend", in: rows)
        XCTAssertEqual(bag.quantity, 1)
        XCTAssertEqual(bag.unit, .bag, "\"1 bag (14 ounces)\" keeps the container word")
        XCTAssertEqual(bag.note, "14 ounces",
                       "The parenthetical size lives in note, not the name")
        XCTAssertFalse(bag.name.contains("14 ounces"),
                       "The name stays clean; got \(bag.name)")

        let can = try row(named: "diced tomatoes", in: rows)
        XCTAssertEqual(can.quantity, 1)
        XCTAssertEqual(can.unit, .can)
        XCTAssertEqual(can.note, "14.5 ounces")
        XCTAssertFalse(can.name.contains("14.5"), "got \(can.name)")

        // The model-level split is exact.
        let bagSource = try XCTUnwrap(extracted.ingredients.first { $0.unit.hasPrefix("bag") })
        XCTAssertEqual(bagSource.unitAndPackageSize.unit, .bag)
        XCTAssertEqual(bagSource.unitAndPackageSize.packageSize, "14 ounces")
    }

    func testP13PackageKeepsContainerUnitAndSize() throws {
        let (_, rows) = try formRows("P13-baseline")

        let package = try row(named: "pepper stir-fry blend", in: rows)
        XCTAssertEqual(package.quantity, 1)
        XCTAssertEqual(package.unit, .package, "\"1 package (14.4 ounces)\" keeps the container word")
        XCTAssertEqual(package.note, "14.4 ounces")
        XCTAssertFalse(package.name.contains("14.4"), "The name stays clean; got \(package.name)")
    }

    // MARK: - Unspecified amounts (P12 sesame oil, P13 parsley, P05 garnishes)

    func testP12SesameOilIsUnspecifiedNotOnePiece() throws {
        let (extracted, rows) = try formRows("P12-baseline")

        let oilSource = try XCTUnwrap(extracted.ingredients.first { $0.name.contains("sesame oil") })
        XCTAssertEqual(oilSource.parsedQuantity, .unspecified)

        let oil = try row(named: "sesame oil", in: rows)
        XCTAssertEqual(oil.unit, .toTaste, "Renders as \"to taste\", quantity field hidden")
        XCTAssertEqual(oil.quantityText, "", "No invented number in the form")
        XCTAssertNil(oil.note, "The page printed no amount at all — nothing to preserve")
        XCTAssertFalse(oil.quantity == 1 && oil.unit == .piece)
    }

    /// When the page DID print an unparseable amount ("to taste",
    /// "for garnish"), that text is preserved in note instead of
    /// being dropped with the unspecified quantity.
    func testPrintedUnparseableAmountPreservedInNote() {
        let recipe = ExtractedRecipe(
            name: "Test", category: "dinner", servingSize: "4",
            prepTime: nil, cookTime: nil,
            ingredients: [
                ExtractedIngredient(name: "salt", amount: "to taste", unit: ""),
                ExtractedIngredient(name: "cilantro", amount: "for garnish", unit: ""),
            ],
            instructions: ["Step"], source: nil
        )
        let rows = recipe.ingredientFormRows
        XCTAssertEqual(rows[0].unit, .toTaste)
        XCTAssertEqual(rows[0].note, "to taste")
        XCTAssertEqual(rows[1].unit, .toTaste)
        XCTAssertEqual(rows[1].note, "for garnish")
        XCTAssertFalse(rows[1].name.contains("garnish"), "Name stays clean: \(rows[1].name)")
    }

    func testP13ParsleyIsUnspecifiedNotOnePiece() throws {
        let (_, rows) = try formRows("P13-baseline")
        let parsley = try row(named: "parsley", in: rows)
        XCTAssertEqual(parsley.unit, .toTaste)
        XCTAssertEqual(parsley.quantityText, "")
    }

    func testP05GarnishesAreUnspecifiedNotOnePiece() throws {
        let (_, rows) = try formRows("P05-4096-diagnostic")
        for fragment in ["salsa", "Guacamole", "cilantro"] {
            let garnish = try row(named: fragment, in: rows)
            XCTAssertEqual(garnish.unit, .toTaste, "\(fragment) has no printed amount")
            XCTAssertEqual(garnish.quantityText, "", "\(fragment) must not invent a quantity")
        }
    }
}
