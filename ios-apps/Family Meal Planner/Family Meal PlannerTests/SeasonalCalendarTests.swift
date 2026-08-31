//
//  SeasonalCalendarTests.swift
//  Family Meal PlannerTests
//
//  Seasonal Suggestions v1: the bundled calendar is the heart of the
//  feature — these tests guard that it ships valid, complete (all
//  8 regions × 12 months), and in the lowercase-keyword shape
//  SeasonalMatch's tokenizer expects.
//

import XCTest
@testable import Family_Meal_Planner

final class SeasonalCalendarTests: XCTestCase {

    /// The bundled JSON decodes. (Tests are hosted in the app, so
    /// Bundle.main is the app bundle — the same load path production
    /// uses.)
    func testCalendarLoadsFromBundle() {
        XCTAssertNotNil(SeasonalCalendar.shared,
                        "SeasonalCalendar.json missing or malformed in the app bundle")
    }

    /// Every region × month cell exists and lists at least some
    /// produce. Peak may honestly be empty (a Northeast January has
    /// no peak harvest) but peak + available never is.
    func testAllNinetySixCellsPresentAndNonEmpty() throws {
        let calendar = try XCTUnwrap(SeasonalCalendar.shared)
        for region in USRegion.allCases {
            for month in 1...12 {
                let cell = calendar.produce(for: region, month: month)
                XCTAssertNotNil(cell, "\(region.rawValue)/\(month) missing")
                XCTAssertFalse(cell?.isEmpty ?? true,
                               "\(region.rawValue)/\(month) has no produce at all")
            }
        }
    }

    /// Keywords are lowercase, trimmed, and unique within a cell
    /// (an item must be peak or available, never both).
    func testProduceKeywordsAreCleanAndUnique() throws {
        let calendar = try XCTUnwrap(SeasonalCalendar.shared)
        for region in USRegion.allCases {
            for month in 1...12 {
                guard let cell = calendar.produce(for: region, month: month) else { continue }
                let all = cell.peak + cell.available
                for name in all {
                    XCTAssertFalse(name.isEmpty)
                    XCTAssertEqual(name, name.lowercased(),
                                   "\(region.rawValue)/\(month): '\(name)' not lowercase")
                    XCTAssertEqual(name, name.trimmingCharacters(in: .whitespaces),
                                   "\(region.rawValue)/\(month): '\(name)' has stray whitespace")
                }
                XCTAssertEqual(all.count, Set(all).count,
                               "\(region.rawValue)/\(month): duplicate produce entry")
            }
        }
    }

    /// Out-of-range months return nil instead of crashing.
    func testOutOfRangeMonthReturnsNil() throws {
        let calendar = try XCTUnwrap(SeasonalCalendar.shared)
        XCTAssertNil(calendar.produce(for: .northeast, month: 0))
        XCTAssertNil(calendar.produce(for: .northeast, month: 13))
    }
}
