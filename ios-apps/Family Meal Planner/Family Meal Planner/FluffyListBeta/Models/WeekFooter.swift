//
//  WeekFooter.swift
//  FluffyList
//
//  Visibility rule for the week view's planning footer — the
//  seasonal strip (or the region prompt standing in for it) and
//  "Copy last week", which live below the day rows now that the
//  special-cased "wide open" empty-week state is gone (2026-09-04).
//  Pure and one-line-testable, WeekSummary-style.
//
//  The rule: the footer shows whenever the displayed week still has
//  at least one OPEN night (WeekSummary's rule — today or later with
//  no household meal) and the week isn't past. A fully planned week
//  reads "The week is settled." and offers nothing to fill; a past
//  week is read-only and its quiet note already says so.
//
//  Note this deliberately retires the old "Copy last week" gate
//  (hasOpenFutureDay, which also counted open MEMBER slots): a week
//  whose seven household slots are full is settled, and copying into
//  leftover member slots from a settled page was a corner nobody
//  planned from. An open night implies an open household slot, so
//  inside a visible footer the copy link can always show.
//

import Foundation

enum WeekFooter {

    /// Whether the planning footer renders under the day rows.
    static func isVisible(openCount: Int, isPastWeek: Bool) -> Bool {
        !isPastWeek && openCount > 0
    }
}
