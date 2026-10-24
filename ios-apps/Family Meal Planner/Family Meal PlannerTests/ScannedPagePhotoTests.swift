//
//  ScannedPagePhotoTests.swift
//  Family Meal PlannerTests
//
//  A photo import attaches the first scanned page as the recipe photo —
//  on success and on a content-filter failure alike — but only when the
//  recipe has no photo yet. A photo the user picked, or one an existing
//  recipe already has, must never be replaced by the scan.
//

import UIKit
import XCTest
@testable import Family_Meal_Planner

@MainActor
final class ScannedPagePhotoTests: XCTestCase {

    private static func page(_ color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    /// RecipeRow has a custom decoder (no memberwise init), so build one
    /// from the same JSON shape Supabase returns.
    private func existingRecipe(sourceImagePath: String?) throws -> RecipeRow {
        var object: [String: Any] = [
            "id": UUID().uuidString,
            "household_id": UUID().uuidString,
            "name": "Mexican Twice Baked Potatoes",
            "created_at": 0,
        ]
        if let sourceImagePath { object["source_image_path"] = sourceImagePath }
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(RecipeRow.self, from: data)
    }

    func testFirstScannedPageIsAttachedWhenNoPhotoIsSet() {
        let form = SupabaseRecipeFormViewModel()
        let first = Self.page(.white)
        let second = Self.page(.black)

        form.attachScannedPageIfNoPhoto([first, second])

        XCTAssertTrue(form.sourceImage === first, "The first page, not a later one")
        XCTAssertTrue(form.sourceImageIsScannedPage)
        XCTAssertFalse(form.sourceImageRemoved)
    }

    func testPickedPhotoIsNotReplacedByScan() {
        let form = SupabaseRecipeFormViewModel()
        let picked = Self.page(.red)
        form.setPickedPhoto(picked)

        form.attachScannedPageIfNoPhoto([Self.page(.white)])

        XCTAssertTrue(form.sourceImage === picked)
        XCTAssertFalse(form.sourceImageIsScannedPage)
    }

    func testStoredPhotoIsNotReplacedByScan() {
        let form = SupabaseRecipeFormViewModel()
        form.sourceImagePath = "household/recipe/source.jpg"

        form.attachScannedPageIfNoPhoto([Self.page(.white)])

        XCTAssertNil(form.sourceImage, "Nothing new to upload — the stored photo stays")
    }

    func testNoPagesAttachesNothing() {
        let form = SupabaseRecipeFormViewModel()
        form.attachScannedPageIfNoPhoto([])
        XCTAssertNil(form.sourceImage)
        XCTAssertFalse(form.sourceImageIsScannedPage)
    }

    /// Duplicate flow, "Update Existing": the existing recipe already has a
    /// photo, so the auto-attached scan page must be dropped, not uploaded
    /// over it.
    func testUpdateExistingKeepsExistingPhotoOverScan() throws {
        let form = SupabaseRecipeFormViewModel()
        form.attachScannedPageIfNoPhoto([Self.page(.white)])

        form.switchToUpdate(of: try existingRecipe(sourceImagePath: "household/recipe/source.jpg"))

        XCTAssertNil(form.sourceImage)
        XCTAssertEqual(form.sourceImagePath, "household/recipe/source.jpg")
        XCTAssertFalse(form.sourceImageIsScannedPage)
    }

    /// "Update Existing" on a recipe with no photo: the scan page stays and
    /// becomes that recipe's photo on save.
    func testUpdateExistingWithoutPhotoKeepsScan() throws {
        let form = SupabaseRecipeFormViewModel()
        let first = Self.page(.white)
        form.attachScannedPageIfNoPhoto([first])

        form.switchToUpdate(of: try existingRecipe(sourceImagePath: nil))

        XCTAssertTrue(form.sourceImage === first)
    }

    /// A photo the user picked themselves still wins in "Update Existing"
    /// — same as before this change.
    func testUpdateExistingKeepsUserPickedPhoto() throws {
        let form = SupabaseRecipeFormViewModel()
        let picked = Self.page(.red)
        form.setPickedPhoto(picked)

        form.switchToUpdate(of: try existingRecipe(sourceImagePath: "household/recipe/source.jpg"))

        XCTAssertTrue(form.sourceImage === picked)
    }
}
