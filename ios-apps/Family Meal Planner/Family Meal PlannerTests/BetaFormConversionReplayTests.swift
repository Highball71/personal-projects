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
                let hasPackageSize = source.unitAndPackageSize.packageSize != nil
                let missingAmount = source.parsedQuantity == .unspecified

                guard isRange || hasPackageSize || missingAmount else { continue }
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
