//
//  IngredientDisplayTests.swift
//  Family Meal PlannerTests
//
//  The shared row-wording formatter (round-3 polish). One test per
//  display rule, hand-built inputs, exact rendered strings.
//

import XCTest
@testable import Family_Meal_Planner

final class IngredientDisplayTests: XCTestCase {

    func testContainerRendersCountWordAndAbbreviatedSize() {
        let rendering = IngredientDisplay.render(quantity: 1, unit: "can", note: "14.5 ounces")
        XCTAssertEqual(rendering.quantityLabel, "1 can (14.5 oz)",
                       "Count, container word, size in parentheses with app abbreviations")
        XCTAssertNil(rendering.detailText, "The size is consumed into the label, not repeated")
        XCTAssertEqual(rendering.combined, "1 can (14.5 oz)")
    }

    func testSizeWithoutContainerStaysAsPrinted() {
        let rendering = IngredientDisplay.render(quantity: 4, unit: "piece", note: "about 1 pound total; medium")
        XCTAssertEqual(rendering.quantityLabel, "4 medium",
                       "The rescued size word replaces the generic piece")
        XCTAssertEqual(rendering.detailText, "about 1 pound total",
                       "A size with no container word stays exactly as printed")
    }

    func testPreparationNeverEntersTheQuantityLabel() {
        let rendering = IngredientDisplay.render(quantity: 2, unit: "lb", note: "cut into 1-inch pieces")
        XCTAssertEqual(rendering.quantityLabel, "2 lb")
        XCTAssertEqual(rendering.detailText, "cut into 1-inch pieces")
        XCTAssertEqual(rendering.combined, "2 lb · cut into 1-inch pieces")
    }

    func testNoteRepeatingTheRowQuantityIsSuppressed() {
        let rendering = IngredientDisplay.render(quantity: 14.5, unit: "oz", note: "14.5 ounces")
        XCTAssertEqual(rendering.quantityLabel, "14 1/2 oz")
        XCTAssertNil(rendering.detailText,
                     "A note that only restates the row's own quantity is suppressed on this row")
    }

    func testSectionAndPreparationUseOneSeparatorStyle() {
        let rendering = IngredientDisplay.render(quantity: 2, unit: "tbsp", note: "Marinade: thinly sliced")
        XCTAssertEqual(rendering.detailText, "Marinade · thinly sliced")
        XCTAssertEqual(rendering.combined, "2 tbsp · Marinade · thinly sliced")
    }

    func testToTasteRowKeepsNoteContext() {
        let rendering = IngredientDisplay.render(quantity: 1, unit: "to taste", note: "for garnish")
        XCTAssertEqual(rendering.combined, "to taste · for garnish")
    }

    func testScaleAppliesToTheLabelNotTheNote() {
        let rendering = IngredientDisplay.render(quantity: 1.5, unit: "lb", note: "1¼ to 1½ lb", scale: 2)
        XCTAssertEqual(rendering.combined, "3 lb · 1¼ to 1½ lb",
                       "The printed range is context, never rescaled")
    }

    func testLegacyAndEmptyUnitsRenderAsBefore() {
        XCTAssertEqual(IngredientDisplay.render(quantity: 4, unit: "cups", note: nil).combined, "4 cups")
        XCTAssertEqual(IngredientDisplay.render(quantity: 3, unit: "—", note: nil).combined, "3")
        XCTAssertEqual(IngredientDisplay.render(quantity: 2, unit: "", note: nil).combined, "2")
    }
}
