//
//  WeekNavigation.swift
//  FluffyList
//
//  Week navigation for the Press week view: which weeks the arrows
//  and swipe can reach, whether the displayed week is read-only, and
//  the masthead title for each offset. Pure and injectable (like
//  WeekSummary) so the bounds, gating, and copy-source math are
//  unit-testable without SwiftUI.
//
//  The range (decided 2026-09-03): 4 weeks back, 2 weeks forward
//  from the CURRENT week — not from the displayed one, so the window
//  never drifts as you navigate. Past weeks are read-only: every day
//  in them is already gone, so assign/copy/replace/remove would all
//  be refused anyway; the view swaps those affordances for a quiet
//  inline note instead of letting each one fail loudly.
//

import Foundation

struct WeekNavigation: Equatable {
    /// How far the arrows reach, in whole weeks from the current one.
    static let weeksBack = 4
    static let weeksForward = 2

    /// Start of the displayed week (what the view is showing).
    let displayedWeekStart: Date
    /// Start of the week containing today — offset 0.
    let currentWeekStart: Date
    /// Displayed week's distance from the current week: -1 is last
    /// week, +1 is next week.
    let weekOffset: Int

    private let calendar: Calendar

    init(displayedWeekStart: Date, today: Date = Date(), calendar: Calendar = .current) {
        self.calendar = calendar
        self.displayedWeekStart = displayedWeekStart
        // Same week-start computation as DateHelper.startOfWeek, but
        // on the injected calendar so tests control the locale rules.
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: today)
        let current = calendar.date(from: components) ?? today
        self.currentWeekStart = current
        // Whole weeks between the two starts. Counting calendar days
        // (not seconds) keeps DST transitions from rounding a week to
        // six-and-a-bit days.
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: current),
            to: calendar.startOfDay(for: displayedWeekStart)
        ).day ?? 0
        self.weekOffset = days / 7
    }

    // MARK: - Bounds

    var canGoBack: Bool { weekOffset > -Self.weeksBack }
    var canGoForward: Bool { weekOffset < Self.weeksForward }

    /// Start of the week one back, nil at the lower bound — so the
    /// arrow and the swipe can both just "go to this if it exists".
    var previousWeekStart: Date? {
        guard canGoBack else { return nil }
        return calendar.date(byAdding: .weekOfYear, value: -1, to: displayedWeekStart)
    }

    /// Start of the week one forward, nil at the upper bound.
    var nextWeekStart: Date? {
        guard canGoForward else { return nil }
        return calendar.date(byAdding: .weekOfYear, value: 1, to: displayedWeekStart)
    }

    // MARK: - Gating

    var isCurrentWeek: Bool { weekOffset == 0 }

    /// A fully past week — every one of its days is before today, so
    /// the view renders it read-only.
    var isPastWeek: Bool { weekOffset < 0 }

    // MARK: - Copy source

    /// Where "Copy last week" copies FROM when this week is displayed:
    /// always the week immediately before the displayed one (the
    /// service's copyPreviousWeek(weekStart:) applies the same -7).
    var copySourceWeekStart: Date {
        calendar.date(byAdding: .day, value: -7, to: displayedWeekStart)
            ?? displayedWeekStart
    }

    // MARK: - Masthead title

    /// The masthead title for each offset. Named weeks read better in
    /// the Press's display face than a bare date (the dateline below
    /// already carries "WEEK OF SEP 14").
    var title: String {
        switch weekOffset {
        case 0: return "This Week"
        case -1: return "Last Week"
        case 1: return "Next Week"
        case 2: return "In Two Weeks"
        case -2: return "Two Weeks Ago"
        case -3: return "Three Weeks Ago"
        case -4: return "Four Weeks Ago"
        default: return "Week of " + Self.titleFormatter.string(from: displayedWeekStart)
        }
    }

    private static let titleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}
