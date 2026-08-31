//
//  DietaryOption.swift
//  FluffyList
//
//  The dietary-preference vocabulary. Promoted out of
//  HouseholdSetupView (where it was private) for per-person meals
//  Phase 2: the raw values are stored verbatim in
//  household_members.dietary_preferences (migration 013), so the enum
//  round-trips through the DB — do not rename cases' raw values.
//

import Foundation

enum DietaryOption: String, CaseIterable, Identifiable, Hashable {
    case vegetarian  = "Vegetarian"
    case vegan       = "Vegan"
    case glutenFree  = "Gluten-Free"
    case dairyFree   = "Dairy-Free"
    case nutFree     = "Nut-Free"
    case lowCarb     = "Low-Carb"
    case pescatarian = "Pescatarian"
    case halal       = "Halal"
    case kosher      = "Kosher"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .vegetarian:  "leaf"
        case .vegan:       "leaf.fill"
        case .glutenFree:  "slash.circle"
        case .dairyFree:   "drop.triangle"
        case .nutFree:     "exclamationmark.triangle"
        case .lowCarb:     "scalemass"
        case .pescatarian: "fish"
        case .halal:       "checkmark.seal"
        case .kosher:      "star.circle"
        }
    }

    // MARK: - Persistence helpers

    /// Parse the legacy @AppStorage("dietaryPreferences") format — a
    /// comma-separated raw-value string. Unknown values are dropped.
    static func set(fromCommaSeparated raw: String) -> Set<DietaryOption> {
        Set(raw.split(separator: ",").compactMap { DietaryOption(rawValue: String($0)) })
    }

    /// Parse the dietary_preferences array as stored in the DB.
    /// Unknown values (from a future app version) are dropped.
    static func set(fromRawValues values: [String]) -> Set<DietaryOption> {
        Set(values.compactMap(DietaryOption.init(rawValue:)))
    }

    /// Serialize a selection for the DB column — sorted so the stored
    /// array is stable across saves.
    static func rawValues(from selection: Set<DietaryOption>) -> [String] {
        selection.map(\.rawValue).sorted()
    }
}
