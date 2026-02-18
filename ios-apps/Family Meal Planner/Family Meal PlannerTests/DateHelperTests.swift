//
//  DateHelperTests.swift
//  Family Meal PlannerTests
//

import XCTest
@testable import Family_Meal_Planner

final class DateHelperTests: XCTestCase {

    // MARK: - Helpers

    /// Create a date from components for deterministic tests.
    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    // MARK: - startOfWeek

    func testStartOfWeekFromMidweek() {
        // Wednesday Feb 12, 2025 → should snap back to the start of that week
        let wednesday = makeDate(year: 2025, month: 2, day: 12)
        let start = DateHelper.startOfWeek(containing: wednesday)
        let weekday = Calendar.current.component(.weekday, from: start)
        // Should be the locale's first day of week (Sunday=1 in US)
        XCTAssertEqual(weekday, Calendar.current.firstWeekday)
    }

    func testStartOfWeekIdempotent() {
        // Applying startOfWeek twice should give the same result
        let date = makeDate(year: 2025, month: 2, day: 12)
        let first = DateHelper.startOfWeek(containing: date)
        let second = DateHelper.startOfWeek(containing: first)
        XCTAssertEqual(first, second)
    }

    func testStartOfWeekFromSaturday() {
        let saturday = makeDate(year: 2025, month: 2, day: 15)
        let start = DateHelper.startOfWeek(containing: saturday)
        let weekday = Calendar.current.component(.weekday, from: start)
        XCTAssertEqual(weekday, Calendar.current.firstWeekday)
    }

    // MARK: - weekDays

    func testWeekDaysReturns7() {
        let start = makeDate(year: 2025, month: 2, day: 9)
        let days = DateHelper.weekDays(startingFrom: start)
        XCTAssertEqual(days.count, 7)
    }

    func testWeekDaysConsecutive() {
        let start = makeDate(year: 2025, month: 2, day: 9)
        let days = DateHelper.weekDays(startingFrom: start)
        for i in 1..<days.count {
            let diff = Calendar.current.dateComponents([.day], from: days[i-1], to: days[i]).day!
            XCTAssertEqual(diff, 1, "Day \(i) should be exactly 1 day after day \(i-1)")
        }
    }

    func testWeekDaysStartsFromGivenDate() {
        let start = makeDate(year: 2025, month: 2, day: 9)
        let days = DateHelper.weekDays(startingFrom: start)
        let startDay = Calendar.current.component(.day, from: days[0])
        XCTAssertEqual(startDay, 9)
    }

    // MARK: - stripTime

    func testStripTimeSameDayBecomesEqual() {
        let morning = makeDate(year: 2025, month: 2, day: 8, hour: 10, minute: 30)
        let evening = makeDate(year: 2025, month: 2, day: 8, hour: 22, minute: 15)
        XCTAssertEqual(DateHelper.stripTime(from: morning), DateHelper.stripTime(from: evening))
    }

    func testStripTimeDifferentDaysStayDifferent() {
        let day1 = makeDate(year: 2025, month: 2, day: 8, hour: 10)
        let day2 = makeDate(year: 2025, month: 2, day: 9, hour: 10)
        XCTAssertNotEqual(DateHelper.stripTime(from: day1), DateHelper.stripTime(from: day2))
    }

    // MARK: - shortDayName

    func testShortDayNameFormat() {
        // Sunday Feb 9, 2025
        let sunday = makeDate(year: 2025, month: 2, day: 9)
        let name = DateHelper.shortDayName(for: sunday)
        // Should be a 3-letter abbreviation
        XCTAssertEqual(name.count, 3)
        XCTAssertEqual(name, "Sun")
    }

    // MARK: - dayMonth

    func testDayMonthFormat() {
        let date = makeDate(year: 2025, month: 2, day: 8)
        let result = DateHelper.dayMonth(for: date)
        XCTAssertEqual(result, "Feb 8")
    }

    func testDayMonthDoubleDigitDay() {
        let date = makeDate(year: 2025, month: 12, day: 25)
        let result = DateHelper.dayMonth(for: date)
        XCTAssertEqual(result, "Dec 25")
    }
}
