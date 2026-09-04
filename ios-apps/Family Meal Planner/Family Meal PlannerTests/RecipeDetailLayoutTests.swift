//
//  RecipeDetailLayoutTests.swift
//  Family Meal PlannerTests
//
//  iPad phase 1: the layout decisions for the cookbook-on-a-stand
//  recipe detail. Two things are pinned hard: the compact values ARE
//  the phone's historical constants (the iPhone layout must not
//  change at all), and the regular step column's line measure sits in
//  the readable 60–80 character band.
//

import XCTest
@testable import Family_Meal_Planner

final class RecipeDetailLayoutTests: XCTestCase {

    private let compact = RecipeDetailLayout(isRegular: false)
    private let regular = RecipeDetailLayout(isRegular: true)

    /// Only the regular width gets columns; compact — and therefore
    /// any unknown/nil size class mapped to isRegular == false —
    /// keeps the single phone scroll.
    func testColumnThresholdIsTheRegularSizeClass() {
        XCTAssertFalse(compact.usesTwoColumns)
        XCTAssertTrue(regular.usesTwoColumns)
    }

    /// The compact values are the exact constants the phone layout
    /// has always hardcoded. If one of these fails, the iPhone
    /// rendering changed — which phase 1 forbids.
    func testCompactValuesAreTheHistoricalPhoneConstants() {
        XCTAssertEqual(compact.photoHeight, 230)
        XCTAssertEqual(compact.titleSize, 36)       // .fluffyTitle
        XCTAssertEqual(compact.bodySize, 17)
        XCTAssertEqual(compact.quantitySize, 14)
        XCTAssertEqual(compact.stepNumeralSize, 28)
        XCTAssertEqual(compact.stepNumeralColumnWidth, 34)
        XCTAssertNil(compact.contentMaxWidth, "the phone never caps content width")
        XCTAssertNil(compact.bottomBarMaxWidth, "the phone bar stays full width")
    }

    /// Regular scales everything UP — never down, never equal. Scale,
    /// don't redesign.
    func testRegularScalesUpFromCompact() {
        XCTAssertGreaterThan(regular.photoHeight, compact.photoHeight)
        XCTAssertGreaterThan(regular.titleSize, compact.titleSize)
        XCTAssertGreaterThan(regular.bodySize, compact.bodySize)
        XCTAssertGreaterThan(regular.quantitySize, compact.quantitySize)
        XCTAssertGreaterThan(regular.stepNumeralSize, compact.stepNumeralSize)
        XCTAssertGreaterThan(regular.stepNumeralColumnWidth, compact.stepNumeralColumnWidth)
    }

    /// The line-measure rule: the step column allows roughly 60–80
    /// characters at the regular body size (Inter ≈ 0.5em per
    /// character), readable from a few feet away.
    func testStepColumnMeasureStaysInTheReadableBand() {
        let chars = regular.approxStepCharactersPerLine
        XCTAssertGreaterThanOrEqual(chars, 60, "measure too narrow: \(chars) chars")
        XCTAssertLessThanOrEqual(chars, 80, "measure too wide: \(chars) chars")
    }

    /// The capped content block must actually fit its parts: the
    /// ingredients column, the rule, and a full-measure step column
    /// (plus their internal 22pt paddings) inside contentMaxWidth.
    func testContentCapFitsBothColumnsAtFullMeasure() throws {
        let needed = regular.ingredientColumnWidth + 1 + regular.stepColumnMaxWidth
        let cap = try XCTUnwrap(regular.contentMaxWidth)
        XCTAssertGreaterThanOrEqual(cap, needed,
            "cap \(cap) can't hold ingredients + rule + full step measure (\(needed))")
    }
}
