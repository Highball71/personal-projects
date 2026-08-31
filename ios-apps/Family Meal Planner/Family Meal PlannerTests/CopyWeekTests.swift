//
//  CopyWeekTests.swift
//  Family Meal PlannerTests
//
//  Per-person meals Phase 3: copy-last-week must copy member meals
//  WITH their assignment intact, keep skipping any target slot that
//  already holds a meal for that same target (household, or that
//  member — other slots on the day still copy), and keep skipping
//  past days silently. Copies still route through
//  addMealWithGroceries, so grocery contributions carry over.
//
//  Runs the REAL services against the in-memory fake PostgREST
//  backend from GroceryUnwindTests.swift.
//

import XCTest
@testable import Family_Meal_Planner

final class CopyWeekTests: XCTestCase {

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

    // MARK: - Helpers

    private func day(_ offset: Int, from start: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: start)!
    }

    private func iso(_ date: Date) -> String {
        MealPlanService.isoDate(from: date)
    }

    private func targetRows(dateISO: String) -> [[String: Any]] {
        FakePostgRESTStore.shared.rows(in: "meal_plans")
            .filter { ($0["date"] as? String) == dateISO }
    }

    /// UUID columns arrive uppercase from the SDK's inserts and
    /// lowercase from seeded fixtures — compare lowercased.
    private func memberID(of row: [String: Any]?) -> String? {
        (row?["member_id"] as? String)?.lowercased()
    }

    private func recipeID(of row: [String: Any]?) -> String? {
        (row?["recipe_id"] as? String)?.lowercased()
    }

    /// Copies preserve assignment: last week's household meal copies
    /// as a household meal, Maya's meal copies FOR MAYA, and both
    /// contribute groceries.
    @MainActor
    func testCopyPreservesMemberAssignment() async throws {
        let mealPlanService = MealPlanService()
        let groceryService = GroceryService()
        let recipeService = RecipeService()

        let tacosID = TestFixtures.seedRecipe(
            householdID: Self.householdID, name: "Tacos",
            ingredients: [("tortillas", 8, "piece")])
        let pastaID = TestFixtures.seedRecipe(
            householdID: Self.householdID, name: "Pasta",
            ingredients: [("spaghetti", 1, "lb")])
        let maya = UUID()

        // Last week, same weekday as today: household tacos + Maya's pasta.
        let weekStart = Calendar.current.startOfDay(for: Date())
        let sourceDay = day(-7, from: weekStart)
        TestFixtures.seedMealPlan(householdID: Self.householdID, recipeID: tacosID,
                                  memberID: nil, dateISO: iso(sourceDay))
        TestFixtures.seedMealPlan(householdID: Self.householdID, recipeID: pastaID,
                                  memberID: maya, dateISO: iso(sourceDay))

        let copyResult = await mealPlanService.copyPreviousWeek(
            weekStart: weekStart,
            recipeService: recipeService,
            groceryService: groceryService
        )
        let result = try XCTUnwrap(copyResult)

        XCTAssertEqual(result.copied, 2)
        XCTAssertEqual(result.failed, 0)
        XCTAssertEqual(result.skippedFilled, 0)
        XCTAssertEqual(result.skippedPast, 0)

        let copied = targetRows(dateISO: iso(weekStart))
        XCTAssertEqual(copied.count, 2)
        let householdCopy = try XCTUnwrap(copied.first { memberID(of: $0) == nil })
        XCTAssertEqual(recipeID(of: householdCopy), tacosID.uuidString.lowercased())
        let mayaCopy = try XCTUnwrap(copied.first { memberID(of: $0) == maya.uuidString.lowercased() },
                                     "Maya's meal must be copied for Maya")
        XCTAssertEqual(recipeID(of: mayaCopy), pastaID.uuidString.lowercased())

        // Groceries carried over for both meals.
        XCTAssertEqual(FakePostgRESTStore.shared.rows(in: "grocery_contributions").count, 2)
        XCTAssertNotNil(groceryService.items.first { $0.name == "tortillas" })
        XCTAssertNotNil(groceryService.items.first { $0.name == "spaghetti" })
    }

    /// The skip rule is per (day, member) slot: a target day that
    /// already has a meal for Maya skips ONLY Maya's copy (her meal is
    /// kept, never overwritten) — the household meal still copies onto
    /// that same day, and vice versa.
    @MainActor
    func testCopySkipsFilledSlotsPerTargetNotPerDay() async throws {
        let mealPlanService = MealPlanService()
        let groceryService = GroceryService()
        let recipeService = RecipeService()

        let tacosID = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Tacos")
        let pastaID = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Pasta")
        let curryID = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Curry")
        let soupID = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Soup")
        let maya = UUID()

        let weekStart = Calendar.current.startOfDay(for: Date())

        // Day 0 source: household tacos + Maya's pasta.
        // Day 0 target: Maya already has curry → only tacos copies.
        TestFixtures.seedMealPlan(householdID: Self.householdID, recipeID: tacosID,
                                  memberID: nil, dateISO: iso(day(-7, from: weekStart)))
        TestFixtures.seedMealPlan(householdID: Self.householdID, recipeID: pastaID,
                                  memberID: maya, dateISO: iso(day(-7, from: weekStart)))
        TestFixtures.seedMealPlan(householdID: Self.householdID, recipeID: curryID,
                                  memberID: maya, dateISO: iso(weekStart))

        // Day 1 source: household tacos + Maya's pasta.
        // Day 1 target: household already has soup → only Maya copies.
        TestFixtures.seedMealPlan(householdID: Self.householdID, recipeID: tacosID,
                                  memberID: nil, dateISO: iso(day(-6, from: weekStart)))
        TestFixtures.seedMealPlan(householdID: Self.householdID, recipeID: pastaID,
                                  memberID: maya, dateISO: iso(day(-6, from: weekStart)))
        TestFixtures.seedMealPlan(householdID: Self.householdID, recipeID: soupID,
                                  memberID: nil, dateISO: iso(day(1, from: weekStart)))

        let copyResult = await mealPlanService.copyPreviousWeek(
            weekStart: weekStart,
            recipeService: recipeService,
            groceryService: groceryService
        )
        let result = try XCTUnwrap(copyResult)

        XCTAssertEqual(result.copied, 2, "household onto day 0, Maya onto day 1")
        XCTAssertEqual(result.skippedFilled, 2, "Maya's day-0 slot and the household day-1 slot")
        XCTAssertEqual(result.failed, 0)

        // Day 0: Maya keeps her curry; household tacos copied in.
        let day0 = targetRows(dateISO: iso(weekStart))
        XCTAssertEqual(day0.count, 2)
        XCTAssertEqual(recipeID(of: day0.first { self.memberID(of: $0) == maya.uuidString.lowercased() }),
                       curryID.uuidString.lowercased(),
                       "Maya's existing meal is kept, never overwritten")
        XCTAssertEqual(recipeID(of: day0.first { self.memberID(of: $0) == nil }),
                       tacosID.uuidString.lowercased())

        // Day 1: household keeps its soup; Maya's pasta copied in.
        let day1 = targetRows(dateISO: iso(day(1, from: weekStart)))
        XCTAssertEqual(day1.count, 2)
        XCTAssertEqual(recipeID(of: day1.first { self.memberID(of: $0) == nil }),
                       soupID.uuidString.lowercased(),
                       "the household's existing meal is kept")
        XCTAssertEqual(recipeID(of: day1.first { self.memberID(of: $0) == maya.uuidString.lowercased() }),
                       pastaID.uuidString.lowercased())
    }

    /// Past target days are skipped silently — tallied as skippedPast,
    /// never attempted (the assign path would refuse them with an
    /// error). Using weekStart = 3 days ago makes exactly 3 of the 7
    /// targets past, whatever today's weekday is.
    @MainActor
    func testCopySkipsPastDaysSilently() async throws {
        let mealPlanService = MealPlanService()
        let groceryService = GroceryService()
        let recipeService = RecipeService()

        let tacosID = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Tacos")
        let maya = UUID()

        let weekStart = day(-3, from: Calendar.current.startOfDay(for: Date()))
        // Source week fully planned: a household meal every day, plus
        // Maya's meal on the first (past-targeting) day.
        for offset in 0..<7 {
            TestFixtures.seedMealPlan(
                householdID: Self.householdID, recipeID: tacosID,
                memberID: nil, dateISO: iso(day(offset - 7, from: weekStart)))
        }
        TestFixtures.seedMealPlan(
            householdID: Self.householdID, recipeID: tacosID,
            memberID: maya, dateISO: iso(day(-7, from: weekStart)))

        let copyResult = await mealPlanService.copyPreviousWeek(
            weekStart: weekStart,
            recipeService: recipeService,
            groceryService: groceryService
        )
        let result = try XCTUnwrap(copyResult)

        XCTAssertEqual(result.copied, 4, "today + 3 future days")
        XCTAssertEqual(result.skippedPast, 4,
                       "3 past household meals + Maya's meal on a past day")
        XCTAssertEqual(result.failed, 0)
        XCTAssertNil(mealPlanService.errorMessage, "past skips are silent")

        // Nothing landed on the past days.
        for offset in 0..<3 {
            XCTAssertTrue(targetRows(dateISO: iso(day(offset, from: weekStart))).isEmpty)
        }
    }

    /// An empty previous week reports sourceEmpty (drives the
    /// "Last week was empty." toast).
    @MainActor
    func testCopyReportsEmptySourceWeek() async throws {
        let mealPlanService = MealPlanService()

        let copyResult = await mealPlanService.copyPreviousWeek(
            weekStart: Calendar.current.startOfDay(for: Date()),
            recipeService: RecipeService(),
            groceryService: GroceryService()
        )
        let result = try XCTUnwrap(copyResult)

        XCTAssertTrue(result.sourceEmpty)
        XCTAssertEqual(result.copied, 0)
    }
}
