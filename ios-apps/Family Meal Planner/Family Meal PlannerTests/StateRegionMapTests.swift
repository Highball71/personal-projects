//
//  StateRegionMapTests.swift
//  Family Meal PlannerTests
//
//  US state → growing region for the "Use my location" flow: every
//  state and DC maps except Hawaii (deliberately unmapped — no honest
//  cell), full names and codes both work, case doesn't matter, and
//  anything unrecognized is nil (→ manual picker fallback).
//

import XCTest
@testable import Family_Meal_Planner

final class StateRegionMapTests: XCTestCase {

    /// One representative per region, by two-letter code.
    func testRepresentativeCodesMapToTheirRegions() {
        XCTAssertEqual(StateRegionMap.region(forState: "VT"), .northeast)
        XCTAssertEqual(StateRegionMap.region(forState: "MD"), .midAtlantic)
        XCTAssertEqual(StateRegionMap.region(forState: "NC"), .southeast)
        XCTAssertEqual(StateRegionMap.region(forState: "WI"), .midwest)
        XCTAssertEqual(StateRegionMap.region(forState: "NE"), .plains)
        XCTAssertEqual(StateRegionMap.region(forState: "NM"), .southwest)
        XCTAssertEqual(StateRegionMap.region(forState: "OR"), .pacificNorthwest)
        XCTAssertEqual(StateRegionMap.region(forState: "CA"), .california)
    }

    /// Reverse geocoding can hand back full names in some locales.
    func testFullNamesAndCaseInsensitivity() {
        XCTAssertEqual(StateRegionMap.region(forState: "North Carolina"), .southeast)
        XCTAssertEqual(StateRegionMap.region(forState: "district of columbia"), .midAtlantic)
        XCTAssertEqual(StateRegionMap.region(forState: "nY"), .northeast)
        XCTAssertEqual(StateRegionMap.region(forState: " Washington "), .pacificNorthwest)
    }

    /// The judgment calls, pinned: mountain states split by harvest
    /// character; Alaska joins the Pacific Northwest.
    func testMountainAndAlaskaAssignments() {
        XCTAssertEqual(StateRegionMap.region(forState: "CO"), .plains)
        XCTAssertEqual(StateRegionMap.region(forState: "MT"), .plains)
        XCTAssertEqual(StateRegionMap.region(forState: "UT"), .southwest)
        XCTAssertEqual(StateRegionMap.region(forState: "NV"), .southwest)
        XCTAssertEqual(StateRegionMap.region(forState: "ID"), .pacificNorthwest)
        XCTAssertEqual(StateRegionMap.region(forState: "AK"), .pacificNorthwest)
    }

    /// Hawaii is deliberately unmapped — by code AND by name — so the
    /// prompt falls back to the manual picker instead of guessing.
    func testHawaiiIsDeliberatelyUnmapped() {
        XCTAssertNil(StateRegionMap.region(forState: "HI"))
        XCTAssertNil(StateRegionMap.region(forState: "Hawaii"))
    }

    /// Territories, provinces, and junk are nil — manual fallback.
    func testUnknownInputsAreNil() {
        XCTAssertNil(StateRegionMap.region(forState: "PR"))
        XCTAssertNil(StateRegionMap.region(forState: "Ontario"))
        XCTAssertNil(StateRegionMap.region(forState: ""))
        XCTAssertNil(StateRegionMap.region(forState: "  "))
    }

    /// Completeness: all 50 states + DC resolve, except Hawaii.
    func testEveryStateAndDCIsCovered() {
        let codes = [
            "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL",
            "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME",
            "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH",
            "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI",
            "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI",
            "WY",
        ]
        XCTAssertEqual(codes.count, 51)
        for code in codes {
            let region = StateRegionMap.region(forState: code)
            if code == "HI" {
                XCTAssertNil(region)
            } else {
                XCTAssertNotNil(region, "\(code) should map to a region")
            }
        }
    }
}
