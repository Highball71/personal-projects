//
//  Font+FluffyList.swift
//  FluffyList
//
//  Heirloom typography scale.
//  Display titles: Playfair Display Bold
//  Body / UI text: Inter Regular & Semi Bold
//
//  SETUP: Add the font files to the Xcode project and register
//  them in Info.plist under "Fonts provided by application":
//    - PlayfairDisplay-Bold.ttf
//    - Inter-Regular.ttf
//    - Inter-SemiBold.ttf
//

import SwiftUI

// MARK: - Typography Scale

extension Font {

    // -- Display (Playfair Display Bold) --

    /// Large display title — Playfair Display Bold 34pt
    /// Used for the app name on splash / sign-in.
    static let fluffyDisplayLarge  = Font.custom("PlayfairDisplay-Bold", size: 34)

    /// Standard display title — Playfair Display Bold 28pt
    /// Used for screen-level headings (e.g. "Recipes", "Meal Plan").
    static let fluffyDisplay       = Font.custom("PlayfairDisplay-Bold", size: 28)

    /// Small display — Playfair Display Bold 22pt
    /// Used for section headers within a screen.
    static let fluffyDisplaySmall  = Font.custom("PlayfairDisplay-Bold", size: 22)

    // -- Headings (Inter Semi Bold) --

    /// Title — Inter Semi Bold 20pt
    static let fluffyTitle         = Font.custom("Inter-SemiBold", size: 20)

    /// Headline — Inter Semi Bold 17pt
    static let fluffyHeadline      = Font.custom("Inter-SemiBold", size: 17)

    /// Subheadline — Inter Semi Bold 15pt
    static let fluffySubheadline   = Font.custom("Inter-SemiBold", size: 15)

    // -- Body (Inter Regular) --

    /// Body — Inter Regular 16pt
    static let fluffyBody          = Font.custom("Inter-Regular", size: 16)

    /// Callout — Inter Regular 15pt
    static let fluffyCallout       = Font.custom("Inter-Regular", size: 15)

    /// Footnote — Inter Regular 13pt
    static let fluffyFootnote      = Font.custom("Inter-Regular", size: 13)

    /// Caption — Inter Regular 12pt
    static let fluffyCaption       = Font.custom("Inter-Regular", size: 12)

    // -- Utility --

    /// Button label — Inter Semi Bold 16pt
    static let fluffyButton        = Font.custom("Inter-SemiBold", size: 16)

    /// Tab bar label — Inter Semi Bold 10pt
    static let fluffyTabLabel      = Font.custom("Inter-SemiBold", size: 10)
}

// MARK: - Dynamic Type Support
//
// If you want fonts to scale with the user's Dynamic Type setting,
// use `relativeTo:` — e.g.:
//
//   Font.custom("Inter-Regular", size: 16, relativeTo: .body)
//
// The static constants above use fixed sizes for pixel-perfect
// Figma parity. Swap to relativeTo when you're ready for
// accessibility scaling.
