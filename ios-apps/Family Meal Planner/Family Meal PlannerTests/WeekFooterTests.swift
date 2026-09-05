//
//  WeekFooterTests.swift
//  Family Meal PlannerTests
//
//  Visibility of the week view's planning footer (seasonal strip /
//  region prompt + "Copy last week"): shows while any SLOT in the
//  displayed week — household or member — is open on a today-or-
//  later day; never on past weeks; not on a week with every slot
//  taken. This is the old "Copy last week" gate's breadth, restored
//  after a first cut keyed it to open household NIGHTS only and hid
//  the footer from per-person households with member slots to fill.
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

    // Sun Aug 30 – Sat Sep 5, viewed from Wednesday.
    private var weekDates: [Date] { week(startingAt: date(2026, 8, 30)) }
    private var wednesday: Date { date(2026, 9, 2) }

    /// Mid-current-week with nothing planned ahead → footer shows.
    func testFooterShowsWhileAnOpenNightRemains() {
        // Household of 2: capacity 3 per day; only Wednesday planned.
        XCTAssertTrue(WeekFooter.isVisible(
            weekDates: weekDates,
            memberCount: 2,
            isPastWeek: false,
            today: wednesday,
            calendar: cal,
            plannedSlotCount: { cal.isDate($0, inSameDayAs: self.wednesday) ? 3 : 0 }
        ))
    }

    /// An entirely EMPTY current week (the old "wide open" state) is
    /// the fullest case of "open slots remain" — footer shows.
    func testFooterShowsOnAnEmptyWeek() {
        XCTAssertTrue(WeekFooter.isVisible(
            weekDates: weekDates,
            memberCount: 0,
            isPastWeek: false,
            today: date(2026, 8, 30),
            calendar: cal,
            plannedSlotCount: { _ in 0 }
        ))
    }

    /// The widened rule: every household night is filled, but a
    /// member slot is still open on a future day — the footer (and
    /// its Copy last week) stays, exactly like the old gate.
    func testFooterShowsWhenOnlyAMemberSlotIsOpen() {
        // Household of 2: capacity 3. Every day holds the household
        // meal + one member meal (2 of 3 slots) — one member slot
        // open per remaining day.
        XCTAssertTrue(WeekFooter.isVisible(
            weekDates: weekDates,
            memberCount: 2,
            isPastWeek: false,
            today: wednesday,
            calendar: cal,
            plannedSlotCount: { _ in 2 }
        ))
    }

    /// A past week never shows the footer — its days can't be filled,
    /// however many slots are technically empty.
    func testFooterHiddenOnPastWeek() {
        let pastWeek = week(startingAt: date(2026, 8, 16))
        let nav = WeekNavigation(displayedWeekStart: date(2026, 8, 16),
                                 today: wednesday, calendar: cal)
        XCTAssertTrue(nav.isPastWeek)
        XCTAssertFalse(WeekFooter.isVisible(
            weekDates: pastWeek,
            memberCount: 2,
            isPastWeek: nav.isPastWeek,
            today: wednesday,
            calendar: cal,
            plannedSlotCount: { _ in 0 }
        ))
        // Past-day gating holds on its own too: a past week's dates
        // are all before today, so even isPastWeek: false finds no
        // fillable slot.
        XCTAssertFalse(WeekFooter.isVisible(
            weekDates: pastWeek,
            memberCount: 2,
            isPastWeek: false,
            today: wednesday,
            calendar: cal,
            plannedSlotCount: { _ in 0 }
        ))
    }

    /// A week with EVERY slot taken (household + all members, every
    /// remaining day) is settled — no footer, no Copy last week.
    func testFooterHiddenWhenEverySlotIsTaken() {
        XCTAssertFalse(WeekFooter.isVisible(
            weekDates: weekDates,
            memberCount: 2,
            isPastWeek: false,
            today: wednesday,
            calendar: cal,
            plannedSlotCount: { _ in 3 }
        ))
    }

    /// Past DAYS within the current week don't count: open slots on
    /// Sun–Tue are gone by Wednesday, so a week whose remaining days
    /// are full is settled even though its early days sit empty.
    func testPastDaysWithinTheWeekDoNotCount() {
        let today = cal.startOfDay(for: wednesday)
        XCTAssertFalse(WeekFooter.isVisible(
            weekDates: weekDates,
            memberCount: 0,
            isPastWeek: false,
            today: wednesday,
            calendar: cal,
            plannedSlotCount: { cal.startOfDay(for: $0) < today ? 0 : 1 }
        ))
    }
}
