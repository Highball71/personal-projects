//
//  MemberCRUDTests.swift
//  Family Meal PlannerTests
//
//  Per-person meals Phase 2: profile-member CRUD on HouseholdService
//  and the one-time migration of device-local dietary preferences
//  (@AppStorage "dietaryPreferences") onto the signed-in user's
//  member row.
//
//  Uses the same in-memory fake PostgREST backend as
//  GroceryUnwindTests (URLProtocol on URLSession.shared — no test
//  traffic can reach a real server).
//

import XCTest
@testable import Family_Meal_Planner

final class MemberCRUDTests: XCTestCase {

    private static let householdID = UUID()
    private static let myUserID = UUID()

    /// The real key HouseholdService migrates; saved/restored around
    /// each test so the suite never leaks into the simulator's defaults.
    private let prefsKey = HouseholdService.legacyDietaryPrefsKey
    private var savedPrefsValue: String?

    override func setUp() async throws {
        savedPrefsValue = UserDefaults.standard.string(forKey: prefsKey)
        UserDefaults.standard.removeObject(forKey: prefsKey)
        FakePostgRESTStore.shared.reset()
        URLProtocol.registerClass(FakePostgRESTProtocol.self)
        await MainActor.run {
            SupabaseManager.shared.setCurrentHousehold(Self.householdID)
            SupabaseManager.shared.setCurrentUser(Self.myUserID)
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            SupabaseManager.shared.setCurrentHousehold(nil)
            SupabaseManager.shared.setCurrentUser(nil)
        }
        URLProtocol.unregisterClass(FakePostgRESTProtocol.self)
        FakePostgRESTStore.shared.reset()
        if let savedPrefsValue {
            UserDefaults.standard.set(savedPrefsValue, forKey: prefsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: prefsKey)
        }
    }

    // MARK: - Fixtures

    /// Seed the signed-in user's own (account) member row, as the
    /// create-household flow would have inserted it.
    private func seedMyMemberRow(dietaryPreferences: [String] = []) -> String {
        let id = UUID().uuidString.lowercased()
        FakePostgRESTStore.shared.seed(table: "household_members", rows: [[
            "id": id,
            "household_id": Self.householdID.uuidString.lowercased(),
            "user_id": Self.myUserID.uuidString.lowercased(),
            "display_name": "David",
            "is_head_cook": true,
            "dietary_preferences": dietaryPreferences,
        ]])
        return id
    }

    // MARK: - Profile member CRUD

    /// Creating a profile member must store a row with NO user_id (the
    /// nil is omitted so the column takes its NULL default) and the
    /// chosen dietary preferences, and refresh the members list.
    @MainActor
    func testCreateProfileMemberStoresNullUserID() async throws {
        let service = HouseholdService()

        let created = await service.createProfileMember(
            name: "  Maya  ",
            dietaryPreferences: ["Nut-Free", "Vegetarian"]
        )
        XCTAssertTrue(created, "profile-member insert should succeed")

        let rows = FakePostgRESTStore.shared.rows(in: "household_members")
        XCTAssertEqual(rows.count, 1)
        let row = try XCTUnwrap(rows.first)
        XCTAssertNil(row["user_id"], "profile members must have no user_id")
        XCTAssertEqual(row["display_name"] as? String, "Maya", "name should be trimmed")
        XCTAssertEqual(row["dietary_preferences"] as? [String], ["Nut-Free", "Vegetarian"])
        XCTAssertEqual(row["is_head_cook"] as? Bool, false)

        let member = try XCTUnwrap(service.members.first { $0.displayName == "Maya" },
                                   "members list should refresh after create")
        XCTAssertTrue(member.isProfileMember)
        XCTAssertEqual(member.dietaryPreferences, ["Nut-Free", "Vegetarian"])
    }

    /// A blank name is rejected before any network call.
    @MainActor
    func testCreateProfileMemberRejectsBlankName() async throws {
        let service = HouseholdService()
        let created = await service.createProfileMember(name: "   ", dietaryPreferences: [])
        XCTAssertFalse(created)
        XCTAssertTrue(FakePostgRESTStore.shared.rows(in: "household_members").isEmpty)
        XCTAssertNotNil(service.errorMessage)
    }

    /// Renaming and changing preferences persists and refreshes.
    @MainActor
    func testUpdateProfileMemberPersistsNameAndPrefs() async throws {
        let service = HouseholdService()
        _ = await service.createProfileMember(name: "Maya", dietaryPreferences: [])
        let member = try XCTUnwrap(service.members.first { $0.displayName == "Maya" })

        let updated = await service.updateMember(
            member.id,
            displayName: "Maya R.",
            dietaryPreferences: ["Dairy-Free"]
        )
        XCTAssertTrue(updated)

        let row = try XCTUnwrap(FakePostgRESTStore.shared.rows(in: "household_members").first)
        XCTAssertEqual(row["display_name"] as? String, "Maya R.")
        XCTAssertEqual(row["dietary_preferences"] as? [String], ["Dairy-Free"])

        let refreshed = try XCTUnwrap(service.members.first { $0.id == member.id })
        XCTAssertEqual(refreshed.displayName, "Maya R.")
        XCTAssertEqual(refreshed.dietaryPreferences, ["Dairy-Free"])
    }

    /// Deleting a profile member removes the row and refreshes.
    @MainActor
    func testDeleteProfileMemberRemovesRow() async throws {
        let service = HouseholdService()
        _ = await service.createProfileMember(name: "Maya", dietaryPreferences: [])
        let member = try XCTUnwrap(service.members.first { $0.displayName == "Maya" })

        let deleted = await service.deleteProfileMember(member.id)
        XCTAssertTrue(deleted)
        XCTAssertTrue(FakePostgRESTStore.shared.rows(in: "household_members").isEmpty)
        XCTAssertTrue(service.members.isEmpty)
    }

    /// Account members are never deletable from the People screen —
    /// they leave from their own device (and RLS enforces the same).
    @MainActor
    func testDeleteAccountMemberIsRefused() async throws {
        _ = seedMyMemberRow()
        let service = HouseholdService()
        await service.loadMembers()
        let me = try XCTUnwrap(service.members.first { $0.userID == Self.myUserID })
        XCTAssertFalse(me.isProfileMember)

        let deleted = await service.deleteProfileMember(me.id)
        XCTAssertFalse(deleted)
        XCTAssertEqual(FakePostgRESTStore.shared.rows(in: "household_members").count, 1,
                       "the account member row must be untouched")
        XCTAssertNotNil(service.errorMessage)
    }

    // MARK: - Dietary prefs migration

    /// The happy path: a non-empty local key and an empty member-row
    /// array — the prefs are pushed up (unknown tokens dropped, sorted)
    /// and the key is cleared.
    @MainActor
    func testMigrationPushesLocalPrefsToMemberRow() async throws {
        _ = seedMyMemberRow(dietaryPreferences: [])
        UserDefaults.standard.set("Vegetarian,Nut-Free,NotARealDiet", forKey: prefsKey)

        let service = HouseholdService()
        await service.loadMembers()
        await service.migrateLocalDietaryPreferencesIfNeeded()

        let row = try XCTUnwrap(FakePostgRESTStore.shared.rows(in: "household_members").first)
        XCTAssertEqual(row["dietary_preferences"] as? [String], ["Nut-Free", "Vegetarian"],
                       "prefs should be pushed up, unknown values dropped, sorted")
        XCTAssertNil(UserDefaults.standard.string(forKey: prefsKey),
                     "the local key must be cleared after a successful push")

        let me = try XCTUnwrap(service.members.first { $0.userID == Self.myUserID })
        XCTAssertEqual(me.dietaryPreferences, ["Nut-Free", "Vegetarian"])
    }

    /// If the member row already has preferences (set from another
    /// device, or an earlier migration), the server wins: the row is
    /// untouched and the stale local copy is discarded.
    @MainActor
    func testMigrationServerWinsOverStaleLocalPrefs() async throws {
        _ = seedMyMemberRow(dietaryPreferences: ["Vegan"])
        UserDefaults.standard.set("Nut-Free", forKey: prefsKey)

        let service = HouseholdService()
        await service.loadMembers()
        await service.migrateLocalDietaryPreferencesIfNeeded()

        let row = try XCTUnwrap(FakePostgRESTStore.shared.rows(in: "household_members").first)
        XCTAssertEqual(row["dietary_preferences"] as? [String], ["Vegan"],
                       "an already-populated row must not be overwritten")
        XCTAssertNil(UserDefaults.standard.string(forKey: prefsKey),
                     "the stale local copy is discarded")
    }

    /// Without a member row for the signed-in user (e.g. mid-onboarding)
    /// the key must survive so a later launch can retry.
    @MainActor
    func testMigrationWithoutMemberRowKeepsKey() async throws {
        UserDefaults.standard.set("Vegetarian", forKey: prefsKey)

        let service = HouseholdService()
        await service.loadMembers()
        await service.migrateLocalDietaryPreferencesIfNeeded()

        XCTAssertEqual(UserDefaults.standard.string(forKey: prefsKey), "Vegetarian",
                       "no member row yet — keep the key and retry later")
    }

    /// An empty key is a no-op — no writes, no network dependency.
    @MainActor
    func testMigrationNoOpWhenKeyEmpty() async throws {
        let id = seedMyMemberRow(dietaryPreferences: [])

        let service = HouseholdService()
        await service.loadMembers()
        await service.migrateLocalDietaryPreferencesIfNeeded()

        let row = try XCTUnwrap(FakePostgRESTStore.shared.rows(in: "household_members").first)
        XCTAssertEqual(row["id"] as? String, id)
        XCTAssertEqual(row["dietary_preferences"] as? [String], [])
    }
}
