//
//  RecipeCardImage.swift
//  FluffyList
//
//  Shared recipe image. Prefers the homemade photo when available,
//  falls back to source image, then to a flat editorial placeholder.
//  Loaded photos take "The Press" halftone treatment (desaturate
//  ~35%, contrast ~1.15) — square corners, no scrim. 0.25s fade-in.
//

import SwiftUI

struct RecipeCardImage: View {
    let recipe: RecipeRow
    let height: CGFloat

    /// The best available image path: homemade wins over source.
    private var displayImagePath: String? {
        recipe.homemadeImagePath ?? recipe.sourceImagePath
    }

    var body: some View {
        if let url = SupabaseManager.shared.publicStorageURL(path: displayImagePath) {
            AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.25))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .fluffyHalftone()
                case .failure:
                    gradientFallback
                default:
                    gradientFallback
                }
            }
            .frame(height: height)
            .clipped()
        } else {
            gradientFallback
                .frame(height: height)
        }
    }

    // MARK: - Placeholder Fallback

    /// Flat editorial placeholder: paper-adjacent field, hairline
    /// rules top and bottom, a light category glyph. No gradients.
    private var gradientFallback: some View {
        ZStack {
            Color.fluffyDivider
            Image(systemName: categoryIcon)
                .font(.system(size: height > 100 ? 56 : 22, weight: .ultraLight))
                .foregroundStyle(Color.fluffySecondary.opacity(0.6))
        }
        .overlay(alignment: .top) { Rectangle().fill(Color.fluffyPrimary.opacity(0.2)).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.fluffyPrimary.opacity(0.2)).frame(height: 1) }
    }

    /// SF Symbol per meal category.
    private var categoryIcon: String {
        switch recipe.recipeCategory {
        case .breakfast: "sunrise"
        case .lunch:     "sun.max"
        case .dinner:    "moon.stars"
        case .snack:     "leaf"
        case .dessert:   "birthday.cake"
        case .side:      "carrot"
        case .drink:     "cup.and.saucer"
        }
    }
}
