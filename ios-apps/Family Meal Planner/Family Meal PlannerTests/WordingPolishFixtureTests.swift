//
//  WordingPolishFixtureTests.swift
//  Family Meal PlannerTests
//
//  One test per size/slice wording issue flagged in the Codex round-3
//  review ("Photo review round 3/Review.md", Remaining limitations 1
//  and 3), replayed from the round-2 fixtures in
//  PhotoImportFixtures/round2/. Each asserts the EXACT rendered row
//  string through the shared IngredientDisplay formatter.
//

import XCTest
@testable import Family_Meal_Planner

@MainActor
final class WordingPolishFixtureTests: XCTestCase {

    /// Convert a round-2 extraction fixture and render one row's text
    /// the way both the recipe-detail and grocery rows now do.
    private func renderedRow(fixture: String, nameFragment: String) throws -> (row: IngredientFormData, text: String) {
        let extracted = try PhotoImportFixtures.extractedRecipe(fixture)
        let form = SupabaseRecipeFormViewModel()
        form.populateFrom(extracted)
        let row = try XCTUnwrap(
            form.ingredientRows.first { $0.name.localizedCaseInsensitiveContains(nameFragment) },
            "\(fixture) should contain \(nameFragment)"
        )
        let text = IngredientDisplay.render(
            quantity: row.quantity, unit: row.unit.rawValue, note: row.note
        ).combined
        return (row, text)
    }

    /// P02: printed "1 small pineapple" — "small" used to vanish when
    /// the unit fell back to piece ("1 piece").
    func testP02SmallPineapple() throws {
        // Exact name — "unsweetened pineapple juice" must not match.
        let extracted = try PhotoImportFixtures.extractedRecipe("P02-extracted")
        let form = SupabaseRecipeFormViewModel()
        form.populateFrom(extracted)
        let row = try XCTUnwrap(form.ingredientRows.first { $0.name == "pineapple" })
        let text = IngredientDisplay.render(
            quantity: row.quantity, unit: row.unit.rawValue, note: row.note
        ).combined
        XCTAssertEqual(row.unit, .piece, "Stored unit is untouched")
        XCTAssertEqual(text, "1 small · peeled, cored, and cut into 1½-inch chunks",
                       "Size word on the label, preparation in the detail part")
    }

    /// P10: printed "4 medium portobello mushrooms" under "For the
    /// Mushrooms" — used to render "4 piece".
    func testP10MediumMushrooms() throws {
        let (_, text) = try renderedRow(fixture: "P10-extracted", nameFragment: "portobello")
        XCTAssertEqual(text, "4 medium · For the Mushrooms")
    }

    /// P11: printed "1 medium rutabaga" — grocery row used to read
    /// "1 piece + spiralized or diced".
    func testP11MediumRutabaga() throws {
        let (_, text) = try renderedRow(fixture: "P11-extracted", nameFragment: "rutabaga")
        XCTAssertEqual(text, "1 medium · spiralized or diced")
    }

    /// P15: printed "8 slices bacon" — grocery row used to read
    /// "8 piece + For the Casserole".
    func testP15BaconSlices() throws {
        let (_, text) = try renderedRow(fixture: "P15-extracted", nameFragment: "bacon")
        XCTAssertEqual(text, "8 slices · For the Casserole")
    }

    /// P11 packages (round-3 limitation 3: notes after " + " read like
    /// extra quantities) — containers now render "1 bag (14 oz)".
    func testP11PackagesRenderContainerStyle() throws {
        let (_, bag) = try renderedRow(fixture: "P11-extracted", nameFragment: "bell pepper and onion blend")
        XCTAssertEqual(bag, "1 bag (14 oz)")

        let (_, can) = try renderedRow(fixture: "P11-extracted", nameFragment: "diced tomatoes")
        XCTAssertEqual(can, "1 can (14.5 oz)")
    }

    /// P13's package arrived with the container in the unit field
    /// ("package (14.4 ounces)") — same rendered style.
    func testP13PackageRendersContainerStyle() throws {
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: PhotoImportFixtures.data("P13-response-1"))
        let recipe = try RecipeResponseParser.parse(response: AnthropicClient.extractText(from: response))
        let form = SupabaseRecipeFormViewModel()
        form.populateFrom(recipe)

        let row = try XCTUnwrap(form.ingredientRows.first { $0.name.contains("pepper stir-fry blend") })
        let text = IngredientDisplay.render(quantity: row.quantity, unit: row.unit.rawValue, note: row.note).combined
        XCTAssertEqual(text, "1 package (14.4 oz)")
    }

    /// P04's meat on the grocery list (from the round-2 form snapshot,
    /// the exact stored shape): the range note follows " · ", no
    /// longer " + " where it read like an added quantity.
    func testP04MeatGroceryRowSeparator() throws {
        let snapshot = try XCTUnwrap(
            JSONSerialization.jsonObject(with: PhotoImportFixtures.data("P04-form-and-usage")) as? [String: Any]
        )
        let ingredients = try XCTUnwrap(snapshot["ingredients"] as? [[String: Any]])
        let meat = try XCTUnwrap(ingredients.first { ($0["name"] as? String)?.contains("beef sirloin") == true })

        let text = IngredientDisplay.render(
            quantity: meat["quantity"] as? Double ?? 0,
            unit: meat["unit"] as? String ?? "",
            note: meat["note"] as? String
        ).combined
        XCTAssertEqual(text, "1 1/2 lb · 1¼ to 1½ lb")
    }
}
