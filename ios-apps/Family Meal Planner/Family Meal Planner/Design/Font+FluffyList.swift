//
//  Font+FluffyList.swift
//  FluffyList
//
//  "The Press" typography scale.
//  Source Serif 4 for everything — headings AND body. No sans-serif
//  anywhere, including UI chrome.
//
//  Bundled faces (PostScript names, as registered in Info.plist):
//    - SourceSerif4-Regular
//    - SourceSerif4-Semibold   (note lowercase 'b' in the PS name)
//    - SourceSerif4-Bold
//    - SourceSerif4-It         (italic)
//
//  Tracking: SwiftUI .tracking() takes points, the spec uses em.
//  Use the em-tracking helpers at the bottom (points = em × size).
//

import SwiftUI

// MARK: - Face names

enum FluffyFace {
    static let regular  = "SourceSerif4-Regular"
    static let semibold = "SourceSerif4-Semibold"
    static let bold     = "SourceSerif4-Bold"
    static let italic   = "SourceSerif4-It"
}

// MARK: - Typography Scale

extension Font {

    // -- Display (Source Serif 4 Bold) --

    /// Welcome headline only — Bold 52pt, −0.035em, line-height 0.98
    static let fluffyDisplayLarge  = Font.custom(FluffyFace.bold, size: 52)

    /// Screen titles ("This Week", "Recipes") — Bold 38pt, −0.025em
    static let fluffyDisplay       = Font.custom(FluffyFace.bold, size: 38)

    /// Hero recipe title, empty-state headline — Bold 30pt, −0.02em
    static let fluffyDisplaySmall  = Font.custom(FluffyFace.bold, size: 30)

    /// Recipe detail title — Bold 36pt, −0.03em, line-height 1.02
    static let fluffyTitle         = Font.custom(FluffyFace.bold, size: 36)

    // -- Headings (Source Serif 4 SemiBold) --

    /// Row titles (meal, recipe name) — SemiBold 19pt, −0.01em
    static let fluffyHeadline      = Font.custom(FluffyFace.semibold, size: 19)

    /// Secondary row titles — SemiBold 15pt
    static let fluffySubheadline   = Font.custom(FluffyFace.semibold, size: 15)

    // -- Body (Source Serif 4 Regular / Italic) --

    /// List items, method steps, ingredients — Regular 17pt
    static let fluffyBody          = Font.custom(FluffyFace.regular, size: 17)

    /// Editorial asides, sub-copy, empty states — Italic 15pt
    static let fluffyCallout       = Font.custom(FluffyFace.italic, size: 15)

    /// Larger editorial paragraph (recipe description) — Italic 17pt
    static let fluffyCalloutLarge  = Font.custom(FluffyFace.italic, size: 17)

    /// Quantities, right-aligned metadata — Regular 13pt
    static let fluffyFootnote      = Font.custom(FluffyFace.regular, size: 13)

    /// Row metadata ("PASTA · 20 MIN") — Regular 12pt, +0.10em, uppercase
    static let fluffyCaption       = Font.custom(FluffyFace.regular, size: 12)

    /// Masthead label ("FLUFFYLIST" / dateline) — Regular 10pt, +0.16em, uppercase
    static let fluffyMastheadLabel = Font.custom(FluffyFace.regular, size: 10)

    /// Section head ("INGREDIENTS", "PRODUCE") — Regular 11pt, +0.16em, uppercase
    static let fluffySectionHead   = Font.custom(FluffyFace.regular, size: 11)

    // -- Utility --

    /// Buttons and text links — SemiBold 16pt
    static let fluffyButton        = Font.custom(FluffyFace.semibold, size: 16)

    /// Tab bar — Regular 10pt, +0.12em, uppercase
    static let fluffyTabLabel      = Font.custom(FluffyFace.regular, size: 10)
}

// MARK: - Em Tracking

extension View {
    /// Apply tracking specified in em for a given point size.
    /// SwiftUI's .tracking() takes points; points = em × size.
    func fluffyTracking(_ em: CGFloat, at size: CGFloat) -> some View {
        tracking(em * size)
    }
}

extension Text {
    /// Text-returning variant so it can chain with other Text modifiers.
    func fluffyTracking(_ em: CGFloat, at size: CGFloat) -> Text {
        tracking(em * size)
    }
}
