//
//  PhotoImportFixtures.swift
//  Family Meal PlannerTests
//
//  Loads the saved photo-import evidence from the 2026-09-06 test task
//  (build 119): real extraction results captured from the Claude Vision
//  API, bundled under PhotoImportFixtures/. All fixture-driven tests run
//  fully offline against these files.

import Foundation
import XCTest
@testable import Family_Meal_Planner

/// Anchor class for Bundle(for:) — the fixtures live in the test bundle.
private final class FixtureBundleToken {}

enum PhotoImportFixtures {

    static func data(_ name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: FixtureBundleToken.self).url(forResource: name, withExtension: "json"),
            "Fixture \(name).json is missing from the test bundle"
        )
        return try Data(contentsOf: url)
    }

    static func text(_ name: String) throws -> String {
        try XCTUnwrap(String(data: data(name), encoding: .utf8))
    }

    /// Decode a baseline/diagnostic extraction result as the model the
    /// app parses API responses into.
    static func extractedRecipe(_ name: String) throws -> ExtractedRecipe {
        try JSONDecoder().decode(ExtractedRecipe.self, from: data(name))
    }

    /// The ten form snapshots captured on build 119 (pre-fix output of
    /// populateFrom for every fixture).
    static func betaFormSnapshots() throws -> [[String: Any]] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: data("Beta-form-conversion")) as? [[String: Any]]
        )
    }
}
