//
//  WeekSummaryTests.swift
//  Family Meal PlannerTests
//
//  The week view's count lines. The open-night rule (fixed
//  2026-09-01): open = today or later AND no household meal. Past
//  empty days can't be filled, so they must never read as "open".
//

import XCTest
@testable import Family_Meal_Planner

final class WeekSummaryTests: XCTestCase {

    private let calendar = Calendar.current

    /// Mon..Sun of some fixed week, plus a chosen "today" inside it.
    private func week(todayOffset: Int) -> (dates: [Date], today: Date) {
        let start = calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))!)
        let dates = (0..<7).map {
            calendar.date(byAdding: .day, value: $0, to: start)!
        }
        return (dates, dates[todayOffset])
    }

    /// The bug this fixes: an empty PAST day is not open. Thursday as
    /// today, Mon–Wed empty and gone — only the empty future days
    /// (Fri, Sun) and today (Thu, also empty) count as open.
    func testPastEmptyDaysAreNotOpen() {
        let (dates, today) = week(todayOffset: 3)
        let planned = Set([dates[5]])   // Saturday has a household meal

        let summary = WeekSummary.build(
            weekDates: dates, today: today, calendar: calendar,
            hasMeal: { planned.contains($0) },
            hasHouseholdMeal: { planned.contains($0) }
        )
        XCTAssertEqual(summary.openCount, 3, "Thu (today), Fri, Sun — never Mon–Wed")
        XCTAssertEqual(summary.plannedCount, 1)
        XCTAssertEqual(summary.stateLine, "One dinner planned, three open.")
        XCTAssertEqual(summary.openNightsLine, "Three nights are still open.")
    }

    /// A future day holding only a member meal is still open — the
    /// line is about the household slot.
    func testMemberOnlyDayCountsAsOpen() {
        let (dates, today) = week(todayOffset: 3)
        let memberOnly = dates[4]       // Friday: a member meal, no household meal
        let household = Set([dates[3], dates[5], dates[6]])

        let summary = WeekSummary.build(
            weekDates: dates, today: today, calendar: calendar,
            hasMeal: { household.contains($0) || $0 == memberOnly },
            hasHouseholdMeal: { household.contains($0) }
        )
        XCTAssertEqual(summary.openCount, 1, "only Friday's household slot is open")
        XCTAssertEqual(summary.plannedCount, 4)
        XCTAssertEqual(summary.openNightsLine, "One night is still open.")
    }

    /// Every remaining night filled → settled, even when past days
    /// went unplanned (they can't be filled anymore).
    func testWeekSettledWhenAllRemainingNightsAreFilled() {
        let (dates, today) = week(todayOffset: 5)
        let household = Set([dates[5], dates[6]])   // Sat (today) + Sun

        let summary = WeekSummary.build(
            weekDates: dates, today: today, calendar: calendar,
            hasMeal: { household.contains($0) },
            hasHouseholdMeal: { household.contains($0) }
        )
        XCTAssertEqual(summary.openCount, 0)
        XCTAssertEqual(summary.openNightsLine, "The week is settled.")
        XCTAssertEqual(summary.stateLine, "Every night is planned.")
    }

    /// Nothing planned at all keeps the original empty-state copy.
    func testNothingPlannedYet() {
        let (dates, today) = week(todayOffset: 0)
        let summary = WeekSummary.build(
            weekDates: dates, today: today, calendar: calendar,
            hasMeal: { _ in false },
            hasHouseholdMeal: { _ in false }
        )
        XCTAssertEqual(summary.plannedCount, 0)
        XCTAssertEqual(summary.openCount, 7, "Monday morning: the whole week is open")
        XCTAssertEqual(summary.stateLine, "Nothing planned yet.")
        XCTAssertEqual(summary.openNightsLine, "Seven nights are still open.")
    }
}
