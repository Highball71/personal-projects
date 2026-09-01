//
//  DietaryMatch.swift
//  FluffyList
//
//  Per-person meals Phase 3: keyword-only dietary matching (decided
//  2026-08-27 — v1 is a keyword match on the recipe name and
//  ingredient names; flag, never block, and be honest about misses).
//  A hit is a gentle hint on the recipe row, phrased with a
//  question mark because a keyword match is a guess, not a verdict.
//

import Foundation

enum DietaryMatch {

    /// A keyword hit: which preference it clashes with and the word
    /// that tripped it, for an honest "MIGHT NOT BE NUT-FREE · ALMOND"
    /// style hint.
    struct Conflict: Equatable {
        let option: DietaryOption
        let keyword: String
    }

    /// Lowercased substring keywords that suggest a recipe clashes
    /// with a preference. Deliberately conservative: a miss shows no
    /// hint (fine — hints are best-effort), a false hit shows a
    /// gentle question (also fine). Bare "nut" is excluded on purpose:
    /// it would flag nutmeg.
    private static let meatKeywords = [
        "chicken", "beef", "pork", "turkey", "lamb", "bacon",
        "sausage", "ham", "steak", "prosciutto", "pancetta",
        "veal", "chorizo", "pepperoni", "salami", "meatball"
    ]
    private static let seafoodKeywords = [
        "fish", "salmon", "tuna", "cod", "tilapia", "shrimp",
        "prawn", "crab", "lobster", "scallop", "clam", "oyster",
        "squid", "octopus", "anchov", "halibut", "swordfish"
    ]
    private static let dairyKeywords = [
        "milk", "cheese", "butter", "cream", "yogurt", "ghee",
        "mozzarella", "parmesan", "cheddar", "ricotta", "feta"
    ]

    static func conflictKeywords(for option: DietaryOption) -> [String] {
        switch option {
        case .vegetarian:
            return meatKeywords + seafoodKeywords
        case .vegan:
            return meatKeywords + seafoodKeywords + dairyKeywords
                + ["egg", "honey", "mayo", "gelatin"]
        case .glutenFree:
            return [
                "flour", "wheat", "pasta", "spaghetti", "penne",
                "linguine", "fettuccine", "macaroni", "noodle",
                "lasagna", "bread", "panko", "barley", "rye",
                "couscous", "soy sauce", "beer", "cracker"
            ]
        case .dairyFree:
            return dairyKeywords
        case .nutFree:
            return [
                "almond", "peanut", "cashew", "walnut", "pecan",
                "pistachio", "hazelnut", "macadamia", "pine nut", "nuts"
            ]
        case .lowCarb:
            return [
                "pasta", "spaghetti", "noodle", "rice", "bread",
                "potato", "sugar", "tortilla", "flour", "honey", "maple"
            ]
        case .pescatarian:
            return meatKeywords
        case .halal:
            return [
                "pork", "bacon", "ham", "prosciutto", "pancetta",
                "lard", "pepperoni", "wine", "beer", "rum", "brandy",
                "bourbon", "alcohol"
            ]
        case .kosher:
            return [
                "pork", "bacon", "ham", "prosciutto", "pancetta",
                "lard", "shrimp", "prawn", "crab", "lobster",
                "scallop", "clam", "oyster", "squid", "octopus"
            ]
        }
    }

    /// First keyword clash between one preference and a recipe's name
    /// + ingredient names (ingredient names arrive lowercased from
    /// RecipeService's cache). nil = no hint.
    static func conflict(
        option: DietaryOption,
        recipeName: String,
        ingredientNames: [String]
    ) -> Conflict? {
        let nameLower = recipeName.lowercased()
        for keyword in conflictKeywords(for: option) {
            if nameLower.contains(keyword)
                || ingredientNames.contains(where: { $0.contains(keyword) }) {
                return Conflict(option: option, keyword: keyword)
            }
        }
        return nil
    }

    /// First clash between a member's stored preferences and a recipe.
    /// Unknown preference strings (from a future app version) are
    /// skipped by the DietaryOption parse.
    static func conflict(
        for member: HouseholdMemberRow,
        recipe: RecipeRow,
        ingredientNames: [String]?
    ) -> Conflict? {
        let options = DietaryOption.set(fromRawValues: member.dietaryPreferences)
            .sorted { $0.rawValue < $1.rawValue }
        for option in options {
            if let hit = conflict(
                option: option,
                recipeName: recipe.name,
                ingredientNames: ingredientNames ?? []
            ) {
                return hit
            }
        }
        return nil
    }

    /// The hint line for a recipe row — e.g.
    /// "MIGHT NOT BE NUT-FREE · ALMOND". Honest about being a keyword
    /// guess; FluffyMetadataLine uppercases it.
    static func hintText(for conflict: Conflict) -> String {
        "Might not be \(conflict.option.rawValue) \u{00B7} \(conflict.keyword)"
    }

    // MARK: - Household-wide hints (EVERYONE selected)

    /// A clash between a recipe and the whole household: the first
    /// affected member's conflict, plus how many OTHER members also
    /// clash — for a one-line "MIGHT NOT BE VEGAN FOR MAYA +1 · BUTTER"
    /// hint when the picker's EVERYONE chip is selected.
    struct HouseholdConflict: Equatable {
        let memberName: String
        let conflict: Conflict
        /// Additional members (beyond the named one) with a clash of
        /// their own — possibly against a different preference.
        let othersCount: Int
    }

    /// Check a recipe against EVERY member's preferences. The named
    /// member is the first with a clash in the given member order (the
    /// household's stable order), so the hint reads the same day to
    /// day. nil when nobody clashes — or when there are no members.
    static func householdConflict(
        members: [HouseholdMemberRow],
        recipe: RecipeRow,
        ingredientNames: [String]?
    ) -> HouseholdConflict? {
        let clashes = members.compactMap { member in
            conflict(for: member, recipe: recipe, ingredientNames: ingredientNames)
                .map { (member, $0) }
        }
        guard let first = clashes.first else { return nil }
        return HouseholdConflict(
            memberName: first.0.displayName,
            conflict: first.1,
            othersCount: clashes.count - 1
        )
    }

    /// The household hint line — "Might not be Vegan for Maya · butter",
    /// with " +1" after the name when more members clash too. Still a
    /// hint, never a block.
    static func hintText(for household: HouseholdConflict) -> String {
        let others = household.othersCount > 0 ? " +\(household.othersCount)" : ""
        return "Might not be \(household.conflict.option.rawValue) "
            + "for \(household.memberName)\(others) \u{00B7} \(household.conflict.keyword)"
    }
}
