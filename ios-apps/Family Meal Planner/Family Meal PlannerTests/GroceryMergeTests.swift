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

    func testPreparedProduceNamesStayInPantry() {
        XCTAssertEqual(GroceryCategory.classify("canned tomatoes"), .pantry)
        XCTAssertEqual(GroceryCategory.classify("pepper sauce"), .pantry)
        XCTAssertEqual(GroceryCategory.classify("apple cider"), .pantry)
        XCTAssertEqual(GroceryCategory.classify("apple cider vinegar"), .pantry)
        XCTAssertEqual(GroceryCategory.classify("fresh tomatoes"), .produce)
        XCTAssertEqual(GroceryCategory.classify("fresh bell pepper"), .produce)
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

    func testObservedAlternativeSpellingsCombineWithoutChoosingAnIngredient() {
        let merged = GroceryMerge.mergeInserts([
            insert("arrowroot flour (or tapioca flour)", 2, "tsp"),
            insert("arrowroot flour or tapioca", 2, "tsp"),
            insert("arrowroot flour", 1, "tsp"),
            insert("tapioca flour", 1, "tsp"),
            insert("arrowroot flour or cornstarch", 1, "tsp"),
        ])
        XCTAssertEqual(merged.count, 4)
        XCTAssertEqual(merged[0].quantity, 4)
        XCTAssertTrue(GroceryMerge.hasAlternatives(merged[0].name))
        XCTAssertEqual(merged[1].quantity, 1)
        XCTAssertEqual(merged[2].quantity, 1)
    }

    func testDividedIsCookingContextButOtherQualifiersRemain() {
        let merged = GroceryMerge.mergeInserts([
            insert("extra-virgin olive oil (Divided)", 2, "tbsp"),
            insert("olive oil", 1, "tbsp"),
            insert("extra-virgin olive oil, Clarified Butter, or ghee", 1, "cup"),
        ])
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].name, "extra-virgin olive oil")
        XCTAssertEqual(merged[0].quantity, 3)
        XCTAssertEqual(merged[1].quantity, 1)
        for name in ["tomatoes (14 ounces)", "cilantro (optional)", "salt (to taste)",
                     "flour (gluten-free)", "olive oil (divided, plus extra)"] {
            XCTAssertEqual(GroceryMerge.shoppingName(name), name)
        }
        XCTAssertEqual(GroceryMerge.shoppingLabel("broth or water"), "Choose one: broth or water")
        XCTAssertEqual(GroceryMerge.shoppingLabel("coriander"), "coriander")
        XCTAssertEqual(GroceryMerge.shoppingLabel("olive oil (divided)"), "olive oil")
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
    func testAlternativeAndDividedMealsKeepIndependentContributions() async throws {
        let service = GroceryService()
        let monday = UUID(), wednesday = UUID(), friday = UUID()
        let manual = await service.addItems([insert("olive oil (divided)", 1, "tbsp")])
        XCTAssertTrue(manual)
        let first = await service.addItemsForMealPlan(mealPlanID: monday, items: [
            insert("arrowroot flour (or tapioca flour)", 2, "tsp"),
            insert("olive oil", 2, "tbsp"),
        ])
        let second = await service.addItemsForMealPlan(mealPlanID: wednesday, items: [
            insert("arrowroot flour or tapioca", 2, "tsp"),
            insert("extra-virgin olive oil (divided)", 0.25, "cup"),
        ])
        let third = await service.addItemsForMealPlan(mealPlanID: friday, items: [
            insert("extra-virgin olive oil, Clarified Butter, or ghee", 1, "cup"),
        ])
        XCTAssertTrue(first && second && third)
        XCTAssertEqual(service.items.count, 3)
        XCTAssertEqual(service.items.first { GroceryMerge.normalizeName($0.name) == "olive oil" }?.quantity, 7)
        XCTAssertEqual(service.items.first { $0.name.contains("arrowroot") }?.quantity, 4)
        let fetchedLinks = await service.fetchContributions(forMealPlans: [wednesday])
        let links = try XCTUnwrap(fetchedLinks)
        XCTAssertEqual(links.count, 2)
        let settled = await service.settleContributions(links)
        XCTAssertTrue(settled)
        XCTAssertEqual(service.items.first { GroceryMerge.normalizeName($0.name) == "olive oil" }?.quantity, 3)
        XCTAssertEqual(service.items.first { $0.name.contains("arrowroot") }?.quantity, 2)
        let fetchedRemaining = await service.fetchContributions(forMealPlans: [monday, friday])
        let remaining = try XCTUnwrap(fetchedRemaining)
        let settledRemaining = await service.settleContributions(remaining)
        XCTAssertTrue(settledRemaining)
        XCTAssertEqual(service.items.count, 1)
        XCTAssertEqual(service.items.first?.quantity, 1, "Manual oil survives both meal removals")
    }

    @MainActor
    func testRefreshKeepsLastGoodListOnFailureAndRecovers() async throws {
        let service = GroceryService()
        let added = await service.addItems([insert("apple cider", 1, "cup")])
        XCTAssertTrue(added)
        let firstUpdate = try XCTUnwrap(service.lastRefreshedAt)
        FakePostgRESTStore.shared.failGETTables = ["grocery_items"]
        let failed = await service.fetchItems()
        XCTAssertFalse(failed)
        XCTAssertEqual(service.items.first?.name, "apple cider")
        XCTAssertEqual(service.lastRefreshedAt, firstUpdate)
        XCTAssertNotNil(service.errorMessage)
        XCTAssertFalse(service.isLoading)
        FakePostgRESTStore.shared.failGETTables = []
        let refreshed = await service.fetchItems()
        XCTAssertTrue(refreshed)
        XCTAssertNil(service.errorMessage)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(service.lastRefreshedAt), firstUpdate)
        SupabaseManager.shared.setCurrentHousehold(UUID())
        let other = await service.fetchItems()
        XCTAssertTrue(other)
        XCTAssertTrue(service.items.isEmpty, "Another household must never see the old list")
        SupabaseManager.shared.setCurrentHousehold(nil)
        _ = await service.fetchItems()
        XCTAssertNil(service.lastRefreshedAt)
    }

    @MainActor
    func testCanceledRefreshDoesNotShowConnectionFailure() async throws {
        let service = GroceryService()
        _ = await service.addItems([insert("apple cider", 1, "cup")])
        let updated = service.lastRefreshedAt
        FakePostgRESTStore.shared.cancelGroceryGET = true
        _ = await service.fetchItems()
        XCTAssertNil(service.errorMessage)
        XCTAssertEqual(service.lastRefreshedAt, updated)
        XCTAssertEqual(service.items.first?.name, "apple cider")
        XCTAssertFalse(service.isLoading)
    }

    @MainActor
    func testFailedIngredientReadDoesNotReplacePlannedMeal() async throws {
        let recipeID = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Dinner")
        let recipe = try TestFixtures.recipeRow(id: recipeID, householdID: Self.householdID, name: "Dinner")
        let plans = MealPlanService()
        let existing = await plans.addMeal(recipeID: UUID(), on: Date())
        XCTAssertNotNil(existing)
        FakePostgRESTStore.shared.failGETTables = ["recipe_ingredients"]
        let result = await plans.addMealWithGroceries(recipe: recipe, on: Date(),
            recipeService: RecipeService(), groceryService: GroceryService())
        XCTAssertNil(result)
        let rows = FakePostgRESTStore.shared.rows(in: "meal_plans")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual((rows.first?["id"] as? String)?.lowercased(), existing?.uuidString.lowercased())
        XCTAssertTrue(plans.errorMessage?.contains("hasn't changed") == true)
    }

    @MainActor
    func testGroceryFailureReportsSavedMealInsteadOfFalseSuccess() async throws {
        let recipeID = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Dinner",
                                              ingredients: [("flour", 1, "cup")])
        let recipe = try TestFixtures.recipeRow(id: recipeID, householdID: Self.householdID, name: "Dinner")
        let plans = MealPlanService()
        FakePostgRESTStore.shared.failGETTables = ["grocery_items"]
        let result = await plans.addMealWithGroceries(recipe: recipe, on: Date(),
            recipeService: RecipeService(), groceryService: GroceryService())
        XCTAssertNil(result)
        XCTAssertEqual(FakePostgRESTStore.shared.rows(in: "meal_plans").count, 1)
        XCTAssertTrue(plans.errorMessage?.contains("meal was saved") == true)
        XCTAssertTrue(FakePostgRESTStore.shared.rows(in: "grocery_items").isEmpty)
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
