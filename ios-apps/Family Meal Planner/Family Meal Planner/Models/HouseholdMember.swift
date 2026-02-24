//
//  HouseholdMember.swift
//  Family Meal Planner
//

import Foundation
import SwiftData

/// A person in the household who uses the app.
/// One member can be designated as the Head Cook — the person who has
/// final approval on the weekly meal plan. Other members can suggest
/// recipes, but the Head Cook confirms or swaps them.
///
/// Syncs via CloudKit so all family devices share the same member list.
@Model
final class HouseholdMember {
    var name: String = ""
    var isHeadCook: Bool = false

    init(name: String, isHeadCook: Bool = false) {
        self.name = name
        self.isHeadCook = isHeadCook
    }
}
