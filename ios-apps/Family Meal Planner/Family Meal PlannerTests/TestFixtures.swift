//
//  TestFixtures.swift
//  Family Meal PlannerTests
//
//  Shared builders for the Phase 3 suites (SlotSemanticsTests,
//  CopyWeekTests, DietaryMatchTests). The app's Row models only have
//  decoding inits — production rows always come from PostgREST — so
//  fixtures decode from JSON dictionaries, and DB-side fixtures seed
//  the FakePostgRESTStore (defined in GroceryUnwindTests.swift).
//

import Foundation
@testable import Family_Meal_Planner

enum TestFixtures {

    /// Decode any Row model from a JSON-style dictionary. Uses a plain
    /// JSONDecoder: the only Date field these tests decode directly
    /// (RecipeRow.createdAt) is seeded as a Double for this path.
    static func decodeRow<T: Decodable>(_ dict: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func member(
        id: UUID = UUID(),
        householdID: UUID,
        userID: UUID? = nil,
        name: String,
        prefs: [String] = []
    ) throws -> HouseholdMemberRow {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "household_id": householdID.uuidString,
            "display_name": name,
            "is_head_cook": false,
            "dietary_preferences": prefs,
        ]
        if let userID { dict["user_id"] = userID.uuidString }
        return try decodeRow(dict)
    }

    static func mealPlanRow(
        id: UUID = UUID(),
        householdID: UUID,
        recipeID: UUID?,
        memberID: UUID?,
        date: String
    ) throws -> MealPlanRow {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "household_id": householdID.uuidString,
            "date": date,
        ]
        if let recipeID { dict["recipe_id"] = recipeID.uuidString }
        if let memberID { dict["member_id"] = memberID.uuidString }
        return try decodeRow(dict)
    }

    static func recipeRow(
        id: UUID = UUID(),
        householdID: UUID,
        name: String
    ) throws -> RecipeRow {
        try decodeRow([
            "id": id.uuidString,
            "household_id": householdID.uuidString,
            "name": name,
            // Plain JSONDecoder default date strategy: seconds since
            // the reference date.
            "created_at": 0.0,
        ])
    }

    // MARK: - Fake-store seeding

    /// created_at format the Supabase SDK decoder parses (same one the
    /// fake store stamps on POSTed rows).
    static let storeTimestamp = "2026-08-28T00:00:00.000000+00:00"

    /// Seed a recipe (and its ingredients) into the fake store so the
    /// real RecipeService.fetchRecipes() returns it. Returns the id.
    @discardableResult
    static func seedRecipe(
        householdID: UUID,
        name: String,
        ingredients: [(name: String, quantity: Double, unit: String)] = []
    ) -> UUID {
        let recipeID = UUID()
        FakePostgRESTStore.shared.seed(table: "recipes", rows: [[
            "id": recipeID.uuidString.lowercased(),
            "household_id": householdID.uuidString.lowercased(),
            "name": name,
            "category": "dinner",
            "created_at": storeTimestamp,
        ]])
        if !ingredients.isEmpty {
            FakePostgRESTStore.shared.seed(
                table: "recipe_ingredients",
                rows: ingredients.enumerated().map { index, ing in [
                    "id": UUID().uuidString.lowercased(),
                    "recipe_id": recipeID.uuidString.lowercased(),
                    "name": ing.name,
                    "quantity": ing.quantity,
                    "unit": ing.unit,
                    "sort_order": index,
                ] }
            )
        }
        return recipeID
    }

    /// Seed a meal_plans row directly (bypassing the assign path) —
    /// for building "last week" fixtures the app couldn't create
    /// (assigning to past dates is blocked).
    @discardableResult
    static func seedMealPlan(
        householdID: UUID,
        recipeID: UUID,
        memberID: UUID?,
        dateISO: String
    ) -> UUID {
        let id = UUID()
        var row: [String: Any] = [
            "id": id.uuidString.lowercased(),
            "household_id": householdID.uuidString.lowercased(),
            "recipe_id": recipeID.uuidString.lowercased(),
            "date": dateISO,
        ]
        if let memberID { row["member_id"] = memberID.uuidString.lowercased() }
        FakePostgRESTStore.shared.seed(table: "meal_plans", rows: [row])
        return id
    }
}
