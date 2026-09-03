//
//  WeekNavigationTests.swift
//  Family Meal PlannerTests
//
//  Week navigation for the Press week view: the 4-back / 2-forward
//  bounds (arrows disable at the edges), past-week read-only gating,
//  the copy-source math ("Copy last week" always copies from the week
//  immediately before the DISPLAYED one), and the masthead titles.
//

import XCTest
@testable import Family_Meal_Planner

final class WeekNavigationTests: XCTestCase {

    private let calendar = Calendar.current

    /// A fixed "today" so the tests never depend on the wall clock.
    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!
    }

    /// Navigation state with the displayed week `offset` whole weeks
    /// from the current one.
    private func nav(weeksAway offset: Int) -> WeekNavigation {
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: today)
        let current = calendar.date(from: components)!
        let displayed = calendar.date(byAdding: .weekOfYear, value: offset, to: current)!
        return WeekNavigation(displayedWeekStart: displayed, today: today, calendar: calendar)
    }

    // MARK: - Bounds

    func testOffsetsComputeFromCurrentWeek() {
        XCTAssertEqual(nav(weeksAway: 0).weekOffset, 0)
        XCTAssertEqual(nav(weeksAway: -4).weekOffset, -4)
        XCTAssertEqual(nav(weeksAway: 2).weekOffset, 2)
    }

    func testArrowsDisableExactlyAtTheBounds() {
        // Four weeks back is the floor: back arrow dies, forward lives.
        XCTAssertFalse(nav(weeksAway: -4).canGoBack)
        XCTAssertNil(nav(weeksAway: -4).previousWeekStart)
        XCTAssertTrue(nav(weeksAway: -4).canGoForward)
        // One inside the floor both arrows work.
        XCTAssertTrue(nav(weeksAway: -3).canGoBack)

        // Two weeks forward is the ceiling.
        XCTAssertFalse(nav(weeksAway: 2).canGoForward)
        XCTAssertNil(nav(weeksAway: 2).nextWeekStart)
        XCTAssertTrue(nav(weeksAway: 2).canGoBack)
        XCTAssertTrue(nav(weeksAway: 1).canGoForward)

        // The current week sits well inside both bounds.
        XCTAssertTrue(nav(weeksAway: 0).canGoBack)
        XCTAssertTrue(nav(weeksAway: 0).canGoForward)
    }

    func testArrowDestinationsStepExactlyOneWeek() {
        let n = nav(weeksAway: 0)
        XCTAssertEqual(
            n.previousWeekStart,
            calendar.date(byAdding: .weekOfYear, value: -1, to: n.displayedWeekStart))
        XCTAssertEqual(
            n.nextWeekStart,
            calendar.date(byAdding: .weekOfYear, value: 1, to: n.displayedWeekStart))
    }

    // MARK: - Past-week gating

    func testPastWeeksAreReadOnlyFutureAndCurrentAreNot() {
        for offset in -4...(-1) {
            XCTAssertTrue(nav(weeksAway: offset).isPastWeek,
                          "offset \(offset) is a past week")
        }
        XCTAssertFalse(nav(weeksAway: 0).isPastWeek)
        XCTAssertFalse(nav(weeksAway: 1).isPastWeek)
        XCTAssertFalse(nav(weeksAway: 2).isPastWeek)

        XCTAssertTrue(nav(weeksAway: 0).isCurrentWeek)
        XCTAssertFalse(nav(weeksAway: -1).isCurrentWeek)
        XCTAssertFalse(nav(weeksAway: 1).isCurrentWeek)
    }

    // MARK: - Copy-source math

    func testCopySourceIsSevenDaysBeforeTheDisplayedWeek() {
        let current = nav(weeksAway: 0)
        XCTAssertEqual(
            current.copySourceWeekStart,
            calendar.date(byAdding: .day, value: -7, to: current.displayedWeekStart))

        // Displaying NEXT week, "Copy last week" copies from the
        // CURRENT week — the source follows the displayed week.
        let next = nav(weeksAway: 1)
        XCTAssertEqual(next.copySourceWeekStart, next.currentWeekStart)
    }

    // MARK: - Titles

    func testMastheadTitles() {
        XCTAssertEqual(nav(weeksAway: 0).title, "This Week")
        XCTAssertEqual(nav(weeksAway: -1).title, "Last Week")
        XCTAssertEqual(nav(weeksAway: 1).title, "Next Week")
        XCTAssertEqual(nav(weeksAway: 2).title, "In Two Weeks")
        XCTAssertEqual(nav(weeksAway: -2).title, "Two Weeks Ago")
        XCTAssertEqual(nav(weeksAway: -3).title, "Three Weeks Ago")
        XCTAssertEqual(nav(weeksAway: -4).title, "Four Weeks Ago")
    }
}
