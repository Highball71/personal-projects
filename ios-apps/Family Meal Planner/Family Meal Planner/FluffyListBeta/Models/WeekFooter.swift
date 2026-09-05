//
//  WeekFooter.swift
//  FluffyList
//
//  Visibility rule for the week view's planning footer — the
//  seasonal strip (or the region prompt standing in for it) and
//  "Copy last week", which live below the day rows now that the
//  special-cased "wide open" empty-week state is gone (2026-09-04).
//  Pure and injectable (WeekSummary-style) so the slot math is
//  unit-testable without SwiftUI.
//
//  The rule (widened same day it shipped): the footer shows whenever
//  any SLOT in the displayed week is still open on a day that is
//  today or later — the household slot or any member's — and the
//  week isn't past. This is the old "Copy last week" gate's breadth
//  (hasOpenFutureDay): a family that plans per person can still have
//  somewhere to put a meal after every household night is filled, so
//  the footer stays. A week with every slot taken is settled; a past
//  week is read-only and its quiet note already says so.
//
//  (The first cut keyed off WeekSummary's open-NIGHT count instead,
//  which hid the footer while member slots remained — that narrowing
//  bit exactly the per-person households the slots exist for.)
//

import Foundation

enum WeekFooter {

    /// Whether the planning footer renders under the day rows.
    ///
    /// `plannedSlotCount` is the number of meal rows on a date; a
    /// day is open while that count is below 1 + memberCount (the
    /// household slot plus one per member — the same capacity rule
    /// the picker plans against). `today` and `calendar` are
    /// injectable for tests.
    static func isVisible(
        weekDates: [Date],
        memberCount: Int,
        isPastWeek: Bool,
        today: Date = Date(),
        calendar: Calendar = .current,
        plannedSlotCount: (Date) -> Int
    ) -> Bool {
        guard !isPastWeek else { return false }
        let todayStart = calendar.startOfDay(for: today)
        let slotCapacity = 1 + memberCount
        return weekDates.contains { date in
            calendar.startOfDay(for: date) >= todayStart
                && plannedSlotCount(date) < slotCapacity
        }
    }
}
