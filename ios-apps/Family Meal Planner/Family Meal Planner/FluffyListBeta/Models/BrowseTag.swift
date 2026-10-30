//
//  BrowseTag.swift
//  FluffyList
//
//  The Recipes tab's "Browse by Category" chips (Chicken, Pasta, Fish,
//  Vegetarian, Pork, Soups). Lifted out of SupabaseRecipeListView so
//  the matching rules are unit-testable.
//
//  A chip names what the dish IS, not every ingredient it touches
//  (device pass 2026-10-29: "Chicken" listed Baby Back Ribs and pork
//  lettuce wraps because they use chicken broth). So:
//    - A protein chip matches the title, or an ingredient that is the
//      protein itself — never a broth, stock, bouillon, or seasoning
//      made from it (chicken stock, fish sauce, anchovy paste).
//    - Soups matches the title only. "broth" and "chili" in the
//      ingredients put every braise and every chili-powder recipe in
//      Soups.
//    - Vegetarian still looks everywhere — chicken broth DOES make a
//      dish not vegetarian — and knows more meats (ribs, chorizo…).
//    - Keywords match whole words (plus a plain plural), so "ham" no
//      longer matches hamburger or graham crackers, and "scallop" no
//      longer matches scalloped potatoes.
//  Free-text search is separate and still matches any ingredient.
//

import Foundation

enum BrowseTag: String, CaseIterable, Identifiable {
    case all        = "All"
    case chicken    = "Chicken"
    case pasta      = "Pasta"
    case fish       = "Fish"
    case vegetarian = "Vegetarian"
    case pork       = "Pork"
    case soups      = "Soups"

    var id: String { rawValue }

    // MARK: - Keywords

    private static let chickenWords = ["chicken", "poultry", "hen"]

    private static let pastaWords = [
        "pasta", "spaghetti", "penne", "linguine", "fettuccine",
        "macaroni", "noodle", "lasagna", "lasagne", "rigatoni", "orzo",
        "tortellini", "ravioli", "gnocchi", "ziti", "rotini", "farfalle",
        "angel hair", "mac and cheese"
    ]

    private static let fishWords = [
        "fish", "salmon", "tuna", "cod", "tilapia", "shrimp", "seafood",
        "prawn", "crab", "lobster", "scallop", "halibut", "mahi",
        "swordfish", "trout", "catfish", "haddock", "snapper", "sardine",
        "clam", "mussel", "oyster"
    ]

    private static let porkWords = [
        "pork", "bacon", "ham", "prosciutto", "pancetta", "carnitas",
        "baby back", "spare rib", "sparerib", "chorizo"
    ]

    /// "chili" is handled separately — see isSoupTitle.
    private static let soupWords = [
        "soup", "stew", "chowder", "bisque", "gumbo", "pho", "ramen",
        "minestrone", "gazpacho"
    ]

    /// Anything that makes a dish not vegetarian, broths included.
    private static let meatWords = [
        "chicken", "poultry", "beef", "steak", "pork", "bacon", "ham",
        "prosciutto", "pancetta", "sausage", "chorizo", "pepperoni",
        "salami", "turkey", "lamb", "veal", "duck", "venison", "bison",
        "baby back", "spare rib", "sparerib", "short rib", "prime rib",
        "brisket", "meatball", "meat", "carnitas", "lard", "gelatin",
        "anchovy", "anchovies"
    ] + fishWords
    // Not plain "rib": "2 celery ribs" is in half the soups.

    /// Ingredient words that mean "made from the protein", not the
    /// protein itself: chicken broth, fish sauce, shrimp paste.
    private static let derivedWords = [
        "broth", "stock", "bouillon", "base", "consomme", "consommé",
        "sauce", "paste", "juice", "grease", "drippings", "gravy",
        "seasoning", "flavoring"
    ]

    // MARK: - Matching

    /// Whether a recipe belongs under this chip. `ingredientNames` are
    /// the recipe's ingredient names (any case).
    func matches(_ recipe: RecipeRow, ingredientNames: [String]?) -> Bool {
        let title = recipe.name.lowercased()
        let ingredients = (ingredientNames ?? []).map { $0.lowercased() }

        switch self {
        case .all:
            return true
        case .chicken:
            return Self.isMainProtein(Self.chickenWords, title: title, ingredients: ingredients)
        case .pasta:
            return Self.isMainProtein(Self.pastaWords, title: title, ingredients: ingredients)
        case .fish:
            return Self.isMainProtein(Self.fishWords, title: title, ingredients: ingredients)
        case .pork:
            return Self.isMainProtein(Self.porkWords, title: title, ingredients: ingredients)
        case .soups:
            return Self.isSoupTitle(title)
        case .vegetarian:
            return !Self.containsWord(title, anyOf: Self.meatWords)
                && !ingredients.contains { Self.containsWord($0, anyOf: Self.meatWords) }
        }
    }

    /// The title names it, or some ingredient IS it (not a broth,
    /// sauce, or other product made from it).
    private static func isMainProtein(
        _ words: [String],
        title: String,
        ingredients: [String]
    ) -> Bool {
        if containsWord(title, anyOf: words) { return true }
        return ingredients.contains { ingredient in
            containsWord(ingredient, anyOf: words)
                && !containsWord(ingredient, anyOf: derivedWords)
        }
    }

    /// Soups go by title alone. "Chili" is the dish only as the title's
    /// last word or in "chili con carne" — "Sweet Chili Shrimp" and
    /// "Chili-Lime Chicken" are not soups.
    private static func isSoupTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if containsWord(trimmed, anyOf: soupWords) { return true }
        return trimmed.range(of: "\\bchili(e?s)?$", options: .regularExpression) != nil
            || containsWord(trimmed, anyOf: ["chili con carne"])
    }

    /// True when `text` contains one of `words` as a whole word or
    /// phrase, optionally pluralized with "s" / "es" — "noodle" matches
    /// "egg noodles", "ham" doesn't match "hamburger".
    nonisolated static func containsWord(_ text: String, anyOf words: [String]) -> Bool {
        words.contains { word in
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "(e?s)?\\b"
            return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}
