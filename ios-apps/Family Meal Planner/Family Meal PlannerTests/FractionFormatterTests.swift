//
//  FractionFormatterTests.swift
//  Family Meal PlannerTests
//

import XCTest
@testable import Family_Meal_Planner

final class FractionFormatterTests: XCTestCase {

    // MARK: - formatAsFraction

    func testFormatWholeNumber() {
        XCTAssertEqual(FractionFormatter.formatAsFraction(2.0), "2")
    }

    func testFormatZeroOrNegativeReturnsZero() {
        XCTAssertEqual(FractionFormatter.formatAsFraction(0), "0")
        XCTAssertEqual(FractionFormatter.formatAsFraction(-1), "0")
    }

    func testFormatOneEighth() {
        XCTAssertEqual(FractionFormatter.formatAsFraction(0.125), "1/8")
    }

    func testFormatOneQuarter() {
        XCTAssertEqual(FractionFormatter.formatAsFraction(0.25), "1/4")
    }

    func testFormatOneThird() {
        XCTAssertEqual(FractionFormatter.formatAsFraction(1.0 / 3.0), "1/3")
    }

    func testFormatThreeEighths() {
        XCTAssertEqual(FractionFormatter.formatAsFraction(0.375), "3/8")
    }

    func testFormatOneHalf() {
        XCTAssertEqual(FractionFormatter.formatAsFraction(0.5), "1/2")
    }

    func testFormatFiveEighths() {
        XCTAssertEqual(FractionFormatter.formatAsFraction(0.625), "5/8")
    }

    func testFormatTwoThirds() {
        XCTAssertEqual(FractionFormatter.formatAsFraction(2.0 / 3.0), "2/3")
    }

    func testFormatThreeQuarters() {
        XCTAssertEqual(FractionFormatter.formatAsFraction(0.75), "3/4")
    }

    func testFormatSevenEighths() {
        XCTAssertEqual(FractionFormatter.formatAsFraction(0.875), "7/8")
    }

    func testFormatMixedNumber() {
        XCTAssertEqual(FractionFormatter.formatAsFraction(1.5), "1 1/2")
    }

    func testFormatMixedNumberWithThird() {
        XCTAssertEqual(FractionFormatter.formatAsFraction(2.0 + 1.0/3.0), "2 1/3")
    }

    func testFormatDecimalFallback() {
        // 0.15 is not close to any cooking fraction — falls back to one decimal place
        // (IEEE 754: 0.15 is stored as ~0.14999..., so %.1f rounds to "0.1")
        XCTAssertEqual(FractionFormatter.formatAsFraction(0.15), "0.1")
    }

    func testFormatLargeWholeNumber() {
        XCTAssertEqual(FractionFormatter.formatAsFraction(12.0), "12")
    }

    func testFormatBoundaryTolerance() {
        // 0.51 is within 0.02 of 0.5 → should match "1/2"
        XCTAssertEqual(FractionFormatter.formatAsFraction(0.51), "1/2")
    }

    func testFormatOutsideTolerance() {
        // 0.53 is outside 0.02 of 0.5 → decimal fallback
        XCTAssertEqual(FractionFormatter.formatAsFraction(0.53), "0.5")
    }

    // MARK: - parseFraction

    func testParseInteger() {
        XCTAssertEqual(FractionFormatter.parseFraction("3"), 3.0)
    }

    func testParseDecimal() {
        XCTAssertEqual(FractionFormatter.parseFraction("0.75"), 0.75)
    }

    func testParseSimpleFraction() {
        XCTAssertEqual(FractionFormatter.parseFraction("1/2"), 0.5)
    }

    func testParseMixedNumber() {
        XCTAssertEqual(FractionFormatter.parseFraction("1 1/2"), 1.5)
    }

    func testParseEmptyStringReturnsNil() {
        XCTAssertNil(FractionFormatter.parseFraction(""))
    }

    func testParseWhitespaceOnlyReturnsNil() {
        XCTAssertNil(FractionFormatter.parseFraction("   "))
    }

    func testParseInvalidTextReturnsNil() {
        XCTAssertNil(FractionFormatter.parseFraction("abc"))
    }

    func testParseDivideByZeroReturnsNil() {
        XCTAssertNil(FractionFormatter.parseFraction("1/0"))
    }

    func testParseTrimsWhitespace() {
        XCTAssertEqual(FractionFormatter.parseFraction("  1/2  "), 0.5)
    }

    func testParseThirds() {
        let result = FractionFormatter.parseFraction("1/3")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1.0 / 3.0, accuracy: 0.001)
    }
}
