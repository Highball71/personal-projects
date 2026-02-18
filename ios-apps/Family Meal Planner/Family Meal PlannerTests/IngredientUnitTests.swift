//
//  IngredientUnitTests.swift
//  Family Meal PlannerTests
//

import XCTest
@testable import Family_Meal_Planner

final class IngredientUnitTests: XCTestCase {

    // MARK: - Raw value stability (guards against data corruption)

    func testRawValueStability() {
        // These raw values are persisted in SwiftData — changing them
        // would silently corrupt existing user data.
        XCTAssertEqual(IngredientUnit.teaspoon.rawValue, "tsp")
        XCTAssertEqual(IngredientUnit.tablespoon.rawValue, "tbsp")
        XCTAssertEqual(IngredientUnit.cup.rawValue, "cup")
        XCTAssertEqual(IngredientUnit.fluidOunce.rawValue, "fl oz")
        XCTAssertEqual(IngredientUnit.milliliter.rawValue, "mL")
        XCTAssertEqual(IngredientUnit.liter.rawValue, "L")
        XCTAssertEqual(IngredientUnit.ounce.rawValue, "oz")
        XCTAssertEqual(IngredientUnit.pound.rawValue, "lb")
        XCTAssertEqual(IngredientUnit.gram.rawValue, "g")
        XCTAssertEqual(IngredientUnit.kilogram.rawValue, "kg")
        XCTAssertEqual(IngredientUnit.none.rawValue, "—")
        XCTAssertEqual(IngredientUnit.piece.rawValue, "piece")
        XCTAssertEqual(IngredientUnit.pinch.rawValue, "pinch")
        XCTAssertEqual(IngredientUnit.clove.rawValue, "clove")
        XCTAssertEqual(IngredientUnit.can.rawValue, "can")
        XCTAssertEqual(IngredientUnit.package.rawValue, "package")
        XCTAssertEqual(IngredientUnit.bunch.rawValue, "bunch")
        XCTAssertEqual(IngredientUnit.sprig.rawValue, "sprig")
        XCTAssertEqual(IngredientUnit.dash.rawValue, "dash")
        XCTAssertEqual(IngredientUnit.toTaste.rawValue, "to taste")
        XCTAssertEqual(IngredientUnit.whole.rawValue, "whole")
    }

    // MARK: - displayName spot checks

    func testDisplayNameSpotChecks() {
        XCTAssertEqual(IngredientUnit.teaspoon.displayName, "tsp")
        XCTAssertEqual(IngredientUnit.none.displayName, "(none)")
        XCTAssertEqual(IngredientUnit.toTaste.displayName, "to taste")
    }

    // MARK: - pickerCases

    func testPickerCasesExcludesWhole() {
        XCTAssertFalse(IngredientUnit.pickerCases.contains(.whole),
                       "Legacy .whole should not appear in picker")
    }

    func testPickerCasesCount() {
        XCTAssertEqual(IngredientUnit.pickerCases.count, 20)
    }

    func testPickerCasesStartsWithNone() {
        // Must use explicit type — bare `.none` is ambiguous with Optional.none
        XCTAssertEqual(IngredientUnit.pickerCases.first, IngredientUnit.none)
    }

    // MARK: - allCases

    func testAllCasesCount() {
        // 20 picker cases + 1 legacy (.whole) = 21
        XCTAssertEqual(IngredientUnit.allCases.count, 21)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let original = IngredientUnit.tablespoon
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IngredientUnit.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Identifiable

    func testIdMatchesRawValue() {
        for unit in IngredientUnit.allCases {
            XCTAssertEqual(unit.id, unit.rawValue,
                           "\(unit) id should match rawValue")
        }
    }
}
