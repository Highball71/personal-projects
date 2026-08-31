//
//  SlotSemanticsTests.swift
//  Family Meal PlannerTests
//
//  Per-person meals Phase 3: the slot key is (date, member_id).
//  Assigning a household meal must replace only the household slot;
//  assigning a member's meal must replace only that member's slot;
//  clearing a day must remove EVERY meal on it and settle grocery
//  contributions for all of them (the snapshot-before-delete unwind
//  from the 110 bug, now covering multiple meals per day); and
//  deleting a member must leave their meals behind as household meals
//  (the 013 trigger NULLs member_id — emulated by the fake store).
//
//  Runs the REAL services against the in-memory fake PostgREST
//  backend from GroceryUnwindTests.swift.
//

import XCTest
@testable import Family_Meal_Planner

final class SlotSemanticsTests: XCTestCase {

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

    /// Recipes fetched through the real service so assign calls get
    /// real RecipeRow values (decoded via the SDK path).
    @MainActor
    private func loadRecipes(_ recipeService: RecipeService) async throws -> [RecipeRow] {
        let ok = await recipeService.fetchRecipes()
        XCTAssertTrue(ok, "fetchRecipes against the fake store should succeed")
        return recipeService.recipes
    }

    /// Assign through the real single write path and assert success.
    @MainActor
    private func assign(
        _ recipe: RecipeRow,
        on date: Date,
        member: UUID? = nil,
        mealPlanService: MealPlanService,
        recipeService: RecipeService,
        groceryService: GroceryService,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let newID = await mealPlanService.addMealWithGroceries(
            recipe: recipe, on: date, memberID: member,
            recipeService: recipeService, groceryService: groceryService
        )
        XCTAssertNotNil(newID, "assigning \(recipe.name) should succeed", file: file, line: line)
    }

    private func mealRows() -> [[String: Any]] {
        FakePostgRESTStore.shared.rows(in: "meal_plans")
    }

    /// UUID columns arrive uppercase from the SDK's inserts and
    /// lowercase from seeded fixtures — compare lowercased.
    private func memberID(of row: [String: Any]?) -> String? {
        (row?["member_id"] as? String)?.lowercased()
    }

    private func recipeID(of row: [String: Any]?) -> String? {
        (row?["recipe_id"] as? String)?.lowercased()
    }

    // MARK: - Slot-scoped assignment

    /// Assigning a household meal replaces ONLY the household slot:
    /// the member's meal (and its groceries) survive untouched, and
    /// the replaced household meal's groceries are settled.
    @MainActor
    func testHouseholdAssignReplacesOnlyHouseholdSlot() async throws {
        let mealPlanService = MealPlanService()
        let groceryService = GroceryService()
        let recipeService = RecipeService()
        let householdService = HouseholdService()

        TestFixtures.seedRecipe(householdID: Self.householdID, name: "Pasta",
                                ingredients: [("spaghetti", 1, "lb")])
        TestFixtures.seedRecipe(householdID: Self.householdID, name: "Tacos",
                                ingredients: [("tortillas", 8, "piece")])
        TestFixtures.seedRecipe(householdID: Self.householdID, name: "Curry",
                                ingredients: [("rice", 2, "cups")])
        let recipes = try await loadRecipes(recipeService)
        let pasta = try XCTUnwrap(recipes.first { $0.name == "Pasta" })
        let tacos = try XCTUnwrap(recipes.first { $0.name == "Tacos" })
        let curry = try XCTUnwrap(recipes.first { $0.name == "Curry" })

        _ = await householdService.createProfileMember(name: "Maya", dietaryPreferences: [])
        let maya = try XCTUnwrap(householdService.members.first { $0.displayName == "Maya" })

        let date = Date()
        // Maya gets the pasta; the household gets tacos.
        await assign(pasta, on: date, member: maya.id,
                     mealPlanService: mealPlanService, recipeService: recipeService, groceryService: groceryService)
        await assign(tacos, on: date,
                     mealPlanService: mealPlanService, recipeService: recipeService, groceryService: groceryService)
        XCTAssertEqual(mealRows().count, 2)

        // Replace the household meal with curry.
        await assign(curry, on: date,
                     mealPlanService: mealPlanService, recipeService: recipeService, groceryService: groceryService)

        let rows = mealRows()
        XCTAssertEqual(rows.count, 2, "one household row + Maya's row")
        let householdRows = rows.filter { memberID(of: $0) == nil }
        XCTAssertEqual(householdRows.count, 1, "household slot holds exactly one meal")
        XCTAssertEqual(recipeID(of: householdRows.first),
                       curry.id.uuidString.lowercased())
        let mayaRows = rows.filter { memberID(of: $0) == maya.id.uuidString.lowercased() }
        XCTAssertEqual(mayaRows.count, 1, "Maya's meal must survive the household replace")
        XCTAssertEqual(recipeID(of: mayaRows.first),
                       pasta.id.uuidString.lowercased())

        // Groceries: tacos' tortillas settled away, pasta + curry intact.
        XCTAssertNil(groceryService.items.first { $0.name == "tortillas" },
                     "the replaced household meal's groceries must be settled")
        XCTAssertNotNil(groceryService.items.first { $0.name == "spaghetti" })
        XCTAssertNotNil(groceryService.items.first { $0.name == "rice" })
    }

    /// Assigning a member's meal replaces only that member's slot —
    /// the household meal and other members' meals are untouched, and
    /// one person never holds two meals on a day.
    @MainActor
    func testMemberAssignReplacesOnlyThatMembersSlot() async throws {
        let mealPlanService = MealPlanService()
        let groceryService = GroceryService()
        let recipeService = RecipeService()
        let householdService = HouseholdService()

        TestFixtures.seedRecipe(householdID: Self.householdID, name: "Pasta",
                                ingredients: [("spaghetti", 1, "lb")])
        TestFixtures.seedRecipe(householdID: Self.householdID, name: "Tacos",
                                ingredients: [("tortillas", 8, "piece")])
        TestFixtures.seedRecipe(householdID: Self.householdID, name: "Curry",
                                ingredients: [("rice", 2, "cups")])
        TestFixtures.seedRecipe(householdID: Self.householdID, name: "Soup",
                                ingredients: [("broth", 4, "cups")])
        let recipes = try await loadRecipes(recipeService)
        let pasta = try XCTUnwrap(recipes.first { $0.name == "Pasta" })
        let tacos = try XCTUnwrap(recipes.first { $0.name == "Tacos" })
        let curry = try XCTUnwrap(recipes.first { $0.name == "Curry" })
        let soup = try XCTUnwrap(recipes.first { $0.name == "Soup" })

        _ = await householdService.createProfileMember(name: "Maya", dietaryPreferences: [])
        _ = await householdService.createProfileMember(name: "Sam", dietaryPreferences: [])
        let maya = try XCTUnwrap(householdService.members.first { $0.displayName == "Maya" })
        let sam = try XCTUnwrap(householdService.members.first { $0.displayName == "Sam" })

        let date = Date()
        await assign(tacos, on: date,
                     mealPlanService: mealPlanService, recipeService: recipeService, groceryService: groceryService)
        await assign(pasta, on: date, member: maya.id,
                     mealPlanService: mealPlanService, recipeService: recipeService, groceryService: groceryService)
        await assign(curry, on: date, member: sam.id,
                     mealPlanService: mealPlanService, recipeService: recipeService, groceryService: groceryService)
        XCTAssertEqual(mealRows().count, 3)

        // Maya changes her mind: soup instead of pasta.
        await assign(soup, on: date, member: maya.id,
                     mealPlanService: mealPlanService, recipeService: recipeService, groceryService: groceryService)

        let rows = mealRows()
        XCTAssertEqual(rows.count, 3, "household + Maya + Sam — never two meals for one person")
        let mayaRows = rows.filter { memberID(of: $0) == maya.id.uuidString.lowercased() }
        XCTAssertEqual(mayaRows.count, 1, "one meal per (day, member)")
        XCTAssertEqual(recipeID(of: mayaRows.first),
                       soup.id.uuidString.lowercased())
        XCTAssertEqual(recipeID(of: rows.first { self.memberID(of: $0) == nil }),
                       tacos.id.uuidString.lowercased(),
                       "the household meal is untouched")
        XCTAssertEqual(recipeID(of: rows.first { self.memberID(of: $0) == sam.id.uuidString.lowercased() }),
                       curry.id.uuidString.lowercased(),
                       "Sam's meal is untouched")

        // Pasta's groceries settled; everything else intact.
        XCTAssertNil(groceryService.items.first { $0.name == "spaghetti" })
        XCTAssertNotNil(groceryService.items.first { $0.name == "tortillas" })
        XCTAssertNotNil(groceryService.items.first { $0.name == "rice" })
        XCTAssertNotNil(groceryService.items.first { $0.name == "broth" })
    }

    // MARK: - Clear day with multiple meals

    /// clearDayWithGroceries now removes MULTIPLE meals per day, and
    /// its snapshot-before-delete grocery unwind must settle the
    /// contributions of ALL of them — the 110 grocery-strand bug must
    /// not come back in multi-meal form. A manually-added grocery item
    /// survives at its manual quantity.
    @MainActor
    func testClearDayRemovesAllMealsAndSettlesAllGroceries() async throws {
        let mealPlanService = MealPlanService()
        let groceryService = GroceryService()
        let recipeService = RecipeService()
        let householdService = HouseholdService()

        TestFixtures.seedRecipe(householdID: Self.householdID, name: "Pasta",
                                ingredients: [("flour", 2, "cups")])
        TestFixtures.seedRecipe(householdID: Self.householdID, name: "Tacos",
                                ingredients: [("tortillas", 8, "piece")])
        TestFixtures.seedRecipe(householdID: Self.householdID, name: "Curry",
                                ingredients: [("rice", 2, "cups")])
        let recipes = try await loadRecipes(recipeService)
        let pasta = try XCTUnwrap(recipes.first { $0.name == "Pasta" })
        let tacos = try XCTUnwrap(recipes.first { $0.name == "Tacos" })
        let curry = try XCTUnwrap(recipes.first { $0.name == "Curry" })

        _ = await householdService.createProfileMember(name: "Maya", dietaryPreferences: [])
        _ = await householdService.createProfileMember(name: "Sam", dietaryPreferences: [])
        let maya = try XCTUnwrap(householdService.members.first { $0.displayName == "Maya" })
        let sam = try XCTUnwrap(householdService.members.first { $0.displayName == "Sam" })

        // Manual flour on the list; pasta's meal-contributed flour
        // merges on top of it (2 + 2 cups).
        let manualAdded = await groceryService.addItems([
            GroceryItemInsert(householdID: Self.householdID, name: "flour", quantity: 2, unit: "cups")
        ])
        XCTAssertTrue(manualAdded)

        let date = Date()
        await assign(pasta, on: date,
                     mealPlanService: mealPlanService, recipeService: recipeService, groceryService: groceryService)
        await assign(tacos, on: date, member: maya.id,
                     mealPlanService: mealPlanService, recipeService: recipeService, groceryService: groceryService)
        await assign(curry, on: date, member: sam.id,
                     mealPlanService: mealPlanService, recipeService: recipeService, groceryService: groceryService)

        XCTAssertEqual(mealRows().count, 3)
        XCTAssertEqual(FakePostgRESTStore.shared.rows(in: "grocery_contributions").count, 3)
        let mergedFlour = try XCTUnwrap(groceryService.items.first { $0.name == "flour" })
        XCTAssertEqual(mergedFlour.quantity, 4, accuracy: 0.0001)

        let cleared = await mealPlanService.clearDayWithGroceries(on: date, groceryService: groceryService)
        XCTAssertTrue(cleared)

        XCTAssertTrue(mealRows().isEmpty, "every meal on the day must be removed")
        XCTAssertTrue(FakePostgRESTStore.shared.rows(in: "grocery_contributions").isEmpty)
        XCTAssertNil(groceryService.items.first { $0.name == "tortillas" })
        XCTAssertNil(groceryService.items.first { $0.name == "rice" })
        let flour = try XCTUnwrap(groceryService.items.first { $0.name == "flour" },
                                  "manually-added flour must survive")
        XCTAssertEqual(flour.quantity, 2, accuracy: 0.0001,
                       "flour settles back to the manual 2 cups")
    }

    // MARK: - Member deletion

    /// Deleting a profile member NULLs their meals' member_id (the
    /// 013 trigger, emulated by the fake store) — the meal survives
    /// and renders as a household meal.
    @MainActor
    func testDeletedMemberMealsBecomeHouseholdMeals() async throws {
        let mealPlanService = MealPlanService()
        let groceryService = GroceryService()
        let recipeService = RecipeService()
        let householdService = HouseholdService()

        TestFixtures.seedRecipe(householdID: Self.householdID, name: "Pasta",
                                ingredients: [("spaghetti", 1, "lb")])
        let recipes = try await loadRecipes(recipeService)
        let pasta = try XCTUnwrap(recipes.first { $0.name == "Pasta" })

        _ = await householdService.createProfileMember(name: "Maya", dietaryPreferences: [])
        let maya = try XCTUnwrap(householdService.members.first { $0.displayName == "Maya" })

        let date = Date()
        await assign(pasta, on: date, member: maya.id,
                     mealPlanService: mealPlanService, recipeService: recipeService, groceryService: groceryService)

        let deleted = await householdService.deleteProfileMember(maya.id)
        XCTAssertTrue(deleted)

        // The meal row survives with member_id NULLed.
        let rows = mealRows()
        XCTAssertEqual(rows.count, 1, "the meal must not be deleted with the member")
        XCTAssertNil(memberID(of: rows.first), "member_id must be NULLed by the trigger")

        // And through the real fetch + grouping path it renders as a
        // household meal.
        let fetched = await mealPlanService.fetchPlans(weekStart: Calendar.current.startOfDay(for: date))
        XCTAssertTrue(fetched)
        let dayRows = mealPlanService.plansByDate[MealPlanService.isoDate(from: date)] ?? []
        XCTAssertEqual(dayRows.count, 1)
        let dayPlan = DayPlan.build(from: dayRows, members: householdService.members)
        XCTAssertEqual(dayPlan.householdMeals.count, 1)
        XCTAssertTrue(dayPlan.memberMeals.isEmpty)
    }

    // MARK: - DayPlan grouping (pure)

    /// Household meal first, member meals in members-list order —
    /// regardless of row order.
    func testDayPlanGroupsAndOrdersMemberMeals() throws {
        let householdID = UUID()
        let maya = try TestFixtures.member(householdID: householdID, name: "Maya")
        let sam = try TestFixtures.member(householdID: householdID, name: "Sam")

        let samRow = try TestFixtures.mealPlanRow(
            householdID: householdID, recipeID: UUID(), memberID: sam.id, date: "2026-08-31")
        let householdRow = try TestFixtures.mealPlanRow(
            householdID: householdID, recipeID: UUID(), memberID: nil, date: "2026-08-31")
        let mayaRow = try TestFixtures.mealPlanRow(
            householdID: householdID, recipeID: UUID(), memberID: maya.id, date: "2026-08-31")

        let plan = DayPlan.build(from: [samRow, householdRow, mayaRow], members: [maya, sam])
        XCTAssertEqual(plan.householdMeals, [householdRow])
        XCTAssertEqual(plan.memberMeals.map(\.member.id), [maya.id, sam.id],
                       "member meals follow the members list order")
        XCTAssertEqual(plan.mealCount, 3)
    }

    /// A meal whose member_id doesn't match any loaded member (the
    /// stale-cache window right after a delete on another device)
    /// renders as a household meal, never disappears.
    func testDayPlanUnknownMemberRendersAsHousehold() throws {
        let householdID = UUID()
        let maya = try TestFixtures.member(householdID: householdID, name: "Maya")
        let orphanRow = try TestFixtures.mealPlanRow(
            householdID: householdID, recipeID: UUID(), memberID: UUID(), date: "2026-08-31")

        let plan = DayPlan.build(from: [orphanRow], members: [maya])
        XCTAssertEqual(plan.householdMeals, [orphanRow])
        XCTAssertTrue(plan.memberMeals.isEmpty)
    }

    /// Rows orphaned by a recipe delete (recipe_id NULL) are dropped,
    /// matching the week view's existing filter.
    func testDayPlanDropsRowsWithoutRecipe() throws {
        let householdID = UUID()
        let noRecipe = try TestFixtures.mealPlanRow(
            householdID: householdID, recipeID: nil, memberID: nil, date: "2026-08-31")

        let plan = DayPlan.build(from: [noRecipe], members: [])
        XCTAssertTrue(plan.isEmpty)
    }
}
