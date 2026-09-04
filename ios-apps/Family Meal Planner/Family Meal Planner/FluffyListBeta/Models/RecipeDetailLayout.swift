//
//  RecipeDetailLayout.swift
//  FluffyList
//
//  iPad phase 1: the "cookbook on a stand" recipe detail. All the
//  layout DECISIONS for that screen live here — does the horizontal
//  size class get two columns, how much the Press type scales, and
//  where the line measure is capped — so they are unit-testable and
//  the view just reads values. Driven purely by size class, never by
//  device checks, so an iPad slide-over at compact width correctly
//  gets the phone layout and a future large phone could get this one.
//
//  Every compact value below equals the constant the phone layout has
//  always used — the phone renders byte-for-byte the same as before
//  this file existed. Regular scales the same Press faces up; it does
//  not redesign them.
//

import CoreGraphics

struct RecipeDetailLayout: Equatable {

    /// True for the regular horizontal size class — the only input.
    let isRegular: Bool

    /// Sized from SwiftUI's horizontalSizeClass. nil (unknown) falls
    /// back to the phone layout — the safe default.
    init(isRegular: Bool) {
        self.isRegular = isRegular
    }

    // MARK: - Structure

    /// Two columns — ingredients left, method right — only in the
    /// regular width. Compact keeps the single scroll.
    var usesTwoColumns: Bool { isRegular }

    /// The halftone photo across the top. 230 is the phone constant;
    /// the stand gets half again as much.
    var photoHeight: CGFloat { isRegular ? 345 : 230 }

    /// Fixed width of the left (ingredients) column in the two-column
    /// layout. Compact never reads it.
    var ingredientColumnWidth: CGFloat { 300 }

    /// Cap on the method column's text width — the line-measure rule.
    /// ~65 characters at the regular body size (Inter averages about
    /// half an em per character: 21pt × 0.5 × 65 ≈ 680) so steps stay
    /// readable from a few feet away instead of running the full pane.
    var stepColumnMaxWidth: CGFloat { 680 }

    /// Cap on the whole content block (title + both columns), centered
    /// in whatever is left — keeps 11" landscape from stretching the
    /// broadsheet edge to edge.
    var contentMaxWidth: CGFloat? { isRegular ? 1080 : nil }

    /// The sticky "Add to the week" bar's button width cap on regular
    /// (a 1194pt-wide filled button is a banner, not a button).
    var bottomBarMaxWidth: CGFloat? { isRegular ? 560 : nil }

    // MARK: - Type scale (points)

    /// Recipe title. 36 is .fluffyTitle's size on the phone.
    var titleSize: CGFloat { isRegular ? 44 : 36 }

    /// Body text: steps, ingredient names, notes.
    var bodySize: CGFloat { isRegular ? 21 : 17 }

    /// Ingredient quantity column.
    var quantitySize: CGFloat { isRegular ? 17 : 14 }

    /// The step numeral and its fixed column.
    var stepNumeralSize: CGFloat { isRegular ? 34 : 28 }
    var stepNumeralColumnWidth: CGFloat { isRegular ? 42 : 34 }

    // MARK: - Line measure (for tests)

    /// Approximate characters per line the step column allows at the
    /// body size, using Inter's ~0.5em average character width. The
    /// tests pin this into the readable 60–80 band.
    var approxStepCharactersPerLine: CGFloat {
        stepColumnMaxWidth / (bodySize * 0.5)
    }
}
