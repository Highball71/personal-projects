// Cookbook direction (design/fluffylist-cookbook-direction): shared
// presentation tokens and small components. Presentation only — no data,
// service, or media-role logic lives here.
//
// Base colours: leafy green for primary actions and navigation, tomato for
// small moments of emphasis, a clear blue as the restrained counterpoint.
// Seasonal accents (SeasonalAppearance) stay separate and untouched.
// Never teal.

import SwiftUI

// MARK: - Colours

extension Color {
    /// Leafy green — primary actions, active chips, tab selection.
    static let fluffyLeaf      = Color.fluffyAdaptive("2F7A45", dark: "8FD9A6")
    /// Pale leaf — quiet green fills (selected rows, notes).
    static let fluffyLeafPale  = Color.fluffyAdaptive("E4F1E7", dark: "1E3326")
    /// Tomato — small emphasis: favorites, "today" markers.
    static let fluffyTomato    = Color.fluffyAdaptive("C2412B", dark: "FF9C85")
    /// Clear blue — restrained counterpoint (member meals, info).
    static let fluffyClearBlue = Color.fluffyAdaptive("1F5FC4", dark: "8AB8FF")
    /// Slightly lifted paper for fields and controls.
    static let fluffyPaperRaised = Color.fluffyAdaptive("FFFDF9", dark: "221F1C")
    /// Hairline for outlined controls (chips, fields).
    static let fluffyControlLine = Color.fluffyAdaptive("D7D0C5", dark: "4A433C")
}

// MARK: - Type

extension Font {
    /// Screen title ("Recipes") — Source Serif Bold, scales with Dynamic Type.
    static let fluffyCookbookTitle   = Font.custom(FluffyFace.bold, size: 44, relativeTo: .largeTitle)
    /// Section title ("Recently added").
    static let fluffyCookbookSection = Font.custom(FluffyFace.bold, size: 23, relativeTo: .title2)
    /// Hero recipe title over a photo.
    static let fluffyCookbookHero    = Font.custom(FluffyFace.bold, size: 30, relativeTo: .title)
    /// Row titles in ruled lists.
    static let fluffyCookbookRow     = Font.custom(FluffyFace.semibold, size: 18, relativeTo: .body)
    /// Small card titles on shelves.
    static let fluffyCookbookCard    = Font.custom(FluffyFace.semibold, size: 16, relativeTo: .subheadline)
    /// Italic sub-copy under a title.
    static let fluffyCookbookLede    = Font.custom(FluffyFace.italic, size: 17, relativeTo: .body)
}

// MARK: - Components

/// "FLUFFYLIST ··· THE ALBERTS" line above a screen title. Readable
/// weight and colour — not a functional label, but never faint.
struct CookbookTopline: View {
    var trailing: String?
    var onBrandTap: (() -> Void)?

    var body: some View {
        HStack {
            if let onBrandTap {
                Button(action: onBrandTap) { brand }
                    .buttonStyle(.plain)
                    .accessibilityLabel("FluffyList household")
            } else {
                brand
            }
            Spacer()
            if let trailing, !trailing.isEmpty {
                Text(trailing.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.fluffySecondary)
                    .lineLimit(1)
            }
        }
    }

    private var brand: some View {
        Text("FLUFFYLIST")
            .font(.caption.weight(.bold))
            .tracking(1.6)
            .foregroundStyle(Color.fluffyPrimary)
    }
}

/// Serif section title with optional plain-case detail on the right.
struct CookbookSectionHeader: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.fluffyCookbookSection)
                .foregroundStyle(Color.fluffyPrimary)
            Spacer(minLength: 12)
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Color.fluffySecondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Outlined filter chip; selected state fills leafy green.
struct CookbookChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .fixedSize()
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .foregroundStyle(isSelected ? Color.white : Color.fluffyPrimary)
                .background(isSelected ? Color.fluffyLeaf : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.fluffyLeaf : Color.fluffyControlLine, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Media label (display only)

extension RecipeRow {
    /// Which saved media a `.family`-role cover shows, mirroring
    /// RecipeCardImage's family → legacy homemade → cookbook order.
    /// Label only; selection logic stays in RecipeCardImage.
    var coverMediaLabel: String? {
        if familyCoverImagePath != nil || homemadeImagePath != nil { return "Family photo" }
        if cookbookImagePath != nil { return "Cookbook photo" }
        return nil
    }
}
