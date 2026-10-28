//
//  ReliabilityPassTests.swift
//  Family Meal PlannerTests
//
//  The 2026-10-28 reliability pass on the hybrid redesign. Each test
//  pins one real-world failure the read-only review found:
//
//    - "Connects with this week" ranking (WeekOverlap.picks, lifted
//      out of the picker view so it can be tested)
//    - prefetchPlans: replaces its whole window (clears emptied dates)
//      and drops results that a newer loud fetch has overtaken
//    - the rolling next-week window survives the quiet reconcile that
//      follows an add or remove
//    - grocery refresh: retries once after a blip; a cancelled refresh
//      never sends the retry; refresh failure is its own state
//    - SignedURLCache: reuse until ten minutes before expiry
//    - FamilyPhotoService.add truncates captions to the DB limit
//
//  Service tests run the REAL services against the in-memory fake
//  PostgREST backend from GroceryUnwindTests.swift.
//

import XCTest
@testable import Family_Meal_Planner

final class ReliabilityPassTests: XCTestCase {

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

    // MARK: - overlapPicks (WeekOverlap.picks)

    /// More shared perishables lead; ties are alphabetical, case-blind.
    func testPicksRankByOverlapCountThenName() throws {
        let zucchini = try TestFixtures.recipeRow(householdID: Self.householdID, name: "Zucchini Bake")
        let apple = try TestFixtures.recipeRow(householdID: Self.householdID, name: "apple slaw")
        let bean = try TestFixtures.recipeRow(householdID: Self.householdID, name: "Bean Tacos")
        let overlaps: [UUID: [String]] = [
            zucchini.id: ["cabbage", "cilantro"],
            apple.id: ["cabbage"],
            bean.id: ["cilantro"],
        ]

        let picks = WeekOverlap.picks(from: [bean, apple, zucchini], overlaps: overlaps)

        XCTAssertEqual(picks.map(\.name), ["Zucchini Bake", "apple slaw", "Bean Tacos"])
    }

    /// Only recipes with an overlap appear; the "Your pick" recipe is
    /// excluded; at most picksCap come back.
    func testPicksExcludeNonOverlapsAndPreselectedAndCap() throws {
        let recipes = try (0..<8).map {
            try TestFixtures.recipeRow(householdID: Self.householdID, name: "Recipe \($0)")
        }
        let noOverlap = try TestFixtures.recipeRow(householdID: Self.householdID, name: "Plain Rice")
        var overlaps: [UUID: [String]] = [:]
        for recipe in recipes { overlaps[recipe.id] = ["cabbage"] }
        let preselected = recipes[0]

        let picks = WeekOverlap.picks(
            from: recipes + [noOverlap],
            overlaps: overlaps,
            excluding: preselected.id
        )

        XCTAssertEqual(picks.count, WeekOverlap.picksCap)
        XCTAssertFalse(picks.contains { $0.id == preselected.id }, "Your pick sits on top already")
        XCTAssertFalse(picks.contains { $0.id == noOverlap.id })
        XCTAssertEqual(picks.map(\.name), ["Recipe 1", "Recipe 2", "Recipe 3", "Recipe 4", "Recipe 5"])
    }

    func testPicksEmptyWithoutOverlaps() throws {
        let recipe = try TestFixtures.recipeRow(householdID: Self.householdID, name: "Soup")
        XCTAssertTrue(WeekOverlap.picks(from: [recipe], overlaps: [:]).isEmpty)
    }

    // MARK: - prefetchPlans

    /// Prefetch merges its window without touching the displayed week,
    /// and a later prefetch clears a date whose meal is gone.
    @MainActor
    func testPrefetchMergesWindowAndClearsEmptiedDates() async throws {
        let service = MealPlanService()
        let recipeID = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Tacos")
        let nextWeek = day(7, from: today)
        _ = TestFixtures.seedMealPlan(householdID: Self.householdID, recipeID: recipeID,
                                      memberID: nil, dateISO: iso(today))
        let futurePlanID = TestFixtures.seedMealPlan(householdID: Self.householdID, recipeID: recipeID,
                                                     memberID: nil, dateISO: iso(day(2, from: nextWeek)))

        await service.fetchPlans(weekStart: today)
        let prefetched = await service.prefetchPlans(startDate: nextWeek, dayCount: 7)

        XCTAssertTrue(prefetched)
        XCTAssertEqual(service.plansByDate[iso(today)]?.count, 1, "displayed week untouched")
        XCTAssertEqual(service.plansByDate[iso(day(2, from: nextWeek))]?.first?.id, futurePlanID)

        // Someone else removes the future meal; the next prefetch must
        // clear that date, not leave the stale row behind.
        let other = MealPlanService()
        let removed = await other.removeMeal(futurePlanID, groceryService: GroceryService())
        XCTAssertTrue(removed)
        let again = await service.prefetchPlans(startDate: nextWeek, dayCount: 7)

        XCTAssertTrue(again)
        XCTAssertNil(service.plansByDate[iso(day(2, from: nextWeek))],
                     "a date that came back empty is cleared")
        XCTAssertEqual(service.plansByDate[iso(today)]?.count, 1)
    }

    /// The generation guard: a loud fetch (week navigation) that starts
    /// while a prefetch is in flight wins — the late prefetch result
    /// belongs to the old week's window and is dropped.
    @MainActor
    func testPrefetchDroppedWhenLoudFetchStartsMeanwhile() async throws {
        let service = MealPlanService()
        let recipeID = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Tacos")
        let nextWeek = day(7, from: today)
        _ = TestFixtures.seedMealPlan(householdID: Self.householdID, recipeID: recipeID,
                                      memberID: nil, dateISO: iso(day(1, from: nextWeek)))

        // Start the prefetch and let it reach its network await…
        let prefetch = Task { await service.prefetchPlans(startDate: nextWeek, dayCount: 7) }
        await Task.yield()
        // …then navigate: a loud fetch of a different week begins.
        let lastWeek = day(-7, from: today)
        let loaded = await service.fetchPlans(weekStart: lastWeek)
        let prefetched = await prefetch.value

        XCTAssertTrue(loaded)
        XCTAssertFalse(prefetched, "an overtaken prefetch reports it was dropped")
        XCTAssertNil(service.plansByDate[iso(day(1, from: nextWeek))],
                     "the stale window never lands on the new week")
    }

    /// A QUIET reconcile is not navigation: a prefetch in flight around
    /// one still lands.
    @MainActor
    func testPrefetchSurvivesQuietReconcileMeanwhile() async throws {
        let service = MealPlanService()
        let recipeID = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Tacos")
        let nextWeek = day(7, from: today)
        _ = TestFixtures.seedMealPlan(householdID: Self.householdID, recipeID: recipeID,
                                      memberID: nil, dateISO: iso(day(1, from: nextWeek)))
        await service.fetchPlans(weekStart: today)

        let prefetch = Task { await service.prefetchPlans(startDate: nextWeek, dayCount: 7) }
        await Task.yield()
        await service.fetchPlans(weekStart: today, quiet: true)
        let prefetched = await prefetch.value

        XCTAssertTrue(prefetched)
        XCTAssertEqual(service.plansByDate[iso(day(1, from: nextWeek))]?.count, 1)
    }

    // MARK: - Rolling window survives add/remove

    /// The bug: after an add or remove, the quiet reconcile replaced
    /// plansByDate with only the displayed week, so next week's
    /// prefetched days vanished and "Connects with this week" shrank
    /// for a late-week pick. Quiet reconciles now merge.
    @MainActor
    func testRollingWindowSurvivesAddAndRemoveReconciles() async throws {
        let service = MealPlanService()
        let groceries = GroceryService()
        let recipeID = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Tacos")
        let nextWeek = day(7, from: today)
        let nextWeekISO = iso(day(1, from: nextWeek))
        _ = TestFixtures.seedMealPlan(householdID: Self.householdID, recipeID: recipeID,
                                      memberID: nil, dateISO: nextWeekISO)

        // What reloadWeek does: loud fetch, then prefetch next week.
        await service.fetchPlans(weekStart: today)
        await service.prefetchPlans(startDate: nextWeek, dayCount: 7)
        XCTAssertEqual(service.plansByDate[nextWeekISO]?.count, 1)

        // Add a meal this week, then the quiet reconcile.
        let added = await service.addMeal(recipeID: recipeID, on: day(3, from: today))
        let newPlanID = try XCTUnwrap(added)
        await service.fetchPlans(weekStart: today, quiet: true)

        XCTAssertEqual(service.plansByDate[iso(day(3, from: today))]?.first?.id, newPlanID,
                       "the reconcile picked up the new meal")
        XCTAssertEqual(service.plansByDate[nextWeekISO]?.count, 1,
                       "next week's prefetched day survived the add reconcile")

        // Remove it again (optimistic local edit + server delete), then reconcile.
        _ = service.removeLocalPlan(newPlanID, dateISO: iso(day(3, from: today)))
        let removed = await service.removeMeal(newPlanID, groceryService: groceries)
        XCTAssertTrue(removed)
        await service.fetchPlans(weekStart: today, quiet: true)

        XCTAssertNil(service.plansByDate[iso(day(3, from: today))])
        XCTAssertEqual(service.plansByDate[nextWeekISO]?.count, 1,
                       "next week's prefetched day survived the remove reconcile")

        // A LOUD fetch (navigation / pull-to-refresh) still replaces
        // wholesale — reloadWeek re-runs the prefetch after it.
        await service.fetchPlans(weekStart: today)
        XCTAssertNil(service.plansByDate[nextWeekISO])
    }

    // MARK: - Grocery refresh

    private func groceryInsert(_ name: String) -> GroceryItemInsert {
        GroceryItemInsert(householdID: Self.householdID, name: name, quantity: 1, unit: "")
    }

    /// One failed GET (a connection blip) then success: the retry
    /// recovers, nothing is reported as failed, and exactly two
    /// requests went out.
    @MainActor
    func testGroceryRefreshFailsOnceThenSucceedsOnRetry() async throws {
        let service = GroceryService()
        let added = await service.addItems([groceryInsert("lemons")])
        XCTAssertTrue(added)

        // A write error from earlier must not be read as, or cleared
        // by, the refresh — they're separate states now.
        service.errorMessage = "Couldn't check that item."
        FakePostgRESTStore.shared.failNextGETs = ["grocery_items": 1]
        let before = FakePostgRESTStore.shared.getCount(for: "grocery_items")

        let ok = await service.fetchItems()

        XCTAssertTrue(ok)
        XCTAssertNil(service.refreshError, "a refresh that recovered on retry is not a failure")
        XCTAssertEqual(service.items.map(\.name), ["lemons"])
        XCTAssertEqual(FakePostgRESTStore.shared.getCount(for: "grocery_items") - before, 2,
                       "first attempt failed, retry succeeded")
        XCTAssertEqual(service.errorMessage, "Couldn't check that item.",
                       "a refresh never touches the write error")
        XCTAssertFalse(service.isLoading)
    }

    /// Cancelled while sleeping before its retry, a refresh must give
    /// up — no second request, and no failure reported.
    @MainActor
    func testCancelledRefreshNeverSendsRetry() async throws {
        let service = GroceryService()
        FakePostgRESTStore.shared.failGETTables = ["grocery_items"]

        let refresh = Task { await service.fetchItems() }
        // Wait for the first (failing) attempt to go out.
        for _ in 0..<200 where FakePostgRESTStore.shared.getCount(for: "grocery_items") == 0 {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertEqual(FakePostgRESTStore.shared.getCount(for: "grocery_items"), 1)

        refresh.cancel()
        let ok = await refresh.value
        // Longer than the 350 ms retry delay.
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertFalse(ok)
        XCTAssertEqual(FakePostgRESTStore.shared.getCount(for: "grocery_items"), 1,
                       "a cancelled refresh never sends the retry")
        XCTAssertNil(service.refreshError, "cancellation is not a fetch failure")
    }

    /// Both attempts failing IS a refresh failure — reported through
    /// refreshError, not the write-error channel.
    @MainActor
    func testRefreshFailureUsesItsOwnState() async throws {
        let service = GroceryService()
        FakePostgRESTStore.shared.failGETTables = ["grocery_items"]

        let ok = await service.fetchItems()

        XCTAssertFalse(ok)
        XCTAssertNotNil(service.refreshError)
        XCTAssertNil(service.errorMessage)
        XCTAssertEqual(FakePostgRESTStore.shared.getCount(for: "grocery_items"), 2)
    }

    // MARK: - Signed URL cache

    /// A clock tests can move by hand.
    private final class TestClock {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
    }

    @MainActor
    func testSignedURLReusedUntilTenMinutesBeforeExpiry() async throws {
        let clock = TestClock()
        let cache = SignedURLCache(now: { clock.now })
        var signCount = 0
        func sign(_ expiresIn: Int) async throws -> URL {
            XCTAssertEqual(expiresIn, 3600)
            signCount += 1
            return URL(string: "https://example.test/signed/\(signCount)")!
        }

        let first = try await cache.url(bucket: "family", path: "a.jpg", sign: sign)
        XCTAssertEqual(signCount, 1)

        // Scrolling back to it 30 minutes later: same URL, no request.
        clock.now += 30 * 60
        let reused = try await cache.url(bucket: "family", path: "a.jpg", sign: sign)
        XCTAssertEqual(reused, first)
        XCTAssertEqual(signCount, 1)

        // Just inside the margin (49m59s): still reused.
        clock.now += 19 * 60 + 59
        _ = try await cache.url(bucket: "family", path: "a.jpg", sign: sign)
        XCTAssertEqual(signCount, 1)

        // Ten minutes before expiry: re-sign.
        clock.now += 1
        let refreshed = try await cache.url(bucket: "family", path: "a.jpg", sign: sign)
        XCTAssertEqual(signCount, 2)
        XCTAssertNotEqual(refreshed, first)

        // Keyed by bucket AND path.
        _ = try await cache.url(bucket: "family", path: "b.jpg", sign: sign)
        _ = try await cache.url(bucket: "cookbook", path: "a.jpg", sign: sign)
        XCTAssertEqual(signCount, 4)
    }

    @MainActor
    func testSignedURLFailureIsNotCachedAndRemoveAllClears() async throws {
        let cache = SignedURLCache()
        struct SignFailed: Error {}
        var signCount = 0

        do {
            _ = try await cache.url(bucket: "family", path: "a.jpg") { _ in
                signCount += 1
                throw SignFailed()
            }
            XCTFail("a failed sign must throw")
        } catch {}

        let url = try await cache.url(bucket: "family", path: "a.jpg") { _ in
            signCount += 1
            return URL(string: "https://example.test/ok")!
        }
        XCTAssertEqual(url.absoluteString, "https://example.test/ok")
        XCTAssertEqual(signCount, 2, "the failure wasn't cached; the next view retried")

        cache.removeAll()
        _ = try await cache.url(bucket: "family", path: "a.jpg") { _ in
            signCount += 1
            return URL(string: "https://example.test/again")!
        }
        XCTAssertEqual(signCount, 3)
    }

    // MARK: - Caption truncation

    @MainActor
    func testAddTruncatesCaptionToDatabaseLimit() async throws {
        let id = TestFixtures.seedRecipe(householdID: Self.householdID, name: "Soup")
        let recipes = RecipeService()
        await recipes.fetchRecipes()
        let recipe = try XCTUnwrap(recipes.recipes.first { $0.id == id })
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in }
        let service = FamilyPhotoService()

        try await service.add(image, caption: String(repeating: "a", count: 2500), to: recipe)

        let photos = try await service.photos(for: recipe)
        XCTAssertEqual(photos.first?.caption.count, 2000)
    }

    /// Postgres length() counts code points. A family emoji is one
    /// Character but five code points, so a prefix(2000) of them would
    /// still be rejected; the helper keeps whole emoji under the limit.
    @MainActor
    func testCaptionTruncationCountsCodePoints() {
        let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}"
        let truncated = FamilyPhotoService.truncatedCaption(String(repeating: family, count: 500))

        XCTAssertEqual(truncated.unicodeScalars.count, 2000)
        XCTAssertEqual(truncated.count, 400, "whole emoji only — none split")

        let short = "Grandma's version"
        let same = FamilyPhotoService.truncatedCaption(short)
        XCTAssertEqual(same, short)
    }

    // MARK: - Category display

    func testCategoryDisplayIsCaseInsensitiveAndCapitalized() throws {
        func recipe(_ category: String) throws -> RecipeRow {
            try TestFixtures.decodeRow([
                "id": UUID().uuidString,
                "household_id": Self.householdID.uuidString,
                "name": "Test",
                "category": category,
                "created_at": 0.0,
            ])
        }
        XCTAssertEqual(try recipe("dinner").categoryDisplayName, "Dinner")
        XCTAssertEqual(try recipe("Dinner").categoryDisplayName, "Dinner")
        XCTAssertEqual(try recipe("side dish").categoryDisplayName, "Side Dish")
        XCTAssertEqual(try recipe("brunch").categoryDisplayName, "Brunch", "unknown values stay themselves")
        XCTAssertEqual(try recipe("breakfast").recipeCategory, .breakfast,
                       "lowercase no longer falls through to Dinner")
    }
}
