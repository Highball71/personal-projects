//
//  WeekOverlap.swift
//  FluffyList
//
//  Ingredient Chaining Phase 1: the "ALSO USES CABBAGE, CILANTRO"
//  badge in the recipe picker. A candidate recipe earns it when it
//  shares perishable ingredients with meals already planned this week.
//
//  OBSERVATIONAL ONLY (David, 2026-10-21): recipe-to-recipe. The badge
//  makes no claim about what has been bought or what is on hand, and
//  it never reads or touches the grocery list.
//
//  Pure — no service or network code. Matching is on recipe ingredient
//  NAMES only (never recipe_ingredients.note, never quantity/unit),
//  using SeasonalMatch's word-boundary tokens so "corn" doesn't fire
//  on "cornstarch" and "tomatoes" meets "tomato".
//

import Foundation

enum WeekOverlap {

    /// At most this many names in the badge, so it stays one line.
    static let displayCap = 3

    /// PerishableIngredients with every phrase tokenized once, up
    /// front — the picker re-runs overlaps() on each render, across
    /// every ingredient of every recipe.
    private struct Matcher {
        let name: String
        let keywords: [[String]]
        let excluding: [[String]]
    }

    private static let matchers: [Matcher] = PerishableIngredients.entries.map { entry in
        Matcher(
            name: entry.name,
            keywords: entry.keywords.map { SeasonalMatch.tokens($0) },
            excluding: entry.excluding.map { SeasonalMatch.tokens($0) }
        )
    }

    /// Canonical perishable names (PerishableIngredients.Entry.name)
    /// hit by a list of ingredient names. Unknown names hit nothing.
    static func perishables(in ingredientNames: [String]) -> Set<String> {
        var found: Set<String> = []
        for ingredient in ingredientNames {
            let tokens = SeasonalMatch.tokens(ingredient)
            // "chicken broth", "canned tomatoes", "dried basil" — a
            // shelf-stable form contributes nothing.
            if tokens.contains(where: { PerishableIngredients.shelfStableWords.contains($0) }) {
                continue
            }
            for matcher in matchers where !found.contains(matcher.name) {
                let hit = matcher.keywords.contains {
                    SeasonalMatch.sequence($0, appearsIn: tokens)
                }
                let blocked = matcher.excluding.contains {
                    SeasonalMatch.sequence($0, appearsIn: tokens)
                }
                if hit && !blocked { found.insert(matcher.name) }
            }
        }
        return found
    }

    /// Overlap names per candidate recipe, alphabetical and capped at
    /// displayCap. Only recipes with at least one shared perishable
    /// appear in the result.
    ///
    /// - weekRecipeIDs: every recipe planned in the week — household
    ///   AND member meals, all seven days.
    /// - A candidate already planned this week gets no entry (it would
    ///   only match itself).
    static func overlaps(
        weekRecipeIDs: Set<UUID>,
        ingredientsByRecipeID: [UUID: [String]],
        candidates: [RecipeRow]
    ) -> [UUID: [String]] {
        // The week's basket: every perishable any planned recipe uses.
        let basket = weekRecipeIDs.reduce(into: Set<String>()) { basket, id in
            basket.formUnion(perishables(in: ingredientsByRecipeID[id] ?? []))
        }
        guard !basket.isEmpty else { return [:] }

        var result: [UUID: [String]] = [:]
        for recipe in candidates where !weekRecipeIDs.contains(recipe.id) {
            let hits = perishables(in: ingredientsByRecipeID[recipe.id] ?? [])
                .intersection(basket)
            if !hits.isEmpty {
                result[recipe.id] = Array(hits.sorted().prefix(displayCap))
            }
        }
        return result
    }

    /// "Also uses cabbage, cilantro" — FluffyMetadataLine uppercases
    /// it. Names arrive already sorted and capped from overlaps().
    /// nonisolated for the same reason as SeasonalMatch.tokens: it's
    /// pure string work, and callers pass it straight to Optional.map.
    nonisolated static func badgeText(_ names: [String]) -> String {
        "Also uses \(names.joined(separator: ", "))"
    }
}
