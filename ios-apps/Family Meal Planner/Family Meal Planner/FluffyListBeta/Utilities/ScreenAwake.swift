//
//  ScreenAwake.swift
//  FluffyList
//
//  Keeps the screen awake while a recipe is on the stand: Recipe
//  Detail begins a hold on appear and ends it on disappear, and the
//  idle timer is disabled while any hold is open. Hold-COUNTING
//  (rather than a bare on/off) means stacked details — or any future
//  second screen that wants the same — can't fight each other:
//  the timer is only restored when the last hold ends.
//
//  The UIApplication write is injected so the counting logic is
//  unit-testable without UIKit. Nothing outside Recipe Detail should
//  call this (phase 1 rule: nowhere else).
//

import UIKit

@MainActor
final class ScreenAwake {

    /// The app-wide instance, wired to the real idle timer.
    static let shared = ScreenAwake { disabled in
        UIApplication.shared.isIdleTimerDisabled = disabled
    }

    private let setIdleTimerDisabled: (Bool) -> Void
    private(set) var holdCount = 0

    init(setIdleTimerDisabled: @escaping (Bool) -> Void) {
        self.setIdleTimerDisabled = setIdleTimerDisabled
    }

    /// Open a hold — disables the idle timer if this is the first.
    func begin() {
        holdCount += 1
        if holdCount == 1 { setIdleTimerDisabled(true) }
    }

    /// Close a hold — restores the idle timer when the last one ends.
    /// Unbalanced ends clamp at zero rather than going negative (a
    /// stray extra onDisappear must not poison the next begin).
    func end() {
        guard holdCount > 0 else { return }
        holdCount -= 1
        if holdCount == 0 { setIdleTimerDisabled(false) }
    }
}
