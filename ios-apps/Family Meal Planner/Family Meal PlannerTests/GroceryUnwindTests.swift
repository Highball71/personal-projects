//
//  GroceryUnwindTests.swift
//  Family Meal PlannerTests
//
//  Regression tests for the grocery-unwind bug: removing a meal from
//  the week view stranded its grocery items, because the week view's
//  removal path (clearDayWithGroceries) deleted the meal_plans rows
//  FIRST and only then tried to read grocery_contributions — but the
//  DB cascades contributions away on meal_plans delete (migration
//  005), so the unwind found zero rows and "succeeded" while the
//  grocery list kept everything.
//
//  These tests run the REAL MealPlanService/GroceryService code
//  against an in-memory fake PostgREST backend that faithfully
//  emulates the ON DELETE CASCADE. The fake is installed as a
//  URLProtocol on URLSession.shared — the session the Supabase SDK
//  uses — so no test traffic can ever reach a real server.
//

import XCTest
@testable import Family_Meal_Planner

// MARK: - In-memory fake PostgREST backend

/// Holds fake tables as arrays of JSON dictionaries and answers
/// PostgREST-style requests (a small subset: select=*, eq/in/gte/lt
/// filters, insert, update, delete). Deleting meal_plans or
/// grocery_items rows cascades grocery_contributions, mirroring
/// migrations 005's foreign keys — the behavior under test.
final class FakePostgRESTStore: @unchecked Sendable {
    static let shared = FakePostgRESTStore()

    private let lock = NSLock()
    private var tables: [String: [[String: Any]]] = [:]

    /// Table names whose GET requests should fail with HTTP 500.
    /// Used to test that a failed contribution snapshot aborts the
    /// meal delete instead of stranding groceries.
    var failGETTables: Set<String> = []

    /// Table names whose DELETE requests silently affect zero rows —
    /// exactly what PostgREST does when RLS hides the target rows:
    /// HTTP success, empty representation, nothing deleted. Used to
    /// test that removal paths VERIFY their deletes instead of
    /// reporting success.
    var rlsDeleteBlockedTables: Set<String> = []

    func reset() {
        lock.lock(); defer { lock.unlock() }
        tables = ["meal_plans": [], "grocery_items": [], "grocery_contributions": []]
        failGETTables = []
        rlsDeleteBlockedTables = []
    }

    func rows(in table: String) -> [[String: Any]] {
        lock.lock(); defer { lock.unlock() }
        return tables[table] ?? []
    }

    /// Seed rows directly, bypassing the request path — for test
    /// fixtures the app itself can't create (e.g. an account member
    /// row, which in production only sign-up flows insert).
    func seed(table: String, rows newRows: [[String: Any]]) {
        lock.lock(); defer { lock.unlock() }
        tables[table, default: []].append(contentsOf: newRows)
    }

    // MARK: Request handling

    func handle(_ request: URLRequest, body: Data?) -> (status: Int, body: Data) {
        guard let url = request.url,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return (400, Data("{}".utf8)) }

        // Anything that isn't a PostgREST call (auth refresh, storage,
        // …) gets a 404 so it fails fast without touching the network.
        let pathParts = comps.path.split(separator: "/").map(String.init)
        guard pathParts.count >= 3, pathParts[0] == "rest", pathParts[1] == "v1" else {
            return (404, Data("{}".utf8))
        }
        let table = pathParts[2]
        let queryItems = comps.queryItems ?? []
        let filters = Self.filters(from: queryItems)
        let wantsRepresentation = queryItems.contains { $0.name == "select" }
        let method = request.httpMethod?.uppercased() ?? "GET"

        lock.lock(); defer { lock.unlock() }
        var all = tables[table] ?? []

        switch method {
        case "GET":
            if failGETTables.contains(table) {
                return (500, Data(#"{"message":"injected failure"}"#.utf8))
            }
            let matched = all.filter { Self.matches($0, filters) }
            return (200, Self.encode(matched))

        case "POST":
            guard let body, let parsed = try? JSONSerialization.jsonObject(with: body) else {
                return (400, Data("{}".utf8))
            }
            let incoming: [[String: Any]]
            if let array = parsed as? [[String: Any]] {
                incoming = array
            } else if let object = parsed as? [String: Any] {
                incoming = [object]
            } else {
                return (400, Data("{}".utf8))
            }
            var inserted: [[String: Any]] = []
            for var row in incoming {
                if row["id"] == nil { row["id"] = UUID().uuidString.lowercased() }
                if row["created_at"] == nil { row["created_at"] = "2026-08-28T00:00:00.000000+00:00" }
                if table == "grocery_items", row["is_checked"] == nil { row["is_checked"] = false }
                inserted.append(row)
            }
            all.append(contentsOf: inserted)
            tables[table] = all
            return (201, Self.encode(inserted))

        case "PATCH":
            guard let body, let patch = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else {
                return (400, Data("{}".utf8))
            }
            var updated: [[String: Any]] = []
            for index in all.indices where Self.matches(all[index], filters) {
                for (key, value) in patch { all[index][key] = value }
                updated.append(all[index])
            }
            tables[table] = all
            // Like real PostgREST: return the updated rows when the
            // caller asked for a representation (select=...).
            return wantsRepresentation ? (200, Self.encode(updated)) : (204, Data())

        case "DELETE":
            if rlsDeleteBlockedTables.contains(table) {
                return wantsRepresentation ? (200, Self.encode([])) : (204, Data())
            }
            let deleted = all.filter { Self.matches($0, filters) }
            all.removeAll { Self.matches($0, filters) }
            tables[table] = all
            cascadeLocked(from: table, deletedRows: deleted)
            return wantsRepresentation ? (200, Self.encode(deleted)) : (204, Data())

        default:
            return (405, Data("{}".utf8))
        }
    }

    /// Emulate migration 005's ON DELETE CASCADE foreign keys
    /// (grocery_contributions vanish when their meal_plan or
    /// grocery_item row is deleted) and migration 013's BEFORE DELETE
    /// trigger on household_members (deleting a member NULLs
    /// meal_plans.member_id for their meals — they become household
    /// meals instead of orphans).
    private func cascadeLocked(from table: String, deletedRows: [[String: Any]]) {
        let deletedIDs = Set(deletedRows.compactMap { ($0["id"] as? String)?.lowercased() })
        guard !deletedIDs.isEmpty else { return }

        if table == "household_members" {
            guard var plans = tables["meal_plans"] else { return }
            for index in plans.indices {
                if let ref = (plans[index]["member_id"] as? String)?.lowercased(),
                   deletedIDs.contains(ref) {
                    plans[index]["member_id"] = nil
                }
            }
            tables["meal_plans"] = plans
            return
        }

        let column: String
        switch table {
        case "meal_plans": column = "meal_plan_id"
        case "grocery_items": column = "grocery_item_id"
        default: return
        }
        tables["grocery_contributions"]?.removeAll { contribution in
            guard let ref = (contribution[column] as? String)?.lowercased() else { return false }
            return deletedIDs.contains(ref)
        }
    }

    // MARK: Filter parsing/matching

    private struct Filter {
        let column: String
        let op: String
        let value: String
    }

    private static func filters(from queryItems: [URLQueryItem]) -> [Filter] {
        let nonFilterKeys: Set<String> = ["select", "order", "limit", "offset", "on_conflict", "columns"]
        return queryItems.compactMap { item in
            guard !nonFilterKeys.contains(item.name), let value = item.value,
                  let dot = value.firstIndex(of: ".")
            else { return nil }
            return Filter(
                column: item.name,
                op: String(value[..<dot]),
                value: String(value[value.index(after: dot)...])
            )
        }
    }

    private static func matches(_ row: [String: Any], _ filters: [Filter]) -> Bool {
        for filter in filters {
            // NULL check first — "is.null" matches a missing key or an
            // explicit NSNull, mirroring PostgREST's member_id=is.null.
            if filter.op == "is", filter.value.lowercased() == "null" {
                let value = row[filter.column]
                if value == nil || value is NSNull { continue }
                return false
            }
            // Stringify for comparison; lowercase both sides because the
            // SDK sends uppercase UUIDs while the store generates lowercase.
            let rowValue = row[filter.column].map { "\($0)" }?.lowercased() ?? ""
            switch filter.op {
            case "eq":
                if rowValue != filter.value.lowercased() { return false }
            case "in":
                let values = filter.value
                    .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"")).lowercased() }
                if !values.contains(rowValue) { return false }
            case "gte":
                if rowValue < filter.value.lowercased() { return false }
            case "lt":
                if rowValue >= filter.value.lowercased() { return false }
            default:
                return false
            }
        }
        return true
    }

    private static func encode(_ rows: [[String: Any]]) -> Data {
        (try? JSONSerialization.data(withJSONObject: rows)) ?? Data("[]".utf8)
    }
}

/// URLProtocol that claims EVERY request while registered, so nothing
/// the app fires during a test can reach a real backend. Requests are
/// answered from FakePostgRESTStore.
final class FakePostgRESTProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // Bodies arrive as a stream under URLProtocol, not httpBody.
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll)
        let (status, data) = FakePostgRESTStore.shared.handle(request, body: body)
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
              )
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    // nonisolated: pure stream draining, passed to `map` (a
    // nonisolated context) — same treatment as SeasonalMatch's string
    // helpers under the project's default MainActor isolation.
    private nonisolated static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

// MARK: - Tests

final class GroceryUnwindTests: XCTestCase {

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

    /// Plan a meal that contributes groceries: flour merges into a
    /// pre-existing manual item (2 + 2 cups), butter is created fresh.
    /// Returns the meal plan's ID.
    @MainActor
    private func seedPlannedMeal(
        on date: Date,
        mealPlanService: MealPlanService,
        groceryService: GroceryService
    ) async throws -> UUID {
        let manualAdded = await groceryService.addItems([
            GroceryItemInsert(householdID: Self.householdID, name: "flour", quantity: 2, unit: "cups")
        ])
        XCTAssertTrue(manualAdded, "manual grocery add should succeed")

        let insertedPlanID = await mealPlanService.addMeal(recipeID: UUID(), on: date)
        let planID = try XCTUnwrap(insertedPlanID, "meal plan insert should succeed")
        let contributed = await groceryService.addItemsForMealPlan(mealPlanID: planID, items: [
            GroceryItemInsert(householdID: Self.householdID, name: "flour", quantity: 2, unit: "cups"),
            GroceryItemInsert(householdID: Self.householdID, name: "butter", quantity: 1, unit: "lb"),
        ])
        XCTAssertTrue(contributed, "meal grocery contribution should succeed")

        // Sanity: flour merged to 4 cups, butter present, 2 contribution rows.
        let flour = try XCTUnwrap(groceryService.items.first { $0.name == "flour" })
        XCTAssertEqual(flour.quantity, 4, accuracy: 0.0001)
        XCTAssertNotNil(groceryService.items.first { $0.name == "butter" })
        XCTAssertEqual(FakePostgRESTStore.shared.rows(in: "grocery_contributions").count, 2)

        return planID
    }

    /// THE regression test. Removing a meal via clearDayWithGroceries —
    /// the week view's only removal path — must settle the grocery
    /// list even though the DB cascade destroys the contribution rows
    /// the instant the meal_plans rows are deleted.
    ///
    /// Against the pre-fix code this fails: the unwind ran after the
    /// delete, found zero contributions, and flour stayed at 4 cups
    /// with butter still on the list.
    @MainActor
    func testWeekViewRemovalSettlesGroceryItems() async throws {
        let mealPlanService = MealPlanService()
        let groceryService = GroceryService()
        let date = Date()

        _ = try await seedPlannedMeal(on: date, mealPlanService: mealPlanService, groceryService: groceryService)

        let cleared = await mealPlanService.clearDayWithGroceries(on: date, groceryService: groceryService)
        XCTAssertTrue(cleared, "clearDayWithGroceries should report success")

        XCTAssertTrue(FakePostgRESTStore.shared.rows(in: "meal_plans").isEmpty, "meal plan row should be deleted")

        // The meal's contributions must be unwound: flour back down to
        // the manual 2 cups, butter (entirely meal-contributed) gone.
        let flour = try XCTUnwrap(groceryService.items.first { $0.name == "flour" }, "manual flour must survive")
        XCTAssertEqual(flour.quantity, 2, accuracy: 0.0001, "flour should drop back to the manually-added 2 cups")
        XCTAssertNil(groceryService.items.first { $0.name == "butter" }, "butter came only from the meal and should be removed")
        XCTAssertTrue(FakePostgRESTStore.shared.rows(in: "grocery_contributions").isEmpty)
    }

    /// The other live removal path — removeMeal, unwind-first — must
    /// keep working after the refactor onto the shared settle core.
    @MainActor
    func testRemoveMealStillSettlesGroceryItems() async throws {
        let mealPlanService = MealPlanService()
        let groceryService = GroceryService()
        let date = Date()

        let planID = try await seedPlannedMeal(on: date, mealPlanService: mealPlanService, groceryService: groceryService)

        let removed = await mealPlanService.removeMeal(planID, groceryService: groceryService)
        XCTAssertTrue(removed)

        XCTAssertTrue(FakePostgRESTStore.shared.rows(in: "meal_plans").isEmpty)
        let flour = try XCTUnwrap(groceryService.items.first { $0.name == "flour" })
        XCTAssertEqual(flour.quantity, 2, accuracy: 0.0001)
        XCTAssertNil(groceryService.items.first { $0.name == "butter" })
        XCTAssertTrue(FakePostgRESTStore.shared.rows(in: "grocery_contributions").isEmpty)
    }

    /// If the contribution snapshot can't be read, the delete must be
    /// aborted while the meal still exists — deleting anyway would
    /// strand grocery items that could never be settled afterwards.
    @MainActor
    func testSnapshotFailureAbortsMealDelete() async throws {
        let mealPlanService = MealPlanService()
        let groceryService = GroceryService()
        let date = Date()

        _ = try await seedPlannedMeal(on: date, mealPlanService: mealPlanService, groceryService: groceryService)

        FakePostgRESTStore.shared.failGETTables = ["grocery_contributions"]
        let cleared = await mealPlanService.clearDayWithGroceries(on: date, groceryService: groceryService)
        FakePostgRESTStore.shared.failGETTables = []

        XCTAssertFalse(cleared, "clear must fail when the snapshot can't be taken")
        XCTAssertEqual(FakePostgRESTStore.shared.rows(in: "meal_plans").count, 1, "meal plan must NOT be deleted")
        XCTAssertEqual(FakePostgRESTStore.shared.rows(in: "grocery_contributions").count, 2, "contributions must be intact")
        XCTAssertNotNil(mealPlanService.errorMessage)
    }
}
