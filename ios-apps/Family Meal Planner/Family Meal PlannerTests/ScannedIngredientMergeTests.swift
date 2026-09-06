//
//  ScannedIngredientMergeTests.swift
//  Family Meal PlannerTests
//
//  The payoff of keeping scanned ingredient names clean (ranges and
//  package sizes in recipe_ingredients.note, never in the name): a
//  photo-scanned ingredient and a hand-entered one land on the SAME
//  grocery row through main's GroceryMerge rules.
//
//  Runs the real GroceryService against the fake PostgREST backend —
//  no network.
//

import XCTest
@testable import Family_Meal_Planner

final class ScannedIngredientMergeTests: XCTestCase {

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

    /// P04's real "extra-virgin olive oil, 5 tablespoons" goes through
    /// the photo-import form conversion, onto the grocery list, and a
    /// hand-entered "olive oil, 1 tbsp" merges into the same row via
    /// the alias table — because the scanned name carries no folded
    /// quantity text anymore.
    @MainActor
    func testScannedAndHandEnteredOliveOilShareOneGroceryRow() async throws {
        let extracted = try PhotoImportFixtures.extractedRecipe("P04-baseline")
        let form = SupabaseRecipeFormViewModel()
        form.populateFrom(extracted)

        let scannedOil = try XCTUnwrap(
            form.ingredientRows.first { $0.name.localizedCaseInsensitiveContains("olive oil") }
        )
        XCTAssertEqual(scannedOil.name, "extra-virgin olive oil",
                       "The scanned name is exactly the printed item — nothing folded in")

        let groceryService = GroceryService()
        // Same shape SupabaseAddRecipeView uses for "add to grocery".
        let scannedAdded = await groceryService.addItems([GroceryItemInsert(
            householdID: Self.householdID,
            name: scannedOil.name,
            quantity: scannedOil.quantity,
            unit: scannedOil.unit.rawValue
        )])
        XCTAssertTrue(scannedAdded)

        let manualAdded = await groceryService.addItems([GroceryItemInsert(
            householdID: Self.householdID,
            name: "olive oil",
            quantity: 1,
            unit: "tbsp"
        )])
        XCTAssertTrue(manualAdded)

        let rows = FakePostgRESTStore.shared.rows(in: "grocery_items")
        XCTAssertEqual(rows.count, 1,
                       "Scanned extra-virgin olive oil and hand-entered olive oil are one pantry item")
        XCTAssertEqual(rows.first?["quantity"] as? Double ?? 0, 6, accuracy: 0.0001,
                       "5 tbsp scanned + 1 tbsp manual")
        XCTAssertEqual(rows.first?["unit"] as? String, "tbsp")
    }
}
