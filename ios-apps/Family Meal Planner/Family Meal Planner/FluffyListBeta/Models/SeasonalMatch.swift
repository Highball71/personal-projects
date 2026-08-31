//
//  SeasonalMatch.swift
//  FluffyList
//
//  Seasonal Suggestions v1: keyword-only matching between a recipe
//  and the current region-month produce list — same spirit as
//  DietaryMatch, but scored instead of first-hit. Discovery, not
//  enforcement: zero hits means a recipe simply isn't promoted; it is
//  never hidden.
//
//  Matching is on word boundaries rather than raw substrings so that
//  "corn" doesn't fire on "cornstarch" — a false PROMOTION reads much
//  worse than a missed one (a false dietary hint is only a gentle
//  question; a wrong "in season" claim makes the feature look broken).
//

import Foundation

enum SeasonalMatch {

    /// Peak produce counts double — decision 3 in FEATURE_SEASONAL:
    /// "In season now" ranks peak hits above merely-available hits.
    static let peakWeight = 2
    static let availableWeight = 1

    /// How a recipe scored against one region-month produce cell.
    struct Score: Equatable {
        /// peakWeight × peak hits + availableWeight × available hits.
        let points: Int
        /// Matched produce keywords, for the "IN SEASON · TOMATO"
        /// metadata line. Peak first.
        let peakHits: [String]
        let availableHits: [String]

        var isSeasonal: Bool { points > 0 }
        var matchedProduce: [String] { peakHits + availableHits }
    }

    /// A recipe promoted into the "In season now" section.
    struct Pick: Equatable {
        let recipe: RecipeRow
        let score: Score
    }

    // MARK: - Tokenizing

    /// Lowercase a phrase, split on anything that isn't a letter, and
    /// fold simple plurals so "tomatoes" meets "tomato". Both produce
    /// keywords and recipe text go through the same fold, so imperfect
    /// singulars ("asparagus" → "asparagu") still match themselves.
    static func tokens(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
            .map(singularize)
    }

    private static func singularize(_ word: String) -> String {
        if word.hasSuffix("ies") && word.count > 4 {
            return String(word.dropLast(3)) + "y"
        }
        if (word.hasSuffix("oes") || word.hasSuffix("ches") || word.hasSuffix("shes"))
            && word.count > 4 {
            return String(word.dropLast(2))
        }
        if word.hasSuffix("s") && !word.hasSuffix("ss") && word.count > 3 {
            return String(word.dropLast())
        }
        return word
    }

    /// Whether a produce keyword's token sequence appears contiguously
    /// in a token list — "sweet corn" matches "fresh sweet corn" but
    /// "corn" never matches "cornstarch".
    private static func sequence(_ needle: [String], appearsIn haystack: [String]) -> Bool {
        guard !needle.isEmpty, needle.count <= haystack.count else { return false }
        for start in 0...(haystack.count - needle.count) {
            if Array(haystack[start..<(start + needle.count)]) == needle { return true }
        }
        return false
    }

    // MARK: - Scoring

    /// Score one recipe against one produce cell. Each produce entry
    /// counts at most once, whether it matched the recipe name, an
    /// ingredient, or both.
    static func score(
        recipe: RecipeRow,
        ingredientNames: [String]?,
        produce: SeasonalProduce
    ) -> Score {
        let nameTokens = tokens(recipe.name)
        let ingredientTokens = (ingredientNames ?? []).map(tokens)

        func hits(_ keywords: [String]) -> [String] {
            keywords.filter { keyword in
                let needle = tokens(keyword)
                if sequence(needle, appearsIn: nameTokens) { return true }
                return ingredientTokens.contains { sequence(needle, appearsIn: $0) }
            }
        }

        let peakHits = hits(produce.peak)
        let availableHits = hits(produce.available)
        return Score(
            points: peakWeight * peakHits.count + availableWeight * availableHits.count,
            peakHits: peakHits,
            availableHits: availableHits
        )
    }

    // MARK: - The "In season now" section

    /// The seasonal picks for the Choose a Recipe sheet: recipes with
    /// at least one hit, best score first (peak hits break ties, then
    /// name), capped. Empty whenever the feature is dormant — region
    /// unset, or the bundled calendar missing.
    static func inSeasonNow(
        recipes: [RecipeRow],
        ingredientsByRecipeID: [UUID: [String]],
        region: USRegion?,
        month: Int,
        calendar: SeasonalCalendar? = .shared,
        cap: Int = 8
    ) -> [Pick] {
        guard let region,
              let produce = calendar?.produce(for: region, month: month),
              !produce.isEmpty else { return [] }

        return recipes
            .map { Pick(recipe: $0, score: score(
                recipe: $0,
                ingredientNames: ingredientsByRecipeID[$0.id],
                produce: produce
            )) }
            .filter { $0.score.isSeasonal }
            .sorted {
                if $0.score.points != $1.score.points {
                    return $0.score.points > $1.score.points
                }
                if $0.score.peakHits.count != $1.score.peakHits.count {
                    return $0.score.peakHits.count > $1.score.peakHits.count
                }
                return $0.recipe.name.localizedCaseInsensitiveCompare($1.recipe.name) == .orderedAscending
            }
            .prefix(cap)
            .map { $0 }
    }

    /// IDs of every qualifying recipe (uncapped) — drives the small
    /// leaf badge on recipe rows elsewhere. Empty when dormant.
    static func seasonalRecipeIDs(
        recipes: [RecipeRow],
        ingredientsByRecipeID: [UUID: [String]],
        region: USRegion?,
        month: Int,
        calendar: SeasonalCalendar? = .shared
    ) -> Set<UUID> {
        guard let region,
              let produce = calendar?.produce(for: region, month: month),
              !produce.isEmpty else { return [] }

        return Set(recipes.filter {
            score(recipe: $0, ingredientNames: ingredientsByRecipeID[$0.id], produce: produce)
                .isSeasonal
        }.map(\.id))
    }

    /// Metadata line under a seasonal pick — "IN SEASON · TOMATO,
    /// BASIL" (FluffyMetadataLine uppercases it). At most three
    /// produce names, peak first, so long matches stay one line.
    static func matchText(for score: Score) -> String {
        let names = score.matchedProduce.prefix(3).joined(separator: ", ")
        return names.isEmpty ? "In season" : "In season \u{00B7} \(names)"
    }
}
