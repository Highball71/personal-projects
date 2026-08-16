//
//  FluffyColor.swift
//  FluffyList
//
//  "The Press": sections are no longer colour-coded. The enum keeps
//  its cases and icon role (the tab bar still needs them); the colour
//  role collapses to persimmon + ink-1 pale everywhere.
//

import SwiftUI

/// The main app sections. Colour-coding is retired under The Press —
/// every section's accent is persimmon (ink 1).
enum FluffySection: String, CaseIterable {
    case recipes
    case mealPlan
    case grocery

    /// Single app accent — persimmon (ink 1) for every section.
    var accent: Color { .fluffyAccent }

    /// Single soft tint — ink 1 pale for every section.
    var accentLight: Color { .fluffyAccentPale }

    /// SF Symbol name for the section's tab icon.
    var iconName: String {
        switch self {
        case .recipes:  "book"
        case .mealPlan: "calendar"
        case .grocery:  "cart"
        }
    }
}
