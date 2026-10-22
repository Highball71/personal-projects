//
//  PerishableIngredients.swift
//  FluffyList
//
//  Ingredient Chaining Phase 1: the bundled, hard-coded list of
//  perishables that the week-overlap badge looks for ("ALSO USES
//  CABBAGE, CILANTRO"). Seeded from the produce / protein / dairy
//  keyword lists in SupabaseGroceryListView's GroceryCategory (read,
//  not lifted — that enum stays private and unchanged).
//
//  Staples are deliberately left OUT: oil, salt, pepper, garlic,
//  onion (and shallot), spices, flour, sugar, vinegar, canned/dried
//  goods, rice, pasta, broth — plus butter and eggs, which keep for
//  weeks and sit in almost every fridge. "Also uses garlic" would
//  appear on nearly every recipe and stop meaning anything.
//
//  Unknown names are NOT perishable. Under-claim, never over-claim —
//  the same rule as the seasonal leaf: a missed badge costs nothing,
//  a wrong one makes the feature look broken.
//

import Foundation

enum PerishableIngredients {

    /// One perishable: the name the badge shows, the phrases that
    /// count as it, and phrases that look like it but aren't.
    struct Entry {
        /// Display name in the badge — "cabbage", "scallion".
        let name: String
        /// Word-boundary phrases that count as this perishable.
        /// "green onion" counts as scallion; "napa cabbage" as cabbage.
        let keywords: [String]
        /// Phrases that block this entry even when a keyword hits —
        /// "sweet potato" must not also count as "potato", and
        /// "ground ginger" is a spice, not the root.
        var excluding: [String] = []
    }

    /// Words that mark an ingredient as a shelf-stable form of
    /// something perishable — "chicken broth", "canned tomatoes",
    /// "dried basil", "frozen spinach", "coconut milk". Any one of
    /// these in an ingredient name means that ingredient contributes
    /// NO perishables at all. Compared after SeasonalMatch.tokens'
    /// plural fold, so "flakes" is listed as "flake".
    static let shelfStableWords: Set<String> = [
        "broth", "stock", "bouillon", "soup",
        "canned", "tinned", "jarred", "frozen",
        "dried", "dry", "powder", "powdered", "flake",
        "paste", "sauce", "extract", "seasoning",
        "evaporated", "condensed", "coconut",
        "chip", "starch", "syrup", "jam", "jelly", "preserve",
        "pickled", "pickle", "oil", "vinegar",
    ]

    static let entries: [Entry] = [
        // MARK: Protein
        Entry(name: "chicken", keywords: ["chicken"]),
        // Bare "steak" is left out — tuna and salmon come as steaks too.
        Entry(name: "beef", keywords: ["beef", "ground chuck", "sirloin", "brisket",
                                       "flank steak", "skirt steak", "ribeye"]),
        Entry(name: "pork", keywords: ["pork"]),
        Entry(name: "turkey", keywords: ["turkey"]),
        Entry(name: "lamb", keywords: ["lamb"]),
        Entry(name: "sausage", keywords: ["sausage", "chorizo", "kielbasa", "bratwurst"]),
        Entry(name: "bacon", keywords: ["bacon", "pancetta"]),
        Entry(name: "ham", keywords: ["ham"]),
        Entry(name: "salmon", keywords: ["salmon"]),
        Entry(name: "shrimp", keywords: ["shrimp", "prawn"]),
        Entry(name: "cod", keywords: ["cod"]),
        Entry(name: "tilapia", keywords: ["tilapia"]),
        Entry(name: "scallop", keywords: ["scallop"]),
        Entry(name: "tofu", keywords: ["tofu"]),
        Entry(name: "tempeh", keywords: ["tempeh"]),

        // MARK: Dairy
        Entry(name: "milk", keywords: ["milk", "whole milk", "skim milk"],
              excluding: ["almond milk", "oat milk", "soy milk"]),
        Entry(name: "buttermilk", keywords: ["buttermilk"]),
        Entry(name: "heavy cream", keywords: ["heavy cream", "whipping cream", "double cream"]),
        Entry(name: "sour cream", keywords: ["sour cream"]),
        Entry(name: "half and half", keywords: ["half and half"]),
        Entry(name: "yogurt", keywords: ["yogurt", "yoghurt"]),
        Entry(name: "cream cheese", keywords: ["cream cheese"]),
        Entry(name: "mozzarella", keywords: ["mozzarella"]),
        Entry(name: "ricotta", keywords: ["ricotta"]),
        Entry(name: "feta", keywords: ["feta"]),
        Entry(name: "cheddar", keywords: ["cheddar"]),
        Entry(name: "goat cheese", keywords: ["goat cheese", "chevre"]),
        Entry(name: "mascarpone", keywords: ["mascarpone"]),

        // MARK: Produce — vegetables
        Entry(name: "lettuce", keywords: ["lettuce", "romaine", "iceberg", "mixed greens", "spring mix"]),
        Entry(name: "tomato", keywords: ["tomato"],
              // GroceryCategory files these under pantry (canned).
              excluding: ["diced tomato", "crushed tomato"]),
        Entry(name: "bell pepper", keywords: ["bell pepper", "sweet pepper"]),
        Entry(name: "jalapeño", keywords: ["jalapeno", "jalapeño"]),
        Entry(name: "carrot", keywords: ["carrot"]),
        Entry(name: "celery", keywords: ["celery"], excluding: ["celery seed", "celery salt"]),
        Entry(name: "potato", keywords: ["potato"], excluding: ["sweet potato"]),
        Entry(name: "sweet potato", keywords: ["sweet potato", "yam"]),
        Entry(name: "avocado", keywords: ["avocado"]),
        Entry(name: "spinach", keywords: ["spinach"]),
        Entry(name: "kale", keywords: ["kale"]),
        Entry(name: "arugula", keywords: ["arugula"]),
        Entry(name: "broccoli", keywords: ["broccoli", "broccolini"]),
        Entry(name: "cauliflower", keywords: ["cauliflower"]),
        Entry(name: "cabbage", keywords: ["cabbage", "napa cabbage", "coleslaw mix"]),
        Entry(name: "bok choy", keywords: ["bok choy", "pak choi"]),
        Entry(name: "brussels sprouts", keywords: ["brussels sprout"]),
        Entry(name: "bean sprouts", keywords: ["bean sprout"]),
        Entry(name: "green beans", keywords: ["green bean", "string bean", "haricot vert"]),
        Entry(name: "snap peas", keywords: ["snap pea", "snow pea"]),
        Entry(name: "cucumber", keywords: ["cucumber"]),
        Entry(name: "zucchini", keywords: ["zucchini", "courgette"]),
        Entry(name: "squash", keywords: ["squash"]),
        Entry(name: "eggplant", keywords: ["eggplant", "aubergine"]),
        Entry(name: "mushroom", keywords: ["mushroom", "cremini", "shiitake", "portobello"]),
        Entry(name: "asparagus", keywords: ["asparagus"]),
        Entry(name: "corn", keywords: ["corn", "sweet corn"],
              excluding: ["corn tortilla", "baby corn"]),
        Entry(name: "leek", keywords: ["leek"]),
        Entry(name: "scallion", keywords: ["scallion", "green onion", "spring onion"]),
        Entry(name: "beet", keywords: ["beet", "beetroot"]),
        Entry(name: "radish", keywords: ["radish"]),
        Entry(name: "turnip", keywords: ["turnip"]),
        Entry(name: "fennel", keywords: ["fennel"], excluding: ["fennel seed"]),
        Entry(name: "okra", keywords: ["okra"]),
        // Ground ginger is a spice; ginger ale is a drink.
        Entry(name: "ginger", keywords: ["ginger"],
              excluding: ["ground ginger", "ginger ale"]),

        // MARK: Produce — herbs
        Entry(name: "cilantro", keywords: ["cilantro", "fresh coriander", "coriander leaves"]),
        Entry(name: "basil", keywords: ["basil"]),
        Entry(name: "parsley", keywords: ["parsley"]),
        Entry(name: "mint", keywords: ["mint"]),
        Entry(name: "chives", keywords: ["chive"]),
        // These are usually dried in recipes; only clearly fresh
        // forms count. ("Dill" alone also hits "dill pickles".)
        Entry(name: "dill", keywords: ["fresh dill", "dill sprig"]),
        Entry(name: "thyme", keywords: ["fresh thyme", "thyme sprig"]),
        Entry(name: "rosemary", keywords: ["fresh rosemary", "rosemary sprig"]),
        Entry(name: "sage", keywords: ["fresh sage", "sage leaves"]),

        // MARK: Produce — fruit
        Entry(name: "lemon", keywords: ["lemon"], excluding: ["lemon pepper"]),
        Entry(name: "lime", keywords: ["lime"]),
        Entry(name: "orange", keywords: ["orange"], excluding: ["orange juice", "orange marmalade", "orange bell pepper"]),
        Entry(name: "apple", keywords: ["apple"],
              excluding: ["apple cider", "apple juice", "apple butter"]),
        Entry(name: "pear", keywords: ["pear"]),
        Entry(name: "banana", keywords: ["banana"]),
        Entry(name: "strawberry", keywords: ["strawberry"]),
        Entry(name: "blueberry", keywords: ["blueberry"]),
        Entry(name: "raspberry", keywords: ["raspberry"]),
        Entry(name: "grape", keywords: ["grape"], excluding: ["grape tomato"]),
        Entry(name: "cherry", keywords: ["cherry"], excluding: ["cherry tomato"]),
        Entry(name: "peach", keywords: ["peach"]),
        Entry(name: "plum", keywords: ["plum"], excluding: ["plum tomato"]),
        Entry(name: "mango", keywords: ["mango"]),
        Entry(name: "pineapple", keywords: ["pineapple"]),
        Entry(name: "melon", keywords: ["melon", "watermelon", "cantaloupe", "honeydew"]),
        Entry(name: "pomegranate", keywords: ["pomegranate"]),
    ]
}
