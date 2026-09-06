//
//  BetaFormConversionReplayTests.swift
//  Family Meal PlannerTests
//
//  Replays the ten Beta-form-conversion.json snapshots captured on
//  build 119 (the pre-fix form output for every extraction fixture) by
//  running the same fixtures through today's conversion, and asserts
//  the three defect classes from the 2026-09-06 report never produce a
//  "1 piece" row again: quantity ranges, package sizes, and missing
//  amounts.

import XCTest
@testable import Family_Meal_Planner

@MainActor
final class BetaFormConversionReplayTests: XCTestCase {

    func testNoFlaggedIngredientEndsUpAsOnePiece() throws {
        let snapshots = try PhotoImportFixtures.betaFormSnapshots()
        XCTAssertEqual(snapshots.count, 10, "One snapshot per fixture")

        var flaggedCount = 0

        for snapshot in snapshots {
            let fixture = try XCTUnwrap(snapshot["fixture"] as? String)
            let extracted = try PhotoImportFixtures.extractedRecipe(fixture)

            let form = SupabaseRecipeFormViewModel()
            form.populateFrom(extracted)
            XCTAssertEqual(form.ingredientRows.count, extracted.ingredients.count,
                           "\(fixture): rows must map 1:1 to extracted ingredients")

            for (source, row) in zip(extracted.ingredients, form.ingredientRows) {
                let isRange: Bool
                if case .range = source.parsedQuantity { isRange = true } else { isRange = false }
                let packageSize = source.unitAndPackageSize.packageSize
                let missingAmount = source.parsedQuantity == .unspecified

                // The name must never carry conversion-added text —
                // ranges and package sizes live in `note` now. (Source
                // names legitimately contain parentheticals like
                // "(page 285)", so the check targets amount-derived
                // text, not every "(".)
                let printedAmount = source.amount.trimmingCharacters(in: .whitespaces)
                if isRange {
                    XCTAssertFalse(row.name.contains(printedAmount),
                                   "\(fixture): range \"\(printedAmount)\" leaked into name \"\(row.name)\"")
                    XCTAssertEqual(row.note?.contains(printedAmount), true,
                                   "\(fixture): range \"\(printedAmount)\" missing from note")
                }
                if let packageSize {
                    XCTAssertFalse(row.name.contains(packageSize),
                                   "\(fixture): package size \"\(packageSize)\" leaked into name \"\(row.name)\"")
                    XCTAssertEqual(row.note?.contains(packageSize), true,
                                   "\(fixture): package size \"\(packageSize)\" missing from note")
                }

                guard isRange || packageSize != nil || missingAmount else { continue }
                flaggedCount += 1

                XCTAssertFalse(
                    row.quantity == 1 && row.unit == .piece,
                    "\(fixture): \"\(source.name)\" (amount \"\(source.amount)\", unit \"\(source.unit)\") became 1 piece"
                )
            }
        }

        // The report's defect classes actually occur in these fixtures
        // (P04/P10 ranges, P11/P13 packages, P05/P12/P13 garnishes) —
        // if this is 0 the test is asserting nothing.
        XCTAssertGreaterThanOrEqual(flaggedCount, 9,
                                    "Expected the known ranges, package sizes, and garnishes to be exercised")
    }
}
