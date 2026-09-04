//
//  WeekFooterTests.swift
//  Family Meal PlannerTests
//
//  Visibility of the week view's planning footer (seasonal strip /
//  region prompt + "Copy last week"): shows while the displayed week
//  still has an open night, never on past weeks, and not on a fully
//  planned week. Open nights come from WeekSummary's tested rule, so
//  these cases drive the real pipeline (dates + meal closures →
//  WeekSummary → WeekFooter), not hand-fed counts alone.
//

import XCTest
@testable import Family_Meal_Planner

final class WeekFooterTests: XCTestCase {

    private let cal = Calendar.current

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func week(startingAt start: Date) -> [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    /// Mid-current-week with open nights remaining → footer shows.
    func testFooterShowsWhileAnOpenNightRemains() {
        let weekDates = week(startingAt: date(2026, 8, 30))     // Sun Aug 30
        let today = date(2026, 9, 2)                            // Wed
        // Only Wednesday itself is planned; Thu–Sat are open.
        let summary = WeekSummary.build(
            weekDates: weekDates,
            today: today,
            calendar: cal,
            hasMeal: { cal.isDate($0, inSameDayAs: today) },
            hasHouseholdMeal: { cal.isDate($0, inSameDayAs: today) }
        )
        XCTAssertGreaterThan(summary.openCount, 0)
        XCTAssertTrue(WeekFooter.isVisible(openCount: summary.openCount,
                                           isPastWeek: false))
    }

    /// An entirely EMPTY current week (the old "wide open" state) is
    /// the fullest case of "open nights remain" — footer shows.
    func testFooterShowsOnAnEmptyWeek() {
        let weekDates = week(startingAt: date(2026, 8, 30))
        let summary = WeekSummary.build(
            weekDates: weekDates,
            today: date(2026, 8, 30),
            calendar: cal,
            hasMeal: { _ in false },
            hasHouseholdMeal: { _ in false }
        )
        XCTAssertEqual(summary.openCount, 7)
        XCTAssertTrue(WeekFooter.isVisible(openCount: summary.openCount,
                                           isPastWeek: false))
    }

    /// A past week never shows the footer — its days can't be filled.
    /// Both guards hold: WeekSummary already counts zero open nights
    /// for past dates, and isPastWeek hides the footer even if a
    /// caller ever fed a nonzero count.
    func testFooterHiddenOnPastWeek() {
        let weekDates = week(startingAt: date(2026, 8, 16))
        let today = date(2026, 9, 2)
        let nav = WeekNavigation(displayedWeekStart: date(2026, 8, 16),
                                 today: today, calendar: cal)
        XCTAssertTrue(nav.isPastWeek)

        let summary = WeekSummary.build(
            weekDates: weekDates,
            today: today,
            calendar: cal,
            hasMeal: { _ in false },
            hasHouseholdMeal: { _ in false }
        )
        XCTAssertEqual(summary.openCount, 0)
        XCTAssertFalse(WeekFooter.isVisible(openCount: summary.openCount,
                                            isPastWeek: nav.isPastWeek))
        // The belt-and-suspenders guard.
        XCTAssertFalse(WeekFooter.isVisible(openCount: 7, isPastWeek: true))
    }

    /// A fully planned week (every remaining night has a household
    /// meal) reads "settled" — no footer, no Copy last week.
    func testFooterHiddenWhenWeekIsFull() {
        let weekDates = week(startingAt: date(2026, 8, 30))
        let summary = WeekSummary.build(
            weekDates: weekDates,
            today: date(2026, 9, 2),
            calendar: cal,
            hasMeal: { _ in true },
            hasHouseholdMeal: { _ in true }
        )
        XCTAssertEqual(summary.openCount, 0)
        XCTAssertFalse(WeekFooter.isVisible(openCount: summary.openCount,
                                            isPastWeek: false))
    }
}
