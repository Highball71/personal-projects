//
//  SeasonalStrip.swift
//  FluffyList
//
//  The empty-week ("wide open") seasonal strip: a handful of
//  in-season recipes shown before any day is picked, so the harvest
//  can start the plan instead of only decorating it. Pure and
//  injectable (WeekSummary-style) so the recipe selection and the
//  first-open-night math are unit-testable without SwiftUI.
//
//  Selection reuses SeasonalMatch.inSeasonNow — the same scoring as
//  the picker's "In season now" shelf — then deduplicates by
//  normalized recipe NAME (repeat imports create same-name rows with
//  different ids; two "Egg Roll in a Bowl" lines in a four-row strip
//  would read as a bug) and caps at four. Dormant exactly when the
//  shelf is dormant: unset region or missing calendar means an empty
//  strip, and the view hides an empty strip entirely.
//

import Foundation

enum SeasonalStrip {

    /// The strip is short on purpose: it sits above the empty week's
    /// action links, not instead of them.
    static let cap = 4

    /// The strip's recipes: best seasonal score first, one row per
    /// distinct recipe name, at most `cap`. Empty when dormant.
    static func picks(
        recipes: [RecipeRow],
        ingredientsByRecipeID: [UUID: [String]],
        region: USRegion?,
        month: Int,
        calendar: SeasonalCalendar? = .shared
    ) -> [SeasonalMatch.Pick] {
        // Rank everything (no cap) so name-dedup can't leave the strip
        // short while distinct recipes still qualify further down.
        let ranked = SeasonalMatch.inSeasonNow(
            recipes: recipes,
            ingredientsByRecipeID: ingredientsByRecipeID,
            region: region,
            month: month,
            calendar: calendar,
            cap: recipes.count
        )

        var seenNames = Set<String>()
        var strip: [SeasonalMatch.Pick] = []
        for pick in ranked {
            let key = pick.recipe.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !key.isEmpty else { continue }
            if seenNames.insert(key).inserted {
                strip.append(pick)
                if strip.count == cap { break }
            }
        }
        return strip
    }

    /// The night a strip tap plans for: the first day of the displayed
    /// week that is today or later. nil when every day has passed —
    /// a past week has nothing to plan, so the strip hides (the view
    /// never shows the planning state on past weeks anyway; this is
    /// the model-level guarantee).
    static func firstOpenNight(
        weekDates: [Date],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        let todayStart = calendar.startOfDay(for: today)
        return weekDates.first { calendar.startOfDay(for: $0) >= todayStart }
    }
}
