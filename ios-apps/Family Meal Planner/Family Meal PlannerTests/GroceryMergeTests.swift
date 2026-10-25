//
//  GroceryMergeTests.swift
//  Family Meal PlannerTests
//
//  Bug 2 from the 2026-09-06 build-119 report: olive oil appeared
//  three times on the grocery list, in different measurements, across
//  three recipes — the old merge key was (name, unit), so a unit or
//  descriptor difference made a new row.
//
//  Pure-model tests cover GroceryMerge's rules; the service tests run
//  the real GroceryService against the fake PostgREST backend to prove
//  the DB-merge path (adds from separate recipes) lands on one row.
//

import XCTest
@testable import Family_Meal_Planner

// MARK: - Pure model

final class GroceryMergeTests: XCTestCase {

    private let householdID = UUID()

    private func insert(_ name: String, _ quantity: Double, _ unit: String) -> GroceryItemInsert {
        GroceryItemInsert(householdID: householdID, name: name, quantity: quantity, unit: unit)
    }

    /// The Costco case: 2 tbsp + 1/4 cup + 1 tbsp extra-virgin
    /// = one row, 7 tbsp. (FractionFormatter.formatAsFraction(7) is
    /// "7", so the row displays cleanly as "7 tbsp" — the alternative
    /// "1/4 cup + 3 tbsp" split isn't needed.)
    func testThreeOliveOilRowsMergeToSevenTablespoons() {
        let merged = GroceryMerge.mergeInserts([
            insert("olive oil", 2, "tbsp"),
            insert("olive oil", 0.25, "cup"),
            insert("extra-virgin olive oil", 1, "tbsp"),
        ])

        XCTAssertEqual(merged.count, 1, "One pantry item, one row")
        let row = merged[0]
        XCTAssertEqual(row.name, "olive oil", "The first printed name wins")
        XCTAssertEqual(row.quantity, 7, accuracy: 0.0001, "2 tbsp + 4 tbsp (1/4 cup) + 1 tbsp")
        XCTAssertEqual(row.unit, "tbsp", "The first unit wins as display unit")
        XCTAssertNil(row.note, "Everything merged numerically — no leftover amounts")
        XCTAssertEqual(FractionFormatter.formatAsFraction(row.quantity), "7",
                       "Displays as a clean \"7 tbsp\"")
    }

    func testIncompatibleUnitsShareOneRowWithBothAmounts() {
        let merged = GroceryMerge.mergeInserts([
            insert("fresh cilantro", 1, "piece"),
            insert("fresh cilantro", 2, "tbsp"),
        ])

        XCTAssertEqual(merged.count, 1, "Incompatible units must not split into two rows")
        let row = merged[0]
        XCTAssertEqual(row.quantity, 1, "The first amount stays the row's own")
        XCTAssertEqual(row.unit, "piece")
        XCTAssertEqual(row.note, "2 tbsp", "The other printed amount is kept, never dropped")
    }

    func testSimilarNamesStaySeparate() {
        let merged = GroceryMerge.mergeInserts([
            insert("onion", 1, "piece"),
            insert("green onion", 2, "piece"),
        ])
        XCTAssertEqual(merged.count, 2, "green onion is not onion — no fuzzy matching")
    }

    func testAliasAndWhitespaceNormalization() {
        XCTAssertEqual(GroceryMerge.normalizeName("Extra-Virgin Olive Oil"), "olive oil")
        XCTAssertEqual(GroceryMerge.normalizeName("extra virgin  olive oil"), "olive oil")
        XCTAssertEqual(GroceryMerge.normalizeName("  Olive  Oil "), "olive oil")
        XCTAssertEqual(GroceryMerge.normalizeName("Green Onion"), "green onion",
                       "Not aliased — stays its own item")
    }

    func testRecipeSectionsDoNotBecomePurchasesOrSplitIngredients() {
        let merged = GroceryMerge.mergeInserts([
            insert("For the Filling", 1, "piece"),
            insert("[For the Pork]", 1, "piece"),
            insert("[For the Pork] apple cider", 2, "cup"),
            insert("[For the Slaw] apple cider", 1, "cup"),
            insert("[For the Slaw] extra-virgin olive oil", 2, "tbsp"),
            insert("olive oil", 1, "tsp"),
        ])
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].name, "apple cider")
        XCTAssertEqual(merged[0].quantity, 3)
        XCTAssertEqual(merged[1].quantity, 2 + 1.0 / 3, accuracy: 0.0001)
        XCTAssertEqual(GroceryMerge.normalizeName("[For the Pork] apple cider"), "apple cider")
    }

    func testSectionCleaningPreservesRealIngredientsAndNotes() {
        let names = ["pie filling", "[optional] cilantro", "pork", "apple cider vinegar"]
        for name in names {
            XCTAssertFalse(GroceryMerge.isSectionHeading(name))
            XCTAssertEqual(GroceryMerge.shoppingName(name), name)
        }
        let merged = GroceryMerge.mergeInserts([
            GroceryItemInsert(householdID: householdID,
                              name: "[For the Filling] coconut milk", quantity: 1,
                              unit: "can", note: "14 ounces, unsweetened")
        ])
        XCTAssertEqual(merged.first?.name, "coconut milk")
        XCTAssertEqual(merged.first?.note, "14 ounces, unsweetened")
        XCTAssertEqual(merged.first?.quantity, 1)
    }

    func testUnitConversionFamilies() {
        // US volume
        XCTAssertEqual(GroceryMerge.convert(1, from: "tbsp", to: "tsp"), 3)
        XCTAssertEqual(GroceryMerge.convert(0.25, from: "cup", to: "tbsp"), 4)
        // US weight (legacy plural spellings included)
        XCTAssertEqual(GroceryMerge.convert(1, from: "lb", to: "oz"), 16)
        XCTAssertEqual(GroceryMerge.convert(8, from: "ounces", to: "lb"), 0.5)
        // Metric
        XCTAssertEqual(GroceryMerge.convert(1, from: "kg", to: "g"), 1000)
        XCTAssertEqual(GroceryMerge.convert(500, from: "mL", to: "L"), 0.5)
        // Across families: never converted
        XCTAssertNil(GroceryMerge.convert(1, from: "cup", to: "g"))
        XCTAssertNil(GroceryMerge.convert(1, from: "oz", to: "fl oz"),
                     "Weight ounces and fluid ounces are different families")
        XCTAssertNil(GroceryMerge.convert(1, from: "piece", to: "tbsp"))
    }
}

// MARK: - Service-level (fake PostgREST backend, no network)

final class GroceryMergeServiceTests: XCTestCase {

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

    private func insert(_ name: String, _ quantity: Double, _ unit: String) -> GroceryItemInsert {
        GroceryItemInsert(householdID: Self.householdID, name: name, quantity: quantity, unit: unit)
    }

    /// Adds from separate recipes (separate addItems calls) exercise
    /// the DB-merge path, not just the in-batch one: the second call
    /// must find the existing row and sum into ITS unit.
    @MainActor
    func testAddsFromSeparateRecipesLandOnOneOliveOilRow() async throws {
        let groceryService = GroceryService()

        let first = await groceryService.addItems([insert("olive oil", 2, "tbsp")])
        XCTAssertTrue(first)
        let second = await groceryService.addItems([
            insert("olive oil", 0.25, "cup"),
            insert("extra-virgin olive oil", 1, "tbsp"),
        ])
        XCTAssertTrue(second)

        let rows = FakePostgRESTStore.shared.rows(in: "grocery_items")
        XCTAssertEqual(rows.count, 1, "Three olive-oil amounts across two adds → one row")
        XCTAssertEqual(rows.first?["quantity"] as? Double ?? 0, 7, accuracy: 0.0001)
        XCTAssertEqual(rows.first?["unit"] as? String, "tbsp",
                       "The existing row's unit is the display unit")
    }

    @MainActor
    func testSectionedMealContributionsMergeAndUnwind() async throws {
        let service = GroceryService()
        let mealID = UUID()
        let first = await service.addItems([insert("apple cider", 1, "cup")])
        XCTAssertTrue(first)
        let added = await service.addItemsForMealPlan(mealPlanID: mealID, items: [
            insert("For the Filling", 1, "piece"),
            insert("[For the Pork] apple cider", 2, "cup"),
            insert("[For the Slaw] apple cider", 1, "cup")
        ])
        XCTAssertTrue(added)
        XCTAssertEqual(service.items.count, 1)
        XCTAssertEqual(service.items.first?.quantity, 4)
        let contributions = await service.fetchContributions(forMealPlans: [mealID])
        XCTAssertEqual(contributions?.count, 1)
        XCTAssertEqual(contributions?.first?.quantity, 3)
        let settled = await service.settleContributions(contributions ?? [])
        XCTAssertTrue(settled)
        XCTAssertEqual(service.items.count, 1)
        XCTAssertEqual(service.items.first?.quantity, 1)
    }

    @MainActor
    func testIncompatibleAddNotesExistingRow() async throws {
        let groceryService = GroceryService()

        let first = await groceryService.addItems([insert("fresh cilantro", 1, "piece")])
        XCTAssertTrue(first)
        let second = await groceryService.addItems([insert("fresh cilantro", 2, "tbsp")])
        XCTAssertTrue(second)

        let rows = FakePostgRESTStore.shared.rows(in: "grocery_items")
        XCTAssertEqual(rows.count, 1, "Still one row")
        XCTAssertEqual(rows.first?["quantity"] as? Double, 1, "The row's own amount is untouched")
        XCTAssertEqual(rows.first?["unit"] as? String, "piece")
        XCTAssertEqual(rows.first?["note"] as? String, "2 tbsp",
                       "The unmergeable amount is preserved on the row")
    }
}
