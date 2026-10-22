//
//  WeekOverlapTests.swift
//  Family Meal PlannerTests
//
//  Ingredient Chaining Phase 1: the observational "ALSO USES CABBAGE"
//  badge in the recipe picker. A candidate earns it only by sharing a
//  PERISHABLE ingredient name with a recipe already planned this week
//  — staples never count, word boundaries hold, a planned recipe never
//  badges itself, and missing data is quiet, not a crash.
//

import XCTest
@testable import Family_Meal_Planner

final class WeekOverlapTests: XCTestCase {

    private let householdID = UUID()

    private func recipe(_ name: String) throws -> RecipeRow {
        try TestFixtures.recipeRow(householdID: householdID, name: name)
    }

    /// One planned recipe and one candidate, each with its own
    /// ingredient names — the shape most tests need.
    private func overlap(
        planned plannedIngredients: [String],
        candidate candidateIngredients: [String]
    ) throws -> [String]? {
        let planned = try recipe("Planned")
        let candidate = try recipe("Candidate")
        let result = WeekOverlap.overlaps(
            weekRecipeIDs: [planned.id],
            ingredientsByRecipeID: [
                planned.id: plannedIngredients,
                candidate.id: candidateIngredients,
            ],
            candidates: [planned, candidate]
        )
        return result[candidate.id]
    }

    // MARK: - Badge or not

    /// Sharing one perishable is enough — and the text names it.
    func testSharedPerishableEarnsBadge() throws {
        let names = try overlap(
            planned: ["napa cabbage", "soy sauce", "rice"],
            candidate: ["cabbage", "carrots", "olive oil"]
        )
        XCTAssertEqual(names, ["cabbage"])
        XCTAssertEqual(names.map(WeekOverlap.badgeText), "Also uses cabbage")
    }

    /// Staples are never perishables — sharing only olive oil, salt,
    /// and garlic earns nothing.
    func testStaplesOnlyEarnsNoBadge() throws {
        XCTAssertNil(try overlap(
            planned: ["olive oil", "salt", "garlic", "chicken"],
            candidate: ["olive oil", "salt", "garlic", "lentils"]
        ))
    }

    /// Variants of one perishable meet: scallions this week, green
    /// onions in the candidate → both are "scallion".
    func testVariantKeywordsMatch() throws {
        XCTAssertEqual(try overlap(
            planned: ["scallions"],
            candidate: ["green onions"]
        ), ["scallion"])
    }

    /// Plurals fold to singulars, and word boundaries hold: "corn" in
    /// the week never matches "cornstarch" in the candidate.
    func testPluralsMatchAndWordBoundariesHold() throws {
        XCTAssertEqual(try overlap(
            planned: ["tomatoes"],
            candidate: ["tomato"]
        ), ["tomato"])
        XCTAssertNil(try overlap(
            planned: ["corn"],
            candidate: ["cornstarch"]
        ), "cornstarch must not match corn")
    }

    /// Shelf-stable forms of a perishable don't count: chicken broth
    /// is broth (a staple), not chicken.
    func testShelfStableFormsAreNotPerishable() throws {
        XCTAssertNil(try overlap(
            planned: ["chicken thighs"],
            candidate: ["chicken broth", "canned tomatoes"]
        ))
        XCTAssertNil(try overlap(
            planned: ["sweet potatoes"],
            candidate: ["potatoes"]
        ), "sweet potato is not potato")
    }

    /// A recipe already planned this week gets no badge — it would
    /// only be matching itself.
    func testPlannedRecipeNeverBadgesItself() throws {
        let slaw = try recipe("Cabbage Slaw")
        let tacos = try recipe("Fish Tacos")
        let result = WeekOverlap.overlaps(
            weekRecipeIDs: [slaw.id, tacos.id],
            ingredientsByRecipeID: [
                slaw.id: ["cabbage", "cilantro"],
                tacos.id: ["cabbage", "cilantro", "lime"],
            ],
            candidates: [slaw, tacos]
        )
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Text

    /// Four shared perishables → three names, alphabetical.
    func testBadgeShowsThreeNamesAlphabetically() throws {
        let names = try overlap(
            planned: ["lime", "cilantro", "cabbage", "chicken", "avocado"],
            candidate: ["lime wedges", "chicken breast", "fresh cilantro", "shredded cabbage"]
        )
        XCTAssertEqual(names, ["cabbage", "chicken", "cilantro"])
        XCTAssertEqual(names.map(WeekOverlap.badgeText),
                       "Also uses cabbage, chicken, cilantro")
    }

    // MARK: - Quiet when there's nothing to say

    /// An empty week badges nothing, anywhere.
    func testEmptyWeekMeansNoBadges() throws {
        let a = try recipe("Cabbage Slaw")
        let b = try recipe("Fish Tacos")
        let result = WeekOverlap.overlaps(
            weekRecipeIDs: [],
            ingredientsByRecipeID: [a.id: ["cabbage"], b.id: ["cabbage"]],
            candidates: [a, b]
        )
        XCTAssertTrue(result.isEmpty)
    }

    /// No ingredient data for a recipe (planned or candidate) → no
    /// badge and no crash.
    func testMissingIngredientsMeansNoBadge() throws {
        let planned = try recipe("Planned")
        let bare = try recipe("No Ingredients Loaded")
        let other = try recipe("Unplanned Slaw")

        // Candidate missing from the map.
        XCTAssertTrue(WeekOverlap.overlaps(
            weekRecipeIDs: [planned.id],
            ingredientsByRecipeID: [planned.id: ["cabbage"]],
            candidates: [planned, bare]
        ).isEmpty)

        // Planned recipe missing from the map — the basket is empty.
        XCTAssertTrue(WeekOverlap.overlaps(
            weekRecipeIDs: [bare.id],
            ingredientsByRecipeID: [other.id: ["cabbage"]],
            candidates: [bare, other]
        ).isEmpty)
    }
}
