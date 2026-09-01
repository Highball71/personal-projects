//
//  DietaryMatchTests.swift
//  Family Meal PlannerTests
//
//  Per-person meals Phase 3: keyword-only dietary matching for the
//  recipe picker's gentle hints. Flag, never block; a keyword miss
//  shows nothing (v1 is honest about misses).
//

import XCTest
@testable import Family_Meal_Planner

final class DietaryMatchTests: XCTestCase {

    private let householdID = UUID()

    /// A keyword in the recipe NAME trips the hint.
    func testConflictMatchesRecipeName() {
        let conflict = DietaryMatch.conflict(
            option: .vegetarian,
            recipeName: "Chicken Alfredo",
            ingredientNames: []
        )
        XCTAssertEqual(conflict?.option, .vegetarian)
        XCTAssertEqual(conflict?.keyword, "chicken")
    }

    /// A keyword in the INGREDIENT list trips the hint (names arrive
    /// lowercased from RecipeService's cache).
    func testConflictMatchesIngredientNames() {
        let conflict = DietaryMatch.conflict(
            option: .nutFree,
            recipeName: "Weeknight Stir-Fry",
            ingredientNames: ["broccoli", "almond slivers", "soy sauce"]
        )
        XCTAssertEqual(conflict?.option, .nutFree)
        XCTAssertEqual(conflict?.keyword, "almond")
    }

    /// "nutmeg" must NOT trip Nut-Free — bare "nut" is deliberately
    /// not a keyword.
    func testNutmegDoesNotTripNutFree() {
        XCTAssertNil(DietaryMatch.conflict(
            option: .nutFree,
            recipeName: "Spiced Squash Soup",
            ingredientNames: ["butternut squash", "nutmeg", "cream"]
        ))
    }

    /// Member-level check walks the member's stored preferences and
    /// skips unknown strings (from a future app version).
    func testMemberConflictUsesStoredPrefsAndSkipsUnknowns() throws {
        let member = try TestFixtures.member(
            householdID: householdID,
            name: "Maya",
            prefs: ["SomeFutureDiet", "Nut-Free"]
        )
        let recipe = try TestFixtures.recipeRow(householdID: householdID, name: "Peanut Stew")

        let conflict = DietaryMatch.conflict(for: member, recipe: recipe, ingredientNames: nil)
        XCTAssertEqual(conflict?.option, .nutFree)
        XCTAssertEqual(conflict?.keyword, "peanut")
    }

    /// No preferences (or no clash) → no hint.
    func testNoPreferencesMeansNoHint() throws {
        let noPrefs = try TestFixtures.member(householdID: householdID, name: "Sam")
        let recipe = try TestFixtures.recipeRow(householdID: householdID, name: "Peanut Stew")
        XCTAssertNil(DietaryMatch.conflict(for: noPrefs, recipe: recipe, ingredientNames: nil))

        let vegetarian = try TestFixtures.member(
            householdID: householdID, name: "Kim", prefs: ["Vegetarian"])
        let salad = try TestFixtures.recipeRow(householdID: householdID, name: "Garden Salad")
        XCTAssertNil(DietaryMatch.conflict(
            for: vegetarian, recipe: salad,
            ingredientNames: ["lettuce", "tomato", "cucumber"]))
    }

    /// The hint copy names the preference and the matched keyword,
    /// phrased as a guess.
    func testHintTextNamesPreferenceAndKeyword() {
        let text = DietaryMatch.hintText(
            for: .init(option: .nutFree, keyword: "almond"))
        XCTAssertEqual(text, "Might not be Nut-Free \u{00B7} almond")
    }

    // MARK: - Household-wide hints (EVERYONE selected)

    /// EVERYONE checks every member: the hint names the FIRST member
    /// (in household member order) with a clash, and counts the rest
    /// as "+N" — even when they clash with different preferences.
    func testHouseholdConflictNamesFirstMemberAndCountsOthers() throws {
        let sam = try TestFixtures.member(householdID: householdID, name: "Sam")
        let maya = try TestFixtures.member(
            householdID: householdID, name: "Maya", prefs: ["Vegan"])
        let kim = try TestFixtures.member(
            householdID: householdID, name: "Kim", prefs: ["Dairy-Free"])
        let recipe = try TestFixtures.recipeRow(householdID: householdID, name: "Alfredo")

        let household = DietaryMatch.householdConflict(
            members: [sam, maya, kim],
            recipe: recipe,
            ingredientNames: ["butter", "cream", "fettuccine"]
        )
        XCTAssertEqual(household?.memberName, "Maya",
                       "first clashing member in household order is named")
        XCTAssertEqual(household?.conflict.option, .vegan)
        XCTAssertEqual(household?.conflict.keyword, "butter")
        XCTAssertEqual(household?.othersCount, 1, "Kim's dairy clash counts as +1")

        let text = DietaryMatch.hintText(for: household!)
        XCTAssertEqual(text, "Might not be Vegan for Maya +1 \u{00B7} butter")
    }

    /// A lone clashing member gets no "+N"; nobody clashing (or no
    /// members at all) means no hint.
    func testHouseholdConflictSingleMemberAndNoConflictCases() throws {
        let maya = try TestFixtures.member(
            householdID: householdID, name: "Maya", prefs: ["Nut-Free"])
        let sam = try TestFixtures.member(householdID: householdID, name: "Sam")
        let stew = try TestFixtures.recipeRow(householdID: householdID, name: "Peanut Stew")

        let household = DietaryMatch.householdConflict(
            members: [sam, maya], recipe: stew, ingredientNames: nil)
        XCTAssertEqual(household?.othersCount, 0)
        XCTAssertEqual(
            DietaryMatch.hintText(for: household!),
            "Might not be Nut-Free for Maya \u{00B7} peanut")

        let salad = try TestFixtures.recipeRow(householdID: householdID, name: "Garden Salad")
        XCTAssertNil(DietaryMatch.householdConflict(
            members: [sam, maya], recipe: salad,
            ingredientNames: ["lettuce", "tomato"]))
        XCTAssertNil(DietaryMatch.householdConflict(
            members: [], recipe: stew, ingredientNames: nil))
    }
}
