// Warm semantic surfaces and accessible accents for light and dark appearance.
// Store Mode retains its separately defined fixed dark palette.

import SwiftUI
import UIKit

// MARK: - Core Palette

extension Color {

    // -- Surfaces --

    /// Page ground — every screen. Routed through the backdrop
    /// experiment: Cream (the shipped paper) unless the device picks
    /// a sky in Settings → Appearance. Computed like fluffyAccent so
    /// views re-render when the choice changes.
    static var fluffyBackground: Color {
        let pair = SeasonalAppearance.shared.backdrop.page
        return .fluffyAdaptive(pair.light, dark: pair.dark)
    }

    /// Cards/panels stay warm paper in every backdrop — they read as
    /// a surface floating on the sky.
    static let fluffyCard        = Color.fluffyAdaptive("F1ECE6", dark: "292521")

    /// Chrome is the same ground as the page.
    static var fluffyNavBar: Color { fluffyBackground }

    /// Ink ground — Store Mode background (#201E1D)
    static let fluffyInkGround   = Color(hex: "201E1D")

    // -- Text --

    /// Ink — all body and display text (#201E1D)
    static let fluffyPrimary     = Color.fluffyAdaptive("241F1B", dark: "F6F0E8")

    /// Metadata, kickers (#605D5D)
    static let fluffySecondary   = Color.fluffyAdaptive("625B55", dark: "C7BFB6")

    /// Checked / disabled text (#9B9797)
    static let fluffyTertiary    = Color.fluffyAdaptive("746C65", dark: "A99F94")

    // -- Borders & dividers --

    /// Unchecked checkbox stroke (#BAB6B6)
    static let fluffyBorder      = Color.fluffyAdaptive("B7AEA4", dark: "70675E")

    /// Hairline rules between rows — rgba(32,30,29,0.16)
    static let fluffyDivider     = Color.fluffyAdaptive("241F1B", dark: "F6F0E8").opacity(0.16)

    /// Stronger rule for underlined fields — rgba(32,30,29,0.35)
    static let fluffyFieldRule   = Color.fluffyAdaptive("241F1B", dark: "F6F0E8").opacity(0.35)
}

// MARK: - Spot Colours (ink 1 / ink 2 / ink 3)

extension Color {

    /// Ink 1 — Persimmon. The only tappable colour. (#D93A14)
    static var fluffyAccent: Color {
        let pair = SeasonalAppearance.shared.palette.accent
        return .fluffyAdaptive(pair.light, dark: pair.dark)
    }

    /// Always a dark ink so white button labels retain contrast.
    static var fluffyButtonFill: Color { Color(hex: SeasonalAppearance.shared.palette.accent.light) }

    /// Ink 1 deep — pressed / hover state (#9E2A0E)
    static var fluffyAccentDeep: Color { fluffyAccent }

    /// Ink 1 pale — Store Mode checkbox fill, tinted marks (#FFC9B8)
    static var fluffyAccentPale: Color {
        let pair = SeasonalAppearance.shared.palette.pale
        return .fluffyAdaptive(pair.light, dark: pair.dark)
    }

    /// Ink 2 — Deep spruce. The rare second spot colour. (#14663E)
    static let fluffyInk2        = Color.fluffyAdaptive("14663E", dark: "80CDA3")

    /// Ink 2 deep — category heads on dark, dense ink-2 text (#0C4429)
    static let fluffyInk2Deep    = Color.fluffyAdaptive("0C4429", dark: "9ED9B8")

    /// Ink 3 — Press yellow. Reserved; used sparingly. (#EDBB00)
    static let fluffyInk3        = Color(hex: "EDBB00")

    // -- Retired per-section accents --
    // Sections are no longer colour-coded. These aliases keep any
    // straggling call sites compiling; all collapse to persimmon.
    static var fluffyAmber: Color { fluffyAccent }
    static var fluffyAmberLight: Color { fluffyAccentPale }
    static var fluffyTeal: Color { fluffyAccent }
    static var fluffyTealLight: Color { fluffyAccentPale }
    static var fluffySlateBlue: Color { fluffyAccent }
    static var fluffySlateBlueLight: Color { fluffyAccentPale }
}

// MARK: - Semantic Helpers

extension Color {
    /// Error — reuse ink 1 deep rather than a new red
    static let fluffyError       = Color.fluffyAdaptive("9E2A0E", dark: "FFAB8B")

    /// Success — reuse ink 2
    static let fluffySuccess     = Color.fluffyAdaptive("14663E", dark: "80CDA3")
}

// MARK: - Store Mode (ink ground) palette

extension Color {
    /// Paper text on the ink ground (#F3F2F2)
    static let fluffyPaperOnInk      = Color(hex: "F3F2F2")

    /// Dimmed / checked text on the ink ground
    static let fluffyPaperDimOnInk   = Color(hex: "BDBBB8")

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

// Semantic colors resolve again when the system appearance changes.
extension Color {
    static func fluffyAdaptive(_ light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            let value = UInt64(hex, radix: 16) ?? 0
            return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}
