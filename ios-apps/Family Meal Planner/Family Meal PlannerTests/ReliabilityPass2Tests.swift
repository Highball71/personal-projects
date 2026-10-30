//
//  ReliabilityPass2Tests.swift
//  Family Meal PlannerTests
//
//  The 2026-10-29 device pass on `reliability-pass`. Each test pins one
//  failure David hit on his iPhone:
//
//    - "Connects with this week" lost next week after an add or a
//      swipe-remove. The 2026-10-28 test called service primitives in
//      the order we BELIEVED the screen used (bare addMeal, a raw
//      quiet fetch) and checked plansByDate. These drive the methods
//      the screens actually call — loadPlanner, planMeal, unplanMeal,
//      unplanDay — and check what the picker computes from them.
//    - Offline grocery refresh was silent: no banner, ever.
//    - The Recipes "Chicken" chip listed ribs (chicken broth).
//    - "750 min".
//  (The meals-not-dinners summary line lives in WeekSummaryTests.)
//
//  Service tests run the REAL services against the in-memory fake
//  PostgREST backend from GroceryUnwindTests.swift.
//

import XCTest
@testable import Family_Meal_Planner

final class ReliabilityPass2Tests: XCTestCase {

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

    private func day(_ offset: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: date)!
    }

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    // MARK: - "Connects with this week" through the real path

    /// David's repro, as data: Thursday's picker sees next Sunday's
    /// steak salad (cilantro-lime mayo) through the rolling window.
    private struct ConnectsFixture {
        let weekStart: Date
        let thursday: Date
        let friday: Date
        let saturday: Date
        let burgerBowls: UUID
        let enchiladas: UUID
        let pastaID: UUID
    }

    /// Seeds the repro. The displayed week is NEXT week — Sunday-
    /// anchored like the Meals screen — so every day is in the future
    /// and planMeal's past-date guard never blocks.
    private func seedConnectsFixture() -> ConnectsFixture {
        let weekStart = DateHelper.startOfWeek(containing: day(7, from: today))
        let h = Self.householdID
        let salad = TestFixtures.seedRecipe(householdID: h, name: "Steak Salad with Cilantro-Lime Mayo", ingredients: [
            ("flank steak", 1, "lb"), ("cilantro", 1, "bunch"), ("lime", 2, ""),
            ("avocado", 1, ""), ("cherry tomatoes", 1, "pint"),
        ])
        let tacos = TestFixtures.seedRecipe(householdID: h, name: "Beef Tacos", ingredients: [
            ("ground beef", 1, "lb"), ("onion", 1, ""),
        ])
        let burgerBowls = TestFixtures.seedRecipe(householdID: h, name: "Lemon Garlic Burger Bowls", ingredients: [
            ("avocado", 1, ""), ("ground beef", 1, "lb"), ("tomato", 2, ""),
        ])
        let enchiladas = TestFixtures.seedRecipe(householdID: h, name: "Enchiladas", ingredients: [
            ("ground beef", 1, "lb"), ("cilantro", 1, "bunch"), ("tortillas", 8, ""),
        ])
        let pasta = TestFixtures.seedRecipe(householdID: h, name: "Pasta Primavera", ingredients: [
            ("penne", 1, "lb"), ("zucchini", 2, ""),
        ])
        // Thursday this week: tacos. Sunday after: the steak salad,
        // which only the rolling window reaches.
        TestFixtures.seedMealPlan(householdID: h, recipeID: tacos, memberID: nil,
                                  dateISO: iso(day(4, from: weekStart)))
        TestFixtures.seedMealPlan(householdID: h, recipeID: salad, memberID: nil,
                                  dateISO: iso(day(7, from: weekStart)))
        return ConnectsFixture(
            weekStart: weekStart,
            thursday: day(4, from: weekStart),
            friday: day(5, from: weekStart),
            saturday: day(6, from: weekStart),
            burgerBowls: burgerBowls,
            enchiladas: enchiladas,
            pastaID: pasta
        )
    }

    /// Exactly what Thursday's picker computes: the planner's rolling
    /// window from the day being planned, fed to WeekOverlap with the
    /// recipe service's ingredient map (SupabaseMealPlanView passes
    /// these straight into RecipePickerSheet).
    @MainActor
    private func pickerOverlaps(
        on date: Date,
        plans: MealPlanService,
        recipes: RecipeService
    ) -> [UUID: [String]] {
        WeekOverlap.overlaps(
            weekRecipeIDs: plans.plannedRecipeIDs(from: date),
            ingredientsByRecipeID: recipes.ingredientsByRecipeID,
            candidates: recipes.recipes
        )
    }

    @MainActor
    private func assertConnectsIntact(
        _ fx: ConnectsFixture,
        plans: MealPlanService,
        recipes: RecipeService,
        after step: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let overlaps = pickerOverlaps(on: fx.thursday, plans: plans, recipes: recipes)
        XCTAssertEqual(overlaps[fx.burgerBowls], ["avocado", "beef", "tomato"],
                       "Burger Bowls still connects \(step)", file: file, line: line)
        XCTAssertEqual(overlaps[fx.enchiladas], ["beef", "cilantro"],
                       "Enchiladas keeps cilantro (next Sunday) \(step)", file: file, line: line)
    }

    /// The device failure, end to end: open the planner, add a meal on
    /// Friday, swipe it away, clear a day — Thursday's picker keeps next
    /// Sunday's connections after every step.
    @MainActor
    func testConnectsWithThisWeekSurvivesEditsThroughTheRealPath() async throws {
        let fx = seedConnectsFixture()
        let plans = MealPlanService()
        let recipes = RecipeService()
        let groceries = GroceryService()

        // The Meals screen's .task: reloadWeek → loadPlanner, then recipes.
        let loaded = await plans.loadPlanner(weekStart: fx.weekStart)
        XCTAssertTrue(loaded)
        await recipes.fetchRecipes()
        assertConnectsIntact(fx, plans: plans, recipes: recipes, after: "on first load")

        // "+" on Friday → pick Pasta Primavera (the screen's addMeal).
        let pasta = try XCTUnwrap(recipes.recipes.first { $0.id == fx.pastaID })
        let added = await plans.planMeal(pasta, on: fx.friday,
                                         recipeService: recipes, groceryService: groceries)
        let fridayPlanID = try XCTUnwrap(added, plans.errorMessage ?? "planMeal failed")
        XCTAssertEqual(plans.plansByDate[iso(fx.friday)]?.first?.id, fridayPlanID)
        assertConnectsIntact(fx, plans: plans, recipes: recipes, after: "adding a meal on Friday")

        // Swipe-remove Friday's meal (the screen's removeMeal).
        let removed = await plans.unplanMeal(fridayPlanID, on: fx.friday, groceryService: groceries)
        XCTAssertTrue(removed)
        XCTAssertNil(plans.plansByDate[iso(fx.friday)])
        assertConnectsIntact(fx, plans: plans, recipes: recipes, after: "a swipe-remove")

        // Plan Saturday, then "Clear the Whole Day".
        let saturdayPlan = await plans.planMeal(pasta, on: fx.saturday,
                                                recipeService: recipes, groceryService: groceries)
        XCTAssertNotNil(saturdayPlan)
        let cleared = await plans.unplanDay(fx.saturday, groceryService: groceries)
        XCTAssertTrue(cleared)
        assertConnectsIntact(fx, plans: plans, recipes: recipes, after: "clearing a day")
    }

    /// Whatever dropped the window before an edit — recipe detail used
    /// to plan with a loud seven-day reload of the date's week, which
    /// replaced the planner wholesale — the edit's reconcile restores
    /// it. Before, only navigating away and back did.
    @MainActor
    func testEditRestoresWindowDroppedByALoudWeekReload() async throws {
        let fx = seedConnectsFixture()
        let plans = MealPlanService()
        let recipes = RecipeService()
        await plans.loadPlanner(weekStart: fx.weekStart)
        await recipes.fetchRecipes()

        // The old recipe-detail path: a loud fetch of just the week.
        await plans.fetchPlans(weekStart: fx.weekStart)
        let shrunk = pickerOverlaps(on: fx.thursday, plans: plans, recipes: recipes)
        XCTAssertEqual(shrunk[fx.enchiladas], ["beef"], "the old failure, reproduced")
        XCTAssertEqual(shrunk[fx.burgerBowls], ["beef"])

        let pasta = try XCTUnwrap(recipes.recipes.first { $0.id == fx.pastaID })
        let added = await plans.planMeal(pasta, on: fx.friday,
                                         recipeService: recipes, groceryService: GroceryService())
        XCTAssertNotNil(added)
        assertConnectsIntact(fx, plans: plans, recipes: recipes, after: "the next edit's reconcile")
    }

    /// Planning from the Recipes tab or recipe detail (the same
    /// planMeal) reconciles the week ON SCREEN — before, it loudly
    /// loaded the picked date's week, so planning next week from
    /// recipe detail replaced the displayed week's rows.
    @MainActor
    func testPlanningFromRecipeScreensKeepsTheDisplayedWeek() async throws {
        let fx = seedConnectsFixture()
        let plans = MealPlanService()
        let recipes = RecipeService()
        await plans.loadPlanner(weekStart: fx.weekStart)
        await recipes.fetchRecipes()
        let thursdayISO = iso(fx.thursday)
        XCTAssertEqual(plans.plansByDate[thursdayISO]?.count, 1)

        let pasta = try XCTUnwrap(recipes.recipes.first { $0.id == fx.pastaID })
        let nextTuesday = day(9, from: fx.weekStart)
        let added = await plans.planMeal(pasta, on: nextTuesday,
                                         recipeService: recipes, groceryService: GroceryService())

        XCTAssertNotNil(added)
        XCTAssertEqual(plans.plannerWeekStart, fx.weekStart)
        XCTAssertEqual(plans.plansByDate[thursdayISO]?.count, 1, "the displayed week stays loaded")
        XCTAssertEqual(plans.plansByDate[iso(nextTuesday)]?.count, 1, "the new meal is in the window")
    }

    /// Before the Meals screen has ever loaded there's nothing to
    /// reconcile — and no request is sent.
    @MainActor
    func testReconcileBeforePlannerLoadIsANoOp() async throws {
        let plans = MealPlanService()
        let ok = await plans.reconcilePlanner()
        XCTAssertTrue(ok)
        XCTAssertNil(plans.plannerWeekStart)
        XCTAssertEqual(FakePostgRESTStore.shared.getCount(for: "meal_plans"), 0)
    }

    /// A failed remove puts the row back and leaves the window alone.
    @MainActor
    func testFailedUnplanRestoresTheRow() async throws {
        let fx = seedConnectsFixture()
        let plans = MealPlanService()
        let recipes = RecipeService()
        await plans.loadPlanner(weekStart: fx.weekStart)
        await recipes.fetchRecipes()
        let thursdayISO = iso(fx.thursday)
        let before = plans.plansByDate[thursdayISO]
        let planID = try XCTUnwrap(before?.first?.id)

        // The contribution snapshot can't be read → removeMeal aborts.
        FakePostgRESTStore.shared.failGETTables = ["grocery_contributions"]
        let removed = await plans.unplanMeal(planID, on: fx.thursday, groceryService: GroceryService())

        XCTAssertFalse(removed)
        XCTAssertEqual(plans.plansByDate[thursdayISO], before)
        assertConnectsIntact(fx, plans: plans, recipes: recipes, after: "a failed remove")
    }

    // MARK: - Offline grocery refresh

    private func groceryInsert(_ name: String) -> GroceryItemInsert {
        GroceryItemInsert(householdID: Self.householdID, name: name, quantity: 1, unit: "")
    }

    /// Airplane mode: the request fails with no HTTP response. The
    /// refresh reports it — promptly, after our one retry and none of
    /// the SDK's (which added ~14 s of silent spinner) — and keeps the
    /// last saved list on screen.
    @MainActor
    func testOfflineRefreshReportsFailurePromptlyAndKeepsList() async throws {
        let service = GroceryService()
        let added = await service.addItems([groceryInsert("lemons")])
        XCTAssertTrue(added)
        await service.refresh()
        XCTAssertEqual(service.items.map(\.name), ["lemons"])

        FakePostgRESTStore.shared.offlineGETTables = ["grocery_items"]
        let before = FakePostgRESTStore.shared.getCount(for: "grocery_items")
        let started = Date()

        let ok = await service.refresh()

        XCTAssertFalse(ok)
        XCTAssertNotNil(service.refreshError, "the banner's state is set")
        XCTAssertEqual(service.items.map(\.name), ["lemons"], "last saved list kept")
        XCTAssertEqual(FakePostgRESTStore.shared.getCount(for: "grocery_items") - before, 2,
                       "our first attempt and one retry — no SDK retries")
        XCTAssertLessThan(Date().timeIntervalSince(started), 3, "no long silent spinner")
        XCTAssertFalse(service.isLoading)
    }

    /// The silent-banner bug itself: SwiftUI cancels the pull-to-refresh
    /// task mid-refresh. refresh() must still finish and report the
    /// failure — a cancelled fetchItems is (correctly) silent, so the
    /// request must not inherit the caller's cancellation.
    @MainActor
    func testRefreshStillReportsWhenTheCallerIsCancelled() async throws {
        let service = GroceryService()
        FakePostgRESTStore.shared.offlineGETTables = ["grocery_items"]

        let pullToRefresh = Task { await service.refresh() }
        pullToRefresh.cancel()
        let ok = await pullToRefresh.value

        XCTAssertFalse(ok)
        XCTAssertNotNil(service.refreshError,
                        "a cancelled pull-to-refresh still surfaces the offline failure")
        XCTAssertEqual(FakePostgRESTStore.shared.getCount(for: "grocery_items"), 2,
                       "the retry still ran")
    }

    // MARK: - Browse chips mean the main protein

    @MainActor
    private func recipe(_ name: String) throws -> RecipeRow {
        try TestFixtures.recipeRow(householdID: Self.householdID, name: name)
    }

    @MainActor
    private func tags(_ name: String, _ ingredients: [String]) throws -> Set<BrowseTag> {
        let row = try recipe(name)
        return Set(BrowseTag.allCases.filter { $0 != .all && $0.matches(row, ingredientNames: ingredients) })
    }

    /// The device report: ribs and pork lettuce wraps under "Chicken"
    /// because of chicken broth/stock.
    @MainActor
    func testChickenChipIgnoresBrothStockAndBouillon() throws {
        XCTAssertFalse(try tags("Baby Back Ribs", ["baby back ribs", "chicken broth", "bbq sauce"]).contains(.chicken))
        XCTAssertFalse(try tags("Slow-Cooker Pork Lettuce Wraps", ["pork shoulder", "chicken stock", "butter lettuce"]).contains(.chicken))
        XCTAssertFalse(try tags("Mushroom Risotto", ["arborio rice", "Better Than Bouillon chicken base"]).contains(.chicken))
        XCTAssertFalse(try tags("Roast Turkey", ["turkey", "poultry seasoning"]).contains(.chicken))

        XCTAssertTrue(try tags("Lemon Chicken", ["lemon"]).contains(.chicken), "title")
        XCTAssertTrue(try tags("Sheet Pan Dinner", ["bone-in chicken thighs", "chicken broth"]).contains(.chicken),
                      "an ingredient that IS chicken")
    }

    @MainActor
    func testPorkChipNamesPorkOnly() throws {
        XCTAssertTrue(try tags("Baby Back Ribs", ["baby back ribs"]).contains(.pork))
        XCTAssertTrue(try tags("Slow-Cooker Pork Lettuce Wraps", ["pork shoulder"]).contains(.pork))
        XCTAssertTrue(try tags("Split Pea Soup", ["ham hock", "split peas"]).contains(.pork))
        XCTAssertFalse(try tags("Classic Hamburgers", ["ground beef", "hamburger buns"]).contains(.pork),
                       "\"ham\" is a whole word")
        XCTAssertFalse(try tags("Pie Crust", ["graham crackers", "butter"]).contains(.pork))
    }

    @MainActor
    func testFishChipSkipsSeasoningsAndLookalikes() throws {
        XCTAssertFalse(try tags("Pad Thai", ["rice noodles", "fish sauce", "eggs"]).contains(.fish))
        XCTAssertFalse(try tags("Caesar Salad", ["romaine", "anchovy paste"]).contains(.fish))
        XCTAssertFalse(try tags("Scalloped Potatoes", ["potatoes", "cream"]).contains(.fish))
        XCTAssertTrue(try tags("Honey Garlic Salmon", []).contains(.fish))
        XCTAssertTrue(try tags("Weeknight Tacos", ["shrimp", "limes"]).contains(.fish))
    }

    /// Soups go by title — broth and chili powder are in everything.
    @MainActor
    func testSoupsChipGoesByTitle() throws {
        XCTAssertTrue(try tags("Beef Stew", ["beef chuck"]).contains(.soups))
        XCTAssertTrue(try tags("White Chicken Chili", ["chicken", "white beans"]).contains(.soups))
        XCTAssertFalse(try tags("Braised Short Ribs", ["short ribs", "beef broth"]).contains(.soups))
        XCTAssertFalse(try tags("Chili-Lime Chicken", ["chicken", "chili powder"]).contains(.soups))
        XCTAssertFalse(try tags("Sweet Chili Shrimp", ["shrimp"]).contains(.soups))
    }

    @MainActor
    func testVegetarianAndPastaChips() throws {
        // Vegetarian still sees broth — it does make a dish not vegetarian.
        XCTAssertFalse(try tags("Mushroom Risotto", ["arborio rice", "chicken broth"]).contains(.vegetarian))
        XCTAssertFalse(try tags("Baby Back Ribs", ["baby back ribs"]).contains(.vegetarian))
        XCTAssertTrue(try tags("Minestrone", ["celery ribs", "carrots", "vegetable broth"]).contains(.vegetarian),
                      "celery ribs are not meat")
        XCTAssertTrue(try tags("S'mores Bars", ["graham crackers", "chocolate"]).contains(.vegetarian))

        XCTAssertTrue(try tags("Beef Stroganoff", ["egg noodles", "beef"]).contains(.pasta))
        XCTAssertFalse(try tags("Shakshuka", ["eggs", "tomato paste"]).contains(.pasta))
    }

    // MARK: - Total time reads in hours

    func testTotalTimeFormatsHoursAndMinutes() {
        XCTAssertEqual(DurationText.totalTime(minutes: 45), "45 min")
        XCTAssertEqual(DurationText.totalTime(minutes: 59), "59 min")
        XCTAssertEqual(DurationText.totalTime(minutes: 60), "1 hr")
        XCTAssertEqual(DurationText.totalTime(minutes: 75), "1 hr 15 min")
        XCTAssertEqual(DurationText.totalTime(minutes: 120), "2 hr")
        XCTAssertEqual(DurationText.totalTime(minutes: 750), "12 hr 30 min", "the device report")
    }
}
