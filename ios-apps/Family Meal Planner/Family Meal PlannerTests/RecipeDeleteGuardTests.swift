//
//  RecipeDeleteGuardTests.swift
//  Family Meal PlannerTests
//
//  Bug 1 from the 2026-09-06 build-119 report: "Best Whole30
//  Shepherd's Pie" could never be deleted — the delete guard
//  (isRecipeScheduled) counted meal_plans rows on ANY date, while the
//  week view only lets the user remove today-or-later entries. A
//  past-week entry blocked deletion forever.
//
//  The schema has no archived/soft-delete state for meal plan entries:
//  removal is a hard DELETE, and "past" only means date < today. The
//  guard now blocks solely on live (today-or-later) entries; recipe
//  deletion leaves past entries as recipe-less history rows
//  (meal_plans.recipe_id is ON DELETE SET NULL).
//
//  Runs the real MealPlanService/GroceryService against the in-memory
//  fake PostgREST backend (FakePostgRESTStore) — no network.
//

import XCTest
@testable import Family_Meal_Planner

final class RecipeDeleteGuardTests: XCTestCase {

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

    private func iso(daysFromToday offset: Int, today: Date) -> String {
        MealPlanService.isoDate(from: today.addingTimeInterval(Double(offset) * 86_400))
    }

    // MARK: - Guard scope

    @MainActor
    func testGuardBlocksWhenLiveEntryExists() async throws {
        let service = MealPlanService()
        let today = Date()
        let recipeID = UUID()

        TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: recipeID,
            memberID: nil, dateISO: iso(daysFromToday: 0, today: today)
        )
        let blockedToday = await service.isRecipeScheduled(recipeID, asOf: today)
        XCTAssertTrue(blockedToday, "An entry dated today is live and must block deletion")

        let futureRecipeID = UUID()
        TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: futureRecipeID,
            memberID: nil, dateISO: iso(daysFromToday: 3, today: today)
        )
        let blockedFuture = await service.isRecipeScheduled(futureRecipeID, asOf: today)
        XCTAssertTrue(blockedFuture, "A future entry is live and must block deletion")
    }

    @MainActor
    func testGuardAllowsAfterRemoval() async throws {
        let mealPlanService = MealPlanService()
        let groceryService = GroceryService()
        let today = Date()
        let recipeID = UUID()

        let planID = TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: recipeID,
            memberID: nil, dateISO: iso(daysFromToday: 1, today: today)
        )
        let blockedBefore = await mealPlanService.isRecipeScheduled(recipeID, asOf: today)
        XCTAssertTrue(blockedBefore)

        let removed = await mealPlanService.removeMeal(planID, groceryService: groceryService)
        XCTAssertTrue(removed, "Removal of an existing entry should succeed")

        let blockedAfter = await mealPlanService.isRecipeScheduled(recipeID, asOf: today)
        XCTAssertFalse(blockedAfter, "The guard must agree with the removal it just allowed")
    }

    @MainActor
    func testGuardIgnoresPastOnlyEntries() async throws {
        let service = MealPlanService()
        let today = Date()
        let recipeID = UUID()

        // Last week (reachable but read-only in the week view) and five
        // weeks ago (not even reachable) — the Shepherd's Pie shape.
        TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: recipeID,
            memberID: nil, dateISO: iso(daysFromToday: -7, today: today)
        )
        TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: recipeID,
            memberID: nil, dateISO: iso(daysFromToday: -35, today: today)
        )

        let blocked = await service.isRecipeScheduled(recipeID, asOf: today)
        XCTAssertFalse(blocked,
                       "Past entries can't be removed through the UI, so they must not block deletion")
    }

    // MARK: - Removal failure surfaces

    /// PostgREST reports success on a DELETE that RLS reduced to zero
    /// rows. removeMeal must detect that (via .select() verification),
    /// report failure, and leave groceries untouched — the old code
    /// stripped the meal's groceries FIRST and then "succeeded".
    @MainActor
    func testRemoveMealSurfacesSilentlyBlockedDelete() async throws {
        let mealPlanService = MealPlanService()
        let groceryService = GroceryService()
        let today = Date()

        let planID = TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: UUID(),
            memberID: nil, dateISO: iso(daysFromToday: 1, today: today)
        )
        let itemID = UUID()
        FakePostgRESTStore.shared.seed(table: "grocery_items", rows: [[
            "id": itemID.uuidString.lowercased(),
            "household_id": Self.householdID.uuidString.lowercased(),
            "name": "ground lamb", "quantity": 2.0, "unit": "lb",
            "is_checked": false, "created_at": TestFixtures.storeTimestamp,
        ]])
        FakePostgRESTStore.shared.seed(table: "grocery_contributions", rows: [[
            "id": UUID().uuidString.lowercased(),
            "grocery_item_id": itemID.uuidString.lowercased(),
            "meal_plan_id": planID.uuidString.lowercased(),
            "quantity": 2.0,
        ]])

        FakePostgRESTStore.shared.rlsDeleteBlockedTables = ["meal_plans"]
        let removed = await mealPlanService.removeMeal(planID, groceryService: groceryService)
        FakePostgRESTStore.shared.rlsDeleteBlockedTables = []

        XCTAssertFalse(removed, "A delete that affected zero rows must be reported as a failure")
        XCTAssertNotNil(mealPlanService.errorMessage, "The failure must carry a user-facing message")
        XCTAssertEqual(FakePostgRESTStore.shared.rows(in: "meal_plans").count, 1,
                       "The meal is still on the plan")
        let item = FakePostgRESTStore.shared.rows(in: "grocery_items").first
        XCTAssertEqual(item?["quantity"] as? Double, 2.0,
                       "Groceries must NOT be settled for a meal that wasn't actually removed")
        XCTAssertEqual(FakePostgRESTStore.shared.rows(in: "grocery_contributions").count, 1)
    }

    // MARK: - Remove-and-delete path

    @MainActor
    func testRemoveScheduledMealsRemovesOnlyLiveEntries() async throws {
        let mealPlanService = MealPlanService()
        let groceryService = GroceryService()
        let today = Date()
        let recipeID = UUID()

        let pastID = TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: recipeID,
            memberID: nil, dateISO: iso(daysFromToday: -7, today: today)
        )
        TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: recipeID,
            memberID: nil, dateISO: iso(daysFromToday: 0, today: today)
        )
        TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: recipeID,
            memberID: nil, dateISO: iso(daysFromToday: 4, today: today)
        )

        let removed = await mealPlanService.removeScheduledMeals(
            for: recipeID, groceryService: groceryService, asOf: today
        )
        XCTAssertTrue(removed)

        let remaining = FakePostgRESTStore.shared.rows(in: "meal_plans")
        XCTAssertEqual(remaining.count, 1, "Only the past entry stays (it's history, not plan)")
        XCTAssertEqual(remaining.first?["id"] as? String, pastID.uuidString.lowercased())

        let stillBlocked = await mealPlanService.isRecipeScheduled(recipeID, asOf: today)
        XCTAssertFalse(stillBlocked, "After removal the recipe is deletable")
    }
}
