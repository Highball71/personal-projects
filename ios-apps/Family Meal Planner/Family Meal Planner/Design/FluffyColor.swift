//
//  FluffyColor.swift
//  FluffyList
//
//  Section-aware color provider. Maps each app section to its
//  accent color pair so views can be themed by context.
//

import SwiftUI

/// The three main app sections, each with its own accent colour pair.
enum FluffySection: String, CaseIterable {
    case recipes
    case mealPlan
    case grocery

    /// Bold accent colour for this section.
    var accent: Color {
        switch self {
        case .recipes:  .fluffyAmber
        case .mealPlan: .fluffyTeal
        case .grocery:  .fluffySlateBlue
        }
    }

    /// Soft tinted background for this section.
    var accentLight: Color {
        switch self {
        case .recipes:  .fluffyAmberLight
        case .mealPlan: .fluffyTealLight
        case .grocery:  .fluffySlateBlueLight
        }
    }

    /// SF Symbol name for the section's tab icon.
    var iconName: String {
        switch self {
        case .recipes:  "book"
        case .mealPlan: "calendar"
        case .grocery:  "cart"
        }
    }
}
