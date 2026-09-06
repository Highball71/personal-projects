//
//  Round2RegressionTests.swift
//  Family Meal PlannerTests
//
//  Regressions from the Codex round-2 photo-import review (2026-09-06,
//  "Photo review round 2/Review.md"), replayed offline from the saved
//  round-2 responses in PhotoImportFixtures/round2/:
//    1. P12/P13 aborted decoding on JSON null amount/unit.
//    2. P11's packages became "to taste" because printedAmount
//       ("1 bag (14 ounces)") wins as the parsing string and the
//       parser had no container handling there.
//    3. Ingredient notes vanished on the way to the grocery list.
//    4. Section labels folded into names split grocery identity.
//

import XCTest
@testable import Family_Meal_Planner

// MARK: - Fixes 1 + 2: decoding and container parsing (pure, offline)

final class Round2RegressionTests: XCTestCase {

    /// Decode a saved raw proxy response exactly the way the app does:
    /// envelope → first text block → RecipeResponseParser. P13's
    /// response also carries a leading thinking block, which
    /// extractText must skip.
    private func recipeFromRawResponse(_ fixture: String) throws -> ExtractedRecipe {
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: PhotoImportFixtures.data(fixture))
        let text = try AnthropicClient.extractText(from: response)
        return try RecipeResponseParser.parse(response: text)
    }

    // MARK: Fix 1 — null amounts decode

    @MainActor
    func testP12NullAmountResponseDecodesAndConverts() throws {
        let recipe = try recipeFromRawResponse("P12-response-1")
        XCTAssertEqual(recipe.ingredients.count, 11)

        let form = SupabaseRecipeFormViewModel()
        form.populateFrom(recipe)
        XCTAssertEqual(form.ingredientRows.count, 11)

        let oil = try XCTUnwrap(form.ingredientRows.first { $0.name.localizedCaseInsensitiveContains("sesame oil") })
        XCTAssertEqual(oil.unit, .toTaste, "Null amount/unit = unspecified = to-taste row")
        XCTAssertEqual(oil.quantityText, "")
        XCTAssertFalse(oil.quantity == 1 && oil.unit == .piece)
    }

    @MainActor
    func testP13NullAmountResponseDecodesAndConverts() throws {
        let recipe = try recipeFromRawResponse("P13-response-1")
        XCTAssertEqual(recipe.ingredients.count, 11)

        let form = SupabaseRecipeFormViewModel()
        form.populateFrom(recipe)

        let parsley = try XCTUnwrap(form.ingredientRows.first { $0.name.localizedCaseInsensitiveContains("parsley") })
        XCTAssertEqual(parsley.unit, .toTaste)
        XCTAssertEqual(parsley.quantityText, "")
    }

    // MARK: Fix 2 — containers survive whichever field carries them

    /// P11's live response put the container phrase in printedAmount
    /// ("1 bag (14 ounces)") with the CONTENTS in amount/unit
    /// ("14 ounces"). The container must win: count 1, container unit,
    /// size in note — not a "to taste" row.
    @MainActor
    func testP11ResponsePackagesKeepContainerUnits() throws {
        let recipe = try recipeFromRawResponse("P11-response-1")
        let form = SupabaseRecipeFormViewModel()
        form.populateFrom(recipe)

        let bag = try XCTUnwrap(form.ingredientRows.first { $0.name.contains("bell pepper and onion blend") })
        XCTAssertEqual(bag.quantity, 1)
        XCTAssertEqual(bag.unit, .bag)
        XCTAssertEqual(bag.note?.contains("14 ounces"), true, "got \(bag.note ?? "nil")")

        let can = try XCTUnwrap(form.ingredientRows.first { $0.name.contains("diced tomatoes") })
        XCTAssertEqual(can.quantity, 1)
        XCTAssertEqual(can.unit, .can)
        XCTAssertEqual(can.note?.contains("14.5 ounces"), true, "got \(can.note ?? "nil")")
    }

    /// P13's live response used the other shape — container in the
    /// unit ("package (14.4 ounces)"), printedAmount "1".
    @MainActor
    func testP13ResponsePackageKeepsContainerUnit() throws {
        let recipe = try recipeFromRawResponse("P13-response-1")
        let form = SupabaseRecipeFormViewModel()
        form.populateFrom(recipe)

        let package = try XCTUnwrap(form.ingredientRows.first { $0.name.contains("pepper stir-fry blend") })
        XCTAssertEqual(package.quantity, 1)
        XCTAssertEqual(package.unit, .package)
        XCTAssertEqual(package.note?.contains("14.4 ounces"), true, "got \(package.note ?? "nil")")
    }

    func testContainerExpressionParser() {
        let bag = ExtractedIngredient.parseContainerExpression(from: "1 bag (14 ounces)")
        XCTAssertEqual(bag?.count, 1)
        XCTAssertEqual(bag?.unit, .bag)
        XCTAssertEqual(bag?.size, "14 ounces")

        let cans = ExtractedIngredient.parseContainerExpression(from: "2 cans (14.5 ounces)")
        XCTAssertEqual(cans?.count, 2)
        XCTAssertEqual(cans?.unit, .can)

        // Non-containers must never match.
        XCTAssertNil(ExtractedIngredient.parseContainerExpression(from: "1 1/2 pounds"))
        XCTAssertNil(ExtractedIngredient.parseContainerExpression(from: "to taste"))
        XCTAssertNil(ExtractedIngredient.parseContainerExpression(from: ""))
    }

    func testNullAmountAndUnitDecodeAsUnspecified() throws {
        let json = #"{"name":"Toasted sesame oil","amount":null,"unit":null,"printedAmount":null}"#
        let ingredient = try JSONDecoder().decode(ExtractedIngredient.self, from: Data(json.utf8))
        XCTAssertNil(ingredient.amount)
        XCTAssertNil(ingredient.unit)
        XCTAssertEqual(ingredient.parsedQuantity, .unspecified)
    }

    // MARK: Fix 3/4 helpers — note joining

    func testJoinedNotesNeverOverwritesOrDuplicates() {
        XCTAssertEqual(GroceryMerge.joinedNotes(existing: "1¼ to 1½ lb", incoming: "14 ounces"),
                       "1¼ to 1½ lb; 14 ounces", "Differing notes join with \"; \"")
        XCTAssertEqual(GroceryMerge.joinedNotes(existing: "1¼ to 1½ lb", incoming: "1¼ to 1½ lb"),
                       "1¼ to 1½ lb", "Identical notes don't stack")
        XCTAssertEqual(GroceryMerge.joinedNotes(existing: nil, incoming: "14 ounces"), "14 ounces")
        XCTAssertEqual(GroceryMerge.joinedNotes(existing: "kept", incoming: nil), "kept")
        XCTAssertNil(GroceryMerge.joinedNotes(existing: nil, incoming: nil))
    }
}

// MARK: - Fixes 3 + 4: grocery flow (fake PostgREST backend, no network)

final class Round2GroceryFlowTests: XCTestCase {

    private static let householdID = UUID()

    override func setUp() async throws {
        FakePostgRESTStore.shared.reset()
        URLProtocol.registerClass(FakePostgRESTProtocol.self)
        await MainActor.run {
            SupabaseManager.shared.setCurrentHousehold(Self.householdID)
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            SupabaseManager.shared.setCurrentHousehold(nil)
        }
        URLProtocol.unregisterClass(FakePostgRESTProtocol.self)
        FakePostgRESTStore.shared.reset()
    }

    /// Fix 3: plan the round-2 P04 form snapshot (its saved ingredient
    /// rows, notes included) and the grocery row for the meat must
    /// carry the range note — the review found notes vanished between
    /// recipe_ingredients and grocery_items.
    @MainActor
    func testPlannedP04MealCarriesRangeNoteToGroceries() async throws {
        let snapshot = try XCTUnwrap(
            JSONSerialization.jsonObject(with: PhotoImportFixtures.data("P04-form-and-usage")) as? [String: Any]
        )
        let ingredients = try XCTUnwrap(snapshot["ingredients"] as? [[String: Any]])
        XCTAssertEqual(ingredients.count, 15, "Snapshot ground truth")

        let recipeID = UUID()
        FakePostgRESTStore.shared.seed(table: "recipe_ingredients", rows: ingredients.enumerated().map { index, ing in
            var row: [String: Any] = [
                "id": UUID().uuidString.lowercased(),
                "recipe_id": recipeID.uuidString.lowercased(),
                "name": ing["name"] as? String ?? "",
                "quantity": ing["quantity"] as? Double ?? 1,
                "unit": ing["unit"] as? String ?? "",
                "sort_order": index,
            ]
            if let note = ing["note"] as? String, !note.isEmpty { row["note"] = note }
            return row
        })

        let recipe = try TestFixtures.recipeRow(
            id: recipeID, householdID: Self.householdID,
            name: snapshot["name"] as? String ?? "P04"
        )
        let planID = await MealPlanService().addMealWithGroceries(
            recipe: recipe, on: Date(),
            recipeService: RecipeService(), groceryService: GroceryService()
        )
        XCTAssertNotNil(planID, "Planning against the fake backend should succeed")

        let meatRow = try XCTUnwrap(
            FakePostgRESTStore.shared.rows(in: "grocery_items")
                .first { ($0["name"] as? String)?.contains("beef sirloin") == true }
        )
        XCTAssertEqual(meatRow["note"] as? String, "1¼ to 1½ lb",
                       "The printed range reaches the shopping list")
        XCTAssertEqual(meatRow["quantity"] as? Double, 1.5)
    }

    /// Fix 4: the same pantry item under two section headers of one
    /// recipe — and a plain row from another recipe — all land on ONE
    /// grocery row now that sections live in note, not the name.
    @MainActor
    func testSectionedOliveOilMergesAcrossSectionsAndRecipes() async throws {
        let recipe = ExtractedRecipe(
            name: "Two-Section Test", category: "dinner", servingSize: "4",
            prepTime: nil, cookTime: nil,
            ingredients: [
                ExtractedIngredient(name: "olive oil", amount: "2", unit: "tablespoons", section: "Marinade"),
                ExtractedIngredient(name: "olive oil", amount: "1", unit: "tablespoon", section: "Dressing"),
            ],
            instructions: ["Step"], source: nil
        )
        let rows = recipe.ingredientFormRows
        XCTAssertEqual(rows[0].name, "olive oil", "Section stays out of the name")
        XCTAssertEqual(rows[0].note, "Marinade")
        XCTAssertEqual(rows[1].note, "Dressing")

        let groceryService = GroceryService()
        let sameRecipe = await groceryService.addItems(rows.map { row in
            GroceryItemInsert(
                householdID: Self.householdID, name: row.name,
                quantity: row.quantity, unit: row.unit.rawValue, note: row.note
            )
        })
        XCTAssertTrue(sameRecipe)
        let otherRecipe = await groceryService.addItems([
            GroceryItemInsert(householdID: Self.householdID, name: "Olive Oil", quantity: 1, unit: "tbsp")
        ])
        XCTAssertTrue(otherRecipe)

        let groceryRows = FakePostgRESTStore.shared.rows(in: "grocery_items")
        XCTAssertEqual(groceryRows.count, 1, "Two sections + another recipe = one pantry row")
        XCTAssertEqual(groceryRows.first?["quantity"] as? Double ?? 0, 4, accuracy: 0.0001,
                       "2 + 1 + 1 tbsp")
        XCTAssertEqual(groceryRows.first?["note"] as? String, "Marinade; Dressing",
                       "Section context joined, never dropped")
    }
}
