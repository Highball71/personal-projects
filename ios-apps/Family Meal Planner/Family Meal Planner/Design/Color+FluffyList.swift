//
//  Color+FluffyList.swift
//  FluffyList
//
//  "The Press" palette — editorial broadsheet treatment.
//  Paper ground, ink text, persimmon as the single tappable colour,
//  deep spruce as the rare second spot colour.
//  All colours are defined here so changes stay in one place.
//

import SwiftUI

// MARK: - Core Palette

extension Color {

    // -- Surfaces --

    /// Paper ground — every screen (#F3F2F2)
    static let fluffyBackground  = Color(hex: "F3F2F2")

    /// No longer a distinct surface; cards are gone. Same paper.
    static let fluffyCard        = Color(hex: "F3F2F2")

    /// Chrome is the same paper.
    static let fluffyNavBar      = Color(hex: "F3F2F2")

    /// Ink ground — Store Mode background (#201E1D)
    static let fluffyInkGround   = Color(hex: "201E1D")

    // -- Text --

    /// Ink — all body and display text (#201E1D)
    static let fluffyPrimary     = Color(hex: "201E1D")

    /// Metadata, kickers (#605D5D)
    static let fluffySecondary   = Color(hex: "605D5D")

    /// Checked / disabled text (#9B9797)
    static let fluffyTertiary    = Color(hex: "9B9797")

    // -- Borders & dividers --

    /// Unchecked checkbox stroke (#BAB6B6)
    static let fluffyBorder      = Color(hex: "BAB6B6")

    /// Hairline rules between rows — rgba(32,30,29,0.16)
    static let fluffyDivider     = Color(hex: "201E1D").opacity(0.16)

    /// Stronger rule for underlined fields — rgba(32,30,29,0.35)
    static let fluffyFieldRule   = Color(hex: "201E1D").opacity(0.35)
}

// MARK: - Spot Colours (ink 1 / ink 2 / ink 3)

extension Color {

    /// Ink 1 — Persimmon. The only tappable colour. (#D93A14)
    static let fluffyAccent      = Color(hex: "D93A14")

    /// Ink 1 deep — pressed / hover state (#9E2A0E)
    static let fluffyAccentDeep  = Color(hex: "9E2A0E")

    /// Ink 1 pale — Store Mode checkbox fill, tinted marks (#FFC9B8)
    static let fluffyAccentPale  = Color(hex: "FFC9B8")

    /// Ink 2 — Deep spruce. The rare second spot colour. (#14663E)
    static let fluffyInk2        = Color(hex: "14663E")

    /// Ink 2 deep — category heads on dark, dense ink-2 text (#0C4429)
    static let fluffyInk2Deep    = Color(hex: "0C4429")

    /// Ink 3 — Press yellow. Reserved; used sparingly. (#EDBB00)
    static let fluffyInk3        = Color(hex: "EDBB00")

    // -- Retired per-section accents --
    // Sections are no longer colour-coded. These aliases keep any
    // straggling call sites compiling; all collapse to persimmon.
    static let fluffyAmber           = fluffyAccent
    static let fluffyAmberLight      = fluffyAccentPale
    static let fluffyTeal            = fluffyAccent
    static let fluffyTealLight       = fluffyAccentPale
    static let fluffySlateBlue       = fluffyAccent
    static let fluffySlateBlueLight  = fluffyAccentPale
}

// MARK: - Semantic Helpers

extension Color {
    /// Error — reuse ink 1 deep rather than a new red
    static let fluffyError       = Color(hex: "9E2A0E")

    /// Success — reuse ink 2
    static let fluffySuccess     = Color(hex: "14663E")
}

// MARK: - Store Mode (ink ground) palette

extension Color {
    /// Paper text on the ink ground (#F3F2F2)
    static let fluffyPaperOnInk      = Color(hex: "F3F2F2")

    /// Dimmed / checked text on the ink ground
    static let fluffyPaperDimOnInk   = Color(hex: "F3F2F2").opacity(0.4)

    /// Hairline rules on the ink ground
    static let fluffyRuleOnInk       = Color(hex: "F3F2F2").opacity(0.18)
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
