//
//  ScreenAwakeTests.swift
//  Family Meal PlannerTests
//
//  The idle-timer keeper behind "the screen stays awake while Recipe
//  Detail is visible". The UIApplication write is injected, so these
//  tests pin the hold-counting contract without UIKit: first begin
//  disables the timer, last end restores it, nesting doesn't
//  double-fire, and a stray unbalanced end can't poison the next
//  begin.
//

import XCTest
@testable import Family_Meal_Planner

@MainActor
final class ScreenAwakeTests: XCTestCase {

    /// Every value passed to the injected idle-timer setter, in order.
    private var applied: [Bool] = []

    private func makeKeeper() -> ScreenAwake {
        applied = []
        return ScreenAwake { [weak self] disabled in
            self?.applied.append(disabled)
        }
    }

    func testBeginDisablesAndEndRestores() {
        let keeper = makeKeeper()
        keeper.begin()
        XCTAssertEqual(applied, [true], "appear disables the idle timer")
        keeper.end()
        XCTAssertEqual(applied, [true, false], "disappear restores it")
    }

    /// Two stacked holds (a detail pushed over a detail) apply the
    /// disable once and restore only when the LAST hold ends.
    func testNestedHoldsApplyOnceAndRestoreOnLastEnd() {
        let keeper = makeKeeper()
        keeper.begin()
        keeper.begin()
        XCTAssertEqual(applied, [true], "second hold must not re-apply")
        keeper.end()
        XCTAssertEqual(applied, [true], "timer stays off while a hold remains")
        keeper.end()
        XCTAssertEqual(applied, [true, false])
    }

    /// An unbalanced end clamps at zero: it neither writes anything
    /// nor steals the disable from a begin that follows.
    func testUnbalancedEndClampsAtZero() {
        let keeper = makeKeeper()
        keeper.end()
        XCTAssertEqual(applied, [], "an end with no hold writes nothing")
        keeper.begin()
        XCTAssertEqual(applied, [true], "the next begin still disables")
        keeper.end()
        XCTAssertEqual(applied, [true, false])
        XCTAssertEqual(keeper.holdCount, 0)
    }
}
