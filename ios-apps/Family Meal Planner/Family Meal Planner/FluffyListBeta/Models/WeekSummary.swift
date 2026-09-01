//
//  WeekSummary.swift
//  FluffyList
//
//  The week view's two italic count lines ("Five dinners planned,
//  two open." / "Two nights are still open."), extracted into a pure
//  model so the counting rules are unit-testable without SwiftUI.
//
//  The open-night rule (fixed 2026-09-01): a night is OPEN only when
//  it is today or later AND has no household meal. A day that has
//  already passed cannot be filled, so it is never "open" — before
//  this fix an empty Monday kept reading "one night is still open"
//  all week. A future day holding only member meals still counts as
//  open: the household slot is what the line is about.
//

import Foundation

struct WeekSummary: Equatable {
    /// Days with at least one meal of any kind — the "planned" count.
    let plannedCount: Int
    /// Days that are today or later with no household meal — what can
    /// still be filled.
    let openCount: Int

    /// Count a week's days. `hasMeal` = any meal at all (household or
    /// member); `hasHouseholdMeal` = a member_id-NULL meal. `today` is
    /// injectable for tests.
    static func build(
        weekDates: [Date],
        today: Date = Date(),
        calendar: Calendar = .current,
        hasMeal: (Date) -> Bool,
        hasHouseholdMeal: (Date) -> Bool
    ) -> WeekSummary {
        let todayStart = calendar.startOfDay(for: today)
        let planned = weekDates.filter(hasMeal).count
        let open = weekDates.filter { date in
            calendar.startOfDay(for: date) >= todayStart && !hasHouseholdMeal(date)
        }.count
        return WeekSummary(plannedCount: planned, openCount: open)
    }

    // MARK: - The lines

    private static let countWords = [
        "no", "one", "two", "three", "four", "five", "six", "seven"
    ]

    private static func word(_ n: Int) -> String {
        (0...7).contains(n) ? countWords[n] : "\(n)"
    }

    /// "Five dinners planned, two open." — the italic line of state
    /// under the masthead. openCount == 0 reads as settled: there is
    /// nothing left this week that could still be filled.
    var stateLine: String {
        if plannedCount == 0 { return "Nothing planned yet." }
        if openCount == 0 { return "Every night is planned." }
        let dinners = plannedCount == 1 ? "dinner" : "dinners"
        return "\(Self.word(plannedCount).capitalized) \(dinners) planned, "
            + "\(Self.word(openCount)) open."
    }

    /// Italic sentence after the closing rule naming what's still open.
    var openNightsLine: String {
        if openCount == 0 { return "The week is settled." }
        let nights = openCount == 1 ? "night is" : "nights are"
        return "\(Self.word(openCount).capitalized) \(nights) still open."
    }
}
