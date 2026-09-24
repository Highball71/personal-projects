//
//  PhotoAttachTests.swift
//  Family Meal PlannerTests
//
//  Regression tests for the silent photo-attach failure (build 121):
//  picking a photo for a recipe could fail at the storage upload or
//  at the path write, and every failure was swallowed — the form
//  even reported a successful save with the photo silently dropped.
//  These run the REAL RecipeService and SupabaseRecipeFormViewModel
//  against the fake PostgREST store (GroceryUnwindTests.swift), which
//  now also emulates the storage upload endpoint.
//

import UIKit
import XCTest
@testable import Family_Meal_Planner

final class PhotoAttachTests: XCTestCase {

    private static let householdID = UUID()

    override func setUp() async throws {
        FakePostgRESTStore.shared.reset()
        URLProtocol.registerClass(FakePostgRESTProtocol.self)
        await MainActor.run {
            SupabaseManager.shared.setCurrentHousehold(Self.householdID)
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            SupabaseManager.shared.setCurrentHousehold(nil)
        }
        URLProtocol.unregisterClass(FakePostgRESTProtocol.self)
        FakePostgRESTStore.shared.reset()
    }

    /// A flat-color image whose backing bitmap is exactly the given
    /// pixel size (renderer scale pinned to 1, like a decoded photo).
    @MainActor
    private func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: width, height: height)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func storedRecipeRow(id: UUID) -> [String: Any]? {
        FakePostgRESTStore.shared.rows(in: "recipes").first {
            ($0["id"] as? String)?.lowercased() == id.uuidString.lowercased()
        }
    }

    // MARK: - Resize

    /// The renderer scale must be pinned to 1 so "max 1200" means
    /// pixels. Unpinned, the renderer used the screen scale, and a 3x
    /// device (or simulator) tripled the bitmap — the old "card photos
    /// upload at ~3600px" quirk.
    @MainActor
    func testCardUploadResizeIsPixelTrue() {
        let resized = RecipeService.resizedForCardUpload(makeImage(width: 3000, height: 2000))
        XCTAssertEqual(resized.size.width * resized.scale, 1200, accuracy: 0.5)
        XCTAssertEqual(resized.size.height * resized.scale, 800, accuracy: 0.5)
    }

    /// An image already within the limit passes through untouched.
    @MainActor
    func testSmallImageIsNotResized() {
        let small = makeImage(width: 800, height: 600)
        XCTAssertTrue(RecipeService.resizedForCardUpload(small) === small)
    }

    // MARK: - Homemade photo (Recipe Detail path)

    /// Happy path: the upload lands in the bucket at the documented
    /// path convention and the row write is verified.
    @MainActor
    func testHomemadeUploadStoresObjectAndWritesPath() async throws {
        let recipeService = RecipeService()
        let recipeID = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Pancakes")

        let path = await recipeService.uploadHomemadeImage(makeImage(width: 100, height: 100), recipeID: recipeID)
        let uploadedPath = try XCTUnwrap(path, "upload should succeed against the emulated bucket")
        XCTAssertEqual(uploadedPath, "\(Self.householdID.uuidString)/\(recipeID.uuidString)/homemade.jpg")
        XCTAssertNotNil(
            FakePostgRESTStore.shared.storageObject(at: "recipe-images/\(uploadedPath)"),
            "the object must actually land in the bucket"
        )

        let wrote = await recipeService.setHomemadeImagePath(uploadedPath, recipeID: recipeID)
        XCTAssertTrue(wrote)
        let row = try XCTUnwrap(storedRecipeRow(id: recipeID))
        XCTAssertEqual(row["homemade_image_path"] as? String, uploadedPath)
    }

    /// A blocked storage upload (missing bucket / RLS) must come back
    /// nil so the view can show an error instead of doing nothing.
    @MainActor
    func testBlockedStorageUploadReturnsNil() async {
        let recipeService = RecipeService()
        let recipeID = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Pancakes")

        FakePostgRESTStore.shared.storageUploadBlocked = true
        let path = await recipeService.uploadHomemadeImage(makeImage(width: 100, height: 100), recipeID: recipeID)
        XCTAssertNil(path)
    }

    // MARK: - Path writes verify their row

    /// PostgREST reports success on an UPDATE that matched zero rows
    /// (RLS-hidden or deleted target). Both path setters must treat
    /// that as failure — the same silent-no-op trap deleteRecipe
    /// already guards against.
    @MainActor
    func testPathSettersFailWhenNoRowIsUpdated() async {
        let recipeService = RecipeService()
        // Nothing seeded — the UPDATE matches no rows.
        let missingID = UUID()
        let homemadeOK = await recipeService.setHomemadeImagePath("x/y/homemade.jpg", recipeID: missingID)
        XCTAssertFalse(homemadeOK)
        let sourceOK = await recipeService.setSourceImagePath("x/y/source.jpg", recipeID: missingID)
        XCTAssertFalse(sourceOK)
    }

    // MARK: - Form save (Add/Edit path)

    /// Editing a recipe with a newly picked photo: a failed upload
    /// must abort the save before anything is written, set saveError,
    /// and keep the picked image so Save can be retried.
    @MainActor
    func testEditSaveFailsWhenPhotoUploadFails() async throws {
        let recipeService = RecipeService()
        let recipeID = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Pancakes")
        await recipeService.fetchRecipes()
        let recipe = try XCTUnwrap(recipeService.recipes.first { $0.id == recipeID })

        let viewModel = SupabaseRecipeFormViewModel(recipe: recipe, ingredients: [])
        viewModel.name = "Pancakes Deluxe"
        viewModel.sourceImage = makeImage(width: 100, height: 100)

        FakePostgRESTStore.shared.storageUploadBlocked = true
        let success = await viewModel.save(recipeService: recipeService)

        XCTAssertFalse(success, "save must not report success when the photo upload failed")
        XCTAssertNotNil(viewModel.saveError)
        XCTAssertNotNil(viewModel.sourceImage, "the picked image must survive for a retry")
        let row = try XCTUnwrap(storedRecipeRow(id: recipeID))
        XCTAssertEqual(row["name"] as? String, "Pancakes", "the aborted save must write nothing")
    }

    /// Creating a recipe with a picked photo while storage is down:
    /// the recipe row exists (it is created before the upload can
    /// run), but the save reports FAILURE with saveError set — and a
    /// retry completes the photo end to end once storage recovers,
    /// because the form transitioned to edit mode with the image kept.
    @MainActor
    func testCreateSaveReportsPhotoFailureAndRetrySucceeds() async throws {
        let recipeService = RecipeService()
        let viewModel = SupabaseRecipeFormViewModel()
        viewModel.name = "Waffles"
        viewModel.sourceImage = makeImage(width: 100, height: 100)

        FakePostgRESTStore.shared.storageUploadBlocked = true
        let firstSave = await viewModel.save(recipeService: recipeService)

        XCTAssertFalse(firstSave, "save must not report success when the photo upload failed")
        XCTAssertNotNil(viewModel.saveError)
        XCTAssertNotNil(viewModel.sourceImage, "the picked image must survive for a retry")
        let createdID = try XCTUnwrap(viewModel.recipeID, "the form should be in edit mode so Save retries")
        var row = try XCTUnwrap(storedRecipeRow(id: createdID), "the recipe row itself was created")
        XCTAssertNil(row["source_image_path"], "no path may be written without an upload")

        FakePostgRESTStore.shared.storageUploadBlocked = false
        let retry = await viewModel.save(recipeService: recipeService)

        XCTAssertTrue(retry)
        XCTAssertNil(viewModel.sourceImage, "the image was consumed by the successful upload")
        row = try XCTUnwrap(storedRecipeRow(id: createdID))
        let expectedPath = "\(Self.householdID.uuidString)/\(createdID.uuidString)/source.jpg"
        XCTAssertEqual(row["source_image_path"] as? String, expectedPath)
        XCTAssertNotNil(FakePostgRESTStore.shared.storageObject(at: "recipe-images/\(expectedPath)"))
    }

    /// The straightforward create-with-photo save writes the object
    /// and the row's source_image_path in one pass.
    @MainActor
    func testCreateSaveWithPhotoSucceeds() async throws {
        let recipeService = RecipeService()
        let viewModel = SupabaseRecipeFormViewModel()
        viewModel.name = "Crepes"
        viewModel.sourceImage = makeImage(width: 100, height: 100)

        let success = await viewModel.save(recipeService: recipeService)
        XCTAssertTrue(success)

        let createdID = try XCTUnwrap(viewModel.recipeID)
        let row = try XCTUnwrap(storedRecipeRow(id: createdID))
        let expectedPath = "\(Self.householdID.uuidString)/\(createdID.uuidString)/source.jpg"
        XCTAssertEqual(row["source_image_path"] as? String, expectedPath)
    }
}
