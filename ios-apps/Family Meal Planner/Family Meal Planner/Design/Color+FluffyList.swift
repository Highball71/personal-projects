//
//  Color+FluffyList.swift
//  FluffyList
//
//  Heirloom design palette — warm near-white background with
//  three section accent colors (Amber, Teal, Slate Blue).
//  All colours are defined here so changes stay in one place.
//

import SwiftUI

// MARK: - Core Palette

extension Color {

    // -- Surfaces --

    /// App background — warm near-white (#FAFAF7)
    static let fluffyBackground  = Color(hex: "FAFAF7")

    /// Card / sheet surface — clean white to float above background
    static let fluffyCard        = Color(hex: "FFFFFF")

    /// Navigation and tab bar surface
    static let fluffyNavBar      = Color(hex: "F4F4F0")

    // -- Text --

    /// Primary text — near-black (#1C1C1A)
    static let fluffyPrimary     = Color(hex: "1C1C1A")

    /// Secondary text — warm medium gray
    static let fluffySecondary   = Color(hex: "6B6B68")

    /// Tertiary / placeholder text — lighter gray
    static let fluffyTertiary    = Color(hex: "9E9E9A")

    // -- Borders & dividers --

    /// Subtle border for cards and inputs
    static let fluffyBorder      = Color(hex: "E2E2DD")

    /// Lighter divider / separator
    static let fluffyDivider     = Color(hex: "EDEDEA")
}

// MARK: - Section Accents

extension Color {

    // Each app section has a primary accent and a soft-tinted background.

    /// Recipes — Amber (#F59B00)
    static let fluffyAmber           = Color(hex: "F59B00")
    /// Recipes — light amber tint for section backgrounds
    static let fluffyAmberLight      = Color(hex: "FFF5E0")

    /// Meal Plan — Teal (#0F6E6E)
    static let fluffyTeal            = Color(hex: "0F6E6E")
    /// Meal Plan — light teal tint for section backgrounds
    static let fluffyTealLight       = Color(hex: "E4F4F4")

    /// Grocery — Slate Blue (#2E5DA8)
    static let fluffySlateBlue       = Color(hex: "2E5DA8")
    /// Grocery — light blue tint for section backgrounds
    static let fluffySlateBlueLight  = Color(hex: "E6EDF7")

    // Convenience aliases so existing views keep compiling.
    // "fluffyAccent" now maps to amber (the old accent colour).
    static let fluffyAccent          = fluffyAmber
}

// MARK: - Semantic Helpers

extension Color {
    /// Destructive / error red
    static let fluffyError       = Color(hex: "D1333A")

    /// Success green
    static let fluffySuccess     = Color(hex: "2E8B57")
}

// MARK: - Hex Initialiser

extension Color {
    /// Initialise from a 6-digit hex string (no leading #).
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        self.init(
            .sRGB,
            red:     Double((int >> 16) & 0xFF) / 255,
            green:   Double((int >>  8) & 0xFF) / 255,
            blue:    Double( int        & 0xFF) / 255,
            opacity: 1
        )
    }
}
