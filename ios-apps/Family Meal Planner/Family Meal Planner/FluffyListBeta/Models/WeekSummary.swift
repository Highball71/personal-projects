//
//  WeekSummary.swift
//  FluffyList
//
//  The week view's two italic count lines ("Five meals planned, two
//  nights open." / "Two nights are still open."), extracted into a
//  pure model so the counting rules are unit-testable without SwiftUI.
//
//  "Meals", counted per meal (2026-10-30): the line used to call every
//  planned DAY a dinner, so a Monday breakfast and a Wednesday side
//  dish read as dinners, and a day with two meals counted once.
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
    /// Meals planned this week — household and member, every category.
    let plannedCount: Int
    /// Days that are today or later with no household meal — what can
    /// still be filled.
    let openCount: Int

    /// Count a week's meals and open nights. `mealCount` = meals on a
    /// date (household and member); `hasHouseholdMeal` = a
    /// member_id-NULL meal. `today` is injectable for tests.
    static func build(
        weekDates: [Date],
        today: Date = Date(),
        calendar: Calendar = .current,
        mealCount: (Date) -> Int,
        hasHouseholdMeal: (Date) -> Bool
    ) -> WeekSummary {
        let todayStart = calendar.startOfDay(for: today)
        let planned = weekDates.reduce(0) { $0 + mealCount($1) }
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

    /// "Five meals planned, two nights open." — the italic line of state
    /// under the masthead. openCount == 0 reads as settled: there is
    /// nothing left this week that could still be filled.
    var stateLine: String {
        if plannedCount == 0 { return "Nothing planned yet." }
        if openCount == 0 { return "Every night is planned." }
        let meals = plannedCount == 1 ? "meal" : "meals"
        let nights = openCount == 1 ? "night" : "nights"
        return "\(Self.word(plannedCount).capitalized) \(meals) planned, "
            + "\(Self.word(openCount)) \(nights) open."
    }

    /// Italic sentence after the closing rule naming what's still open.
    var openNightsLine: String {
        if openCount == 0 { return "The week is settled." }
        let nights = openCount == 1 ? "night is" : "nights are"
        return "\(Self.word(openCount).capitalized) \(nights) still open."
    }
}
