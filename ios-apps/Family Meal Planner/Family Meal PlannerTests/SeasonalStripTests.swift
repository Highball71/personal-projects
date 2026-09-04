//
//  SeasonalStripTests.swift
//  Family Meal PlannerTests
//
//  The empty-week seasonal strip: which recipes it shows (picker
//  ranking, deduped by name, capped at four, dormant without a
//  region) and which night a tap plans for (the displayed week's
//  first day that is today or later; nil on a fully past week, so
//  the strip hides itself at the model level too).
//

import XCTest
@testable import Family_Meal_Planner

final class SeasonalStripTests: XCTestCase {

    private let householdID = UUID()

    /// An August-ish produce cell (same shape as SeasonalMatchTests).
    private let august = SeasonalProduce(
        peak: ["tomato", "sweet corn", "basil", "peach"],
        available: ["onion", "garlic", "kale", "apple"]
    )

    private var calendar: SeasonalCalendar {
        SeasonalCalendar(regions: ["northeast": ["8": august]])
    }

    private func recipe(_ name: String) throws -> RecipeRow {
        try TestFixtures.recipeRow(householdID: householdID, name: name)
    }

    // MARK: - Recipe selection

    /// The strip keeps the shelf's ranking (best score first) and
    /// caps at four even when more recipes qualify.
    func testStripKeepsRankingAndCapsAtFour() throws {
        // One two-peak recipe that must lead, then five one-peak ones.
        let lead = try recipe("Tomato and Basil Salad")
        let rest = try (1...5).map { try recipe("Peach Dish \($0)") }
        let picks = SeasonalStrip.picks(
            recipes: rest + [lead],
            ingredientsByRecipeID: [:],
            region: .northeast,
            month: 8,
            calendar: calendar
        )
        XCTAssertEqual(picks.count, SeasonalStrip.cap)
        XCTAssertEqual(picks.first?.recipe.id, lead.id,
                       "the strip leads with the best seasonal match")
    }

    /// Repeat imports create same-name rows with different ids; the
    /// strip shows each name once, keeping the best-ranked occurrence
    /// and back-filling with the next distinct recipe.
    func testStripDeduplicatesByNormalizedName() throws {
        let dupA = try recipe("Peach Crumble")
        let dupB = try recipe("  peach crumble ")
        let other = try recipe("Corn on the Cob")
        let picks = SeasonalStrip.picks(
            recipes: [dupA, dupB, other],
            ingredientsByRecipeID: [other.id: ["sweet corn"]],
            region: .northeast,
            month: 8,
            calendar: calendar
        )
        XCTAssertEqual(picks.count, 2)
        let names = picks.map { $0.recipe.name.trimmingCharacters(in: .whitespaces).lowercased() }
        XCTAssertEqual(Set(names), ["peach crumble", "corn on the cob"])
    }

    /// The dedup back-fills past the duplicate: four DISTINCT names
    /// even when the top scorers include a repeated one.
    func testStripBackfillsPastDuplicates() throws {
        // Two copies of the strongest recipe, plus four distinct ones.
        let dup1 = try recipe("Tomato Basil Peach Feast")
        let dup2 = try recipe("Tomato Basil Peach Feast")
        let distinct = try ["Tomato Tart", "Basil Pesto", "Peach Salad", "Kale and Apple Slaw"]
            .map { try recipe($0) }
        let picks = SeasonalStrip.picks(
            recipes: [dup1, dup2] + distinct,
            ingredientsByRecipeID: [:],
            region: .northeast,
            month: 8,
            calendar: calendar
        )
        XCTAssertEqual(picks.count, 4)
        XCTAssertEqual(Set(picks.map(\.recipe.name)).count, 4,
                       "four rows means four distinct names")
        XCTAssertEqual(picks.first?.recipe.name, "Tomato Basil Peach Feast")
    }

    /// No region set (or no calendar) → empty strip, exactly like the
    /// picker's shelf — the view hides an empty strip entirely.
    func testStripIsDormantWithoutRegion() throws {
        let r = try recipe("Tomato Salad")
        XCTAssertTrue(SeasonalStrip.picks(
            recipes: [r],
            ingredientsByRecipeID: [:],
            region: nil,
            month: 8,
            calendar: calendar
        ).isEmpty)
        XCTAssertTrue(SeasonalStrip.picks(
            recipes: [r],
            ingredientsByRecipeID: [:],
            region: .northeast,
            month: 8,
            calendar: nil
        ).isEmpty)
    }

    // MARK: - First open night

    private let cal = Calendar.current

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func week(startingAt start: Date) -> [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    /// Mid-week on the current week: the first open night is TODAY —
    /// tonight can still be planned.
    func testFirstOpenNightMidCurrentWeekIsToday() {
        let weekDates = week(startingAt: date(2026, 8, 30))    // Sun Aug 30
        let today = date(2026, 9, 2)                           // Wed
        XCTAssertEqual(
            SeasonalStrip.firstOpenNight(weekDates: weekDates, today: today, calendar: cal),
            date(2026, 9, 2)
        )
    }

    /// Today counts as open even late in the day — the comparison is
    /// on start-of-day, not the clock.
    func testFirstOpenNightUsesStartOfDay() {
        let weekDates = week(startingAt: date(2026, 8, 30))
        let lateToday = cal.date(
            bySettingHour: 23, minute: 30, second: 0, of: date(2026, 9, 2))!
        XCTAssertEqual(
            SeasonalStrip.firstOpenNight(weekDates: weekDates, today: lateToday, calendar: cal),
            date(2026, 9, 2)
        )
    }

    /// A fully future week opens on its first day.
    func testFirstOpenNightOfFutureWeekIsItsFirstDay() {
        let weekDates = week(startingAt: date(2026, 9, 13))    // next week
        let today = date(2026, 9, 2)
        XCTAssertEqual(
            SeasonalStrip.firstOpenNight(weekDates: weekDates, today: today, calendar: cal),
            date(2026, 9, 13)
        )
    }

    /// A fully past week has no open night — the strip hides.
    func testFirstOpenNightOfPastWeekIsNil() {
        let weekDates = week(startingAt: date(2026, 8, 16))
        let today = date(2026, 9, 2)
        XCTAssertNil(
            SeasonalStrip.firstOpenNight(weekDates: weekDates, today: today, calendar: cal)
        )
    }
}
