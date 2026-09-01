//
//  SeasonalMatchTests.swift
//  Family Meal PlannerTests
//
//  Seasonal Suggestions v1: keyword scoring for the "In season now"
//  section. Peak beats available, zero hits are never promoted (but
//  never hidden either — that's the UI's job), and an unset region
//  keeps the whole feature dormant.
//

import XCTest
@testable import Family_Meal_Planner

final class SeasonalMatchTests: XCTestCase {

    private let householdID = UUID()

    /// An August-ish produce cell used across these tests.
    private let august = SeasonalProduce(
        peak: ["tomato", "sweet corn", "basil", "peach"],
        available: ["onion", "garlic", "kale", "apple"]
    )

    /// A one-cell calendar so tests don't depend on the real month.
    private var calendar: SeasonalCalendar {
        SeasonalCalendar(regions: ["northeast": ["8": august]])
    }

    private func recipe(_ name: String) throws -> RecipeRow {
        try TestFixtures.recipeRow(householdID: householdID, name: name)
    }

    // MARK: - Scoring

    /// Peak hits weigh 2, available hits weigh 1 (decision 3: peak
    /// ranks above merely-available).
    func testPeakHitsWeighDoubleAvailableHits() throws {
        let r = try recipe("Summer Pasta")
        let score = SeasonalMatch.score(
            recipe: r,
            ingredientNames: ["tomatoes", "basil", "onion"],
            produce: august
        )
        XCTAssertEqual(score.peakHits.sorted(), ["basil", "tomato"])
        XCTAssertEqual(score.availableHits, ["onion"])
        XCTAssertEqual(score.points, 2 * 2 + 1)
    }

    /// One peak hit outranks one available hit in the section order.
    func testPeakRecipeRanksAboveAvailableRecipe() throws {
        let peachy = try recipe("Peach Crumble")
        let appley = try recipe("Apple Crumble")
        let picks = SeasonalMatch.inSeasonNow(
            recipes: [appley, peachy],
            ingredientsByRecipeID: [:],
            region: .northeast,
            month: 8,
            calendar: calendar
        )
        XCTAssertEqual(picks.map(\.recipe.name), ["Peach Crumble", "Apple Crumble"])
        XCTAssertGreaterThan(picks[0].score.points, picks[1].score.points)
    }

    /// Zero hits = shown normally elsewhere, but never promoted into
    /// the section and never badged. (The badged recipe here has a
    /// peak hit, which meets the stricter badge rule.)
    func testZeroHitRecipeIsExcludedFromSectionAndBadges() throws {
        let miss = try recipe("Weeknight Lentil Soup")
        let hit = try recipe("Tomato Salad")
        let picks = SeasonalMatch.inSeasonNow(
            recipes: [miss, hit],
            ingredientsByRecipeID: [miss.id: ["lentil", "cumin"]],
            region: .northeast,
            month: 8,
            calendar: calendar
        )
        XCTAssertEqual(picks.map(\.recipe.id), [hit.id])

        let ids = SeasonalMatch.seasonalRecipeIDs(
            recipes: [miss, hit],
            ingredientsByRecipeID: [miss.id: ["lentil", "cumin"]],
            region: .northeast,
            month: 8,
            calendar: calendar
        )
        XCTAssertEqual(ids, [hit.id])
    }

    /// The leaf badge is stricter than the section: onion and garlic
    /// sit on most months' "available" lists, so a lone available hit
    /// must NOT earn the leaf (or nearly every recipe would wear one)
    /// — but a lone PEAK hit does, and so do two hits of any kind.
    /// The "In season now" section still promotes any hit at all.
    func testBadgeNeedsPeakHitOrTwoHits() throws {
        let onionOnly = try recipe("Weeknight Rice Bowl")
        let peachOnly = try recipe("Peach Crumble")
        let onionAndKale = try recipe("Braised Greens")
        let ingredients = [
            onionOnly.id: ["onion", "rice", "soy sauce"],
            onionAndKale.id: ["onion", "kale", "olive oil"],
        ]

        let ids = SeasonalMatch.seasonalRecipeIDs(
            recipes: [onionOnly, peachOnly, onionAndKale],
            ingredientsByRecipeID: ingredients,
            region: .northeast,
            month: 8,
            calendar: calendar
        )
        XCTAssertFalse(ids.contains(onionOnly.id),
                       "a single available hit must not earn the leaf")
        XCTAssertTrue(ids.contains(peachOnly.id),
                      "a single peak hit earns the leaf")
        XCTAssertTrue(ids.contains(onionAndKale.id),
                      "two available hits earn the leaf")

        // The section is untouched by the badge rule: the onion-only
        // recipe is still promoted (ranked low), never filtered out.
        let picks = SeasonalMatch.inSeasonNow(
            recipes: [onionOnly, peachOnly, onionAndKale],
            ingredientsByRecipeID: ingredients,
            region: .northeast,
            month: 8,
            calendar: calendar
        )
        XCTAssertTrue(picks.map(\.recipe.id).contains(onionOnly.id),
                      "the In season now shelf still promotes any hit")
    }

    /// The section is capped at 8 even when more recipes qualify.
    func testSectionIsCappedAtEight() throws {
        let recipes = try (1...10).map { try recipe("Tomato Dish \($0)") }
        let picks = SeasonalMatch.inSeasonNow(
            recipes: recipes,
            ingredientsByRecipeID: [:],
            region: .northeast,
            month: 8,
            calendar: calendar
        )
        XCTAssertEqual(picks.count, 8)
    }

    // MARK: - Dormancy

    /// No region set → the feature is fully dormant: no picks, no
    /// badge IDs, regardless of what the calendar holds.
    func testUnsetRegionMeansFullyDormant() throws {
        let r = try recipe("Tomato Salad")
        XCTAssertTrue(SeasonalMatch.inSeasonNow(
            recipes: [r],
            ingredientsByRecipeID: [:],
            region: nil,
            month: 8,
            calendar: calendar
        ).isEmpty)
        XCTAssertTrue(SeasonalMatch.seasonalRecipeIDs(
            recipes: [r],
            ingredientsByRecipeID: [:],
            region: nil,
            month: 8,
            calendar: calendar
        ).isEmpty)
        // USRegion(rawValue: "") is nil — the stored default maps to
        // dormant through the same path the views use.
        XCTAssertNil(USRegion(rawValue: ""))
    }

    /// A missing calendar (bundle problem) is dormant, not a crash.
    func testMissingCalendarMeansDormant() throws {
        let r = try recipe("Tomato Salad")
        XCTAssertTrue(SeasonalMatch.inSeasonNow(
            recipes: [r],
            ingredientsByRecipeID: [:],
            region: .northeast,
            month: 8,
            calendar: nil
        ).isEmpty)
    }

    // MARK: - Word-boundary matching

    /// "corn" must not fire on "cornstarch" — a false promotion makes
    /// the feature look broken. Plurals still meet their singulars,
    /// and multi-word keywords need the whole phrase.
    func testWordBoundaryAndPluralMatching() throws {
        let starch = try recipe("Crispy Wings")
        let cobs = try recipe("Corn on the Cob")
        let mustardChicken = try recipe("Honey Mustard Chicken")

        let greens = SeasonalProduce(peak: ["sweet corn", "corn", "mustard greens"], available: [])

        let starchScore = SeasonalMatch.score(
            recipe: starch, ingredientNames: ["cornstarch", "chicken wings"], produce: greens)
        XCTAssertFalse(starchScore.isSeasonal, "cornstarch must not match corn")

        let cobScore = SeasonalMatch.score(
            recipe: cobs, ingredientNames: ["ears of corn"], produce: greens)
        XCTAssertTrue(cobScore.isSeasonal)

        let mustardScore = SeasonalMatch.score(
            recipe: mustardChicken, ingredientNames: ["dijon mustard", "honey"], produce: greens)
        XCTAssertFalse(mustardScore.isSeasonal, "condiment mustard must not match mustard greens")

        let tomatoes = SeasonalMatch.score(
            recipe: try recipe("Sauce"), ingredientNames: ["crushed tomatoes"],
            produce: SeasonalProduce(peak: ["tomato"], available: []))
        XCTAssertTrue(tomatoes.isSeasonal, "plural ingredient must meet singular keyword")
    }

    /// A keyword in the recipe NAME alone counts (same spirit as
    /// DietaryMatch), and each produce entry counts only once even
    /// when it appears in both name and ingredients.
    func testNameMatchesAndNoDoubleCounting() throws {
        let r = try recipe("Peach and Basil Salad")
        let score = SeasonalMatch.score(
            recipe: r,
            ingredientNames: ["peaches", "basil", "olive oil"],
            produce: august
        )
        XCTAssertEqual(score.peakHits.sorted(), ["basil", "peach"])
        XCTAssertEqual(score.points, 4)
    }

    /// The match line names the produce, peak first, capped at three.
    func testMatchTextNamesProduce() {
        let text = SeasonalMatch.matchText(
            for: SeasonalMatch.Score(points: 5,
                                     peakHits: ["tomato", "basil"],
                                     availableHits: ["onion", "kale"]))
        XCTAssertEqual(text, "In season \u{00B7} tomato, basil, onion")
    }
}
