//
//  FluffyRecipeRowLabel.swift
//  FluffyList
//
//  The recipe picker row's content — name with the seasonal leaf,
//  category, and the "IN SEASON · TOMATO, BASIL" match line —
//  extracted (2026-09-04) so the "In season now" shelf on the
//  Recipes tab and the empty-week seasonal strip render the exact
//  same rows as the picker instead of re-drawing them. The picker
//  composes its dietary hint underneath; this label carries only
//  what every surface shares.
//

import SwiftUI

/// One recipe line in the picker's style: fluffyHeadline name (leaf
/// badge when in season), caption category, and — for seasonal
/// picks — the ink-2 match line naming the produce.
struct FluffyRecipeRowLabel: View {
    let recipe: RecipeRow
    /// Non-nil in seasonal contexts, where the match is the point.
    var seasonalScore: SeasonalMatch.Score? = nil
    var showsLeaf: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(recipe.name)
                    .font(.fluffyHeadline)
                    .foregroundStyle(Color.fluffyPrimary)
                if showsLeaf {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.fluffyInk2)
                }
            }
            Text(recipe.category.capitalized)
                .font(.fluffyCaption)
                .foregroundStyle(Color.fluffySecondary)
            // "IN SEASON · TOMATO, BASIL" — only where the seasonal
            // match is the reason the row is here.
            if let seasonalScore {
                FluffyMetadataLine(
                    text: SeasonalMatch.matchText(for: seasonalScore),
                    color: .fluffyInk2
                )
            }
        }
    }
}
