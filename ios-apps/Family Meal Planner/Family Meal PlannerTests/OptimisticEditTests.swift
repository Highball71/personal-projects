//
//  OptimisticEditTests.swift
//  Family Meal PlannerTests
//
//  The remove-flicker fix: swipe-to-remove (and Replace) now edit the
//  local week map FIRST — the row leaves the screen before the server
//  round trip — then reconcile quietly. These tests pin the contract:
//  the local edit happens with no server call at all, a failed delete
//  can restore the exact previous rows, and an optimistic Replace
//  touches only its own (date, member) slot.
//
//  Runs the REAL MealPlanService against the in-memory fake PostgREST
//  backend from GroceryUnwindTests.swift.
//

import XCTest
@testable import Family_Meal_Planner

final class OptimisticEditTests: XCTestCase {

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

    private func iso(_ date: Date) -> String {
        MealPlanService.isoDate(from: date)
    }

    /// The heart of the fix: removal updates local state BEFORE the DB
    /// round-trip completes. removeLocalPlan is synchronous — after it
    /// returns, the row is gone from plansByDate while the fake server
    /// still holds it (no request has been made); only then does the
    /// real delete run and the server catch up.
    @MainActor
    func testRemovalUpdatesLocalStateBeforeServerRoundTrip() async throws {
        let service = MealPlanService()
        let groceryService = GroceryService()

        let recipeID = TestFixtures.seedRecipe(
            householdID: Self.householdID, name: "Tacos")
        let today = Calendar.current.startOfDay(for: Date())
        let planID = TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: recipeID,
            memberID: nil, dateISO: iso(today))

        await service.fetchPlans(weekStart: today)
        XCTAssertEqual(service.plansByDate[iso(today)]?.count, 1)

        // Local edit first — synchronous, zero network.
        let snapshot = service.removeLocalPlan(planID, dateISO: iso(today))

        XCTAssertNil(service.plansByDate[iso(today)],
                     "the row must be out of local state immediately")
        XCTAssertEqual(FakePostgRESTStore.shared.rows(in: "meal_plans").count, 1,
                       "the server hasn't been asked yet — local state led")
        XCTAssertEqual(snapshot?.count, 1, "snapshot carries the removed row for restore")

        // Then the round trip completes and the server catches up.
        let removed = await service.removeMeal(planID, groceryService: groceryService)
        XCTAssertTrue(removed)
        XCTAssertTrue(FakePostgRESTStore.shared.rows(in: "meal_plans").isEmpty)

        // The quiet reconcile agrees with the optimistic state and
        // never announces itself as loading.
        let ok = await service.fetchPlans(weekStart: today, quiet: true)
        XCTAssertTrue(ok)
        XCTAssertNil(service.plansByDate[iso(today)])
        XCTAssertFalse(service.isLoading, "quiet fetch never flips isLoading")
    }

    /// A failed delete restores the EXACT previous rows — order and
    /// all — and leaves the rest of the day untouched. (removeLocalDay
    /// shares the same snapshot/restore contract for Clear the Whole
    /// Day.)
    @MainActor
    func testRestoreAfterFailedRemovalPutsBackExactRows() async throws {
        let service = MealPlanService()

        let recipeID = TestFixtures.seedRecipe(
            householdID: Self.householdID, name: "Pasta")
        let today = Calendar.current.startOfDay(for: Date())
        let maya = UUID()
        let householdPlanID = TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: recipeID,
            memberID: nil, dateISO: iso(today))
        _ = TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: recipeID,
            memberID: maya, dateISO: iso(today))

        await service.fetchPlans(weekStart: today)
        let before = service.plansByDate[iso(today)]
        XCTAssertEqual(before?.count, 2)

        let snapshot = service.removeLocalPlan(householdPlanID, dateISO: iso(today))
        XCTAssertEqual(service.plansByDate[iso(today)]?.count, 1,
                       "only the removed row leaves; Maya's meal stays")

        service.restoreLocalPlans(snapshot, dateISO: iso(today))
        XCTAssertEqual(service.plansByDate[iso(today)], before,
                       "restore is exact — same rows, same order")

        // Whole-day variant: clear locally, restore exactly.
        let daySnapshot = service.removeLocalDay(dateISO: iso(today))
        XCTAssertNil(service.plansByDate[iso(today)])
        service.restoreLocalPlans(daySnapshot, dateISO: iso(today))
        XCTAssertEqual(service.plansByDate[iso(today)], before)
    }

    /// Optimistic Replace swaps only its own (date, member) slot: a
    /// household replace leaves member meals alone, and vice versa.
    @MainActor
    func testReplaceLocalSlotReplacesOnlyItsOwnSlot() async throws {
        let service = MealPlanService()

        let oldRecipeID = TestFixtures.seedRecipe(
            householdID: Self.householdID, name: "Old Tacos")
        let today = Calendar.current.startOfDay(for: Date())
        let maya = UUID()
        _ = TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: oldRecipeID,
            memberID: nil, dateISO: iso(today))
        _ = TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: oldRecipeID,
            memberID: maya, dateISO: iso(today))

        await service.fetchPlans(weekStart: today)
        XCTAssertEqual(service.plansByDate[iso(today)]?.count, 2)

        let newRecipeID = UUID()
        let replacement = MealPlanRow(
            id: UUID(),
            householdID: Self.householdID,
            recipeID: newRecipeID,
            memberID: nil,          // the household slot
            date: iso(today)
        )
        service.replaceLocalSlot(with: replacement)

        let rows = service.plansByDate[iso(today)] ?? []
        XCTAssertEqual(rows.count, 2, "still one household + one member meal")
        let householdRow = rows.first { $0.memberID == nil }
        XCTAssertEqual(householdRow?.recipeID, newRecipeID,
                       "the household slot holds the replacement")
        XCTAssertNotNil(rows.first { $0.memberID == maya },
                        "Maya's meal was never touched")
    }
}
