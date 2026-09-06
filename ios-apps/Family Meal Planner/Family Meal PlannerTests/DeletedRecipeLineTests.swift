//
//  DeletedRecipeLineTests.swift
//  Family Meal PlannerTests
//
//  A meal_plans row whose recipe was deleted (recipe_id NULLed by the
//  DB's ON DELETE SET NULL) is two different things by date: past =
//  quiet history ("(recipe deleted)", muted, not tappable), today or
//  future = a slot that still needs a meal ("MEAL NEEDS ATTENTION").
//
//  Rows are fetched through the real MealPlanService against the fake
//  PostgREST backend, then classified by the same pure MealLineState
//  rule the week view renders from. No network.
//

import XCTest
@testable import Family_Meal_Planner

final class DeletedRecipeLineTests: XCTestCase {

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

    /// Fetch one week through the service and return the day's rows.
    @MainActor
    private func fetchedRows(weekStart: Date, dateISO: String) async throws -> [MealPlanRow] {
        let service = MealPlanService()
        let fetched = await service.fetchPlans(weekStart: weekStart)
        XCTAssertTrue(fetched, "fetch against the fake backend should succeed")
        return service.plansByDate[dateISO] ?? []
    }

    @MainActor
    func testPastDeletedRecipeRowIsQuietHistory() async throws {
        let today = Date()
        let pastDate = today.addingTimeInterval(-3 * 86_400)
        let pastISO = MealPlanService.isoDate(from: pastDate)
        TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: nil,
            memberID: nil, dateISO: pastISO
        )

        let rows = try await fetchedRows(weekStart: pastDate, dateISO: pastISO)
        XCTAssertEqual(rows.count, 1, "The orphaned row survives the fetch")
        XCTAssertNil(rows[0].recipeID)

        // The grouping keeps it visible…
        let dayPlan = DayPlan.build(from: rows, members: [])
        XCTAssertEqual(dayPlan.householdMeals.count, 1,
                       "Deleted-recipe history must not vanish from the day")

        // …and on a past day it renders as inert history.
        XCTAssertEqual(
            MealLineState.forLine(recipeID: rows[0].recipeID, recipeExists: false, isPast: true),
            .deletedHistory,
            "Past + deleted recipe = \"(recipe deleted)\", muted, not tappable"
        )
    }

    @MainActor
    func testLiveDeletedRecipeRowStillAsksForAttention() async throws {
        let today = Date()
        let todayISO = MealPlanService.isoDate(from: today)
        TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: nil,
            memberID: nil, dateISO: todayISO
        )

        let rows = try await fetchedRows(weekStart: today, dateISO: todayISO)
        XCTAssertEqual(rows.count, 1)
        XCTAssertNil(rows[0].recipeID)

        XCTAssertEqual(
            MealLineState.forLine(recipeID: rows[0].recipeID, recipeExists: false, isPast: false),
            .needsAttention,
            "A live slot with no recipe still needs the user to act"
        )
    }

    /// The unresolved-but-not-deleted case (recipe id present, recipes
    /// cache stale or not loaded) keeps the attention treatment on any
    /// date — the next fetch settles what it really is.
    func testUnresolvedRecipeIDAlwaysAsksForAttention() {
        let id = UUID()
        XCTAssertEqual(MealLineState.forLine(recipeID: id, recipeExists: false, isPast: true), .needsAttention)
        XCTAssertEqual(MealLineState.forLine(recipeID: id, recipeExists: false, isPast: false), .needsAttention)
        XCTAssertEqual(MealLineState.forLine(recipeID: id, recipeExists: true, isPast: true), .recipe)
    }
}
