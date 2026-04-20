//
//  RecipeCardImage.swift
//  FluffyList
//
//  Shared image component for recipe cards. Prefers the homemade photo
//  when available, falls back to source image, then to a category-based
//  gradient with an SF Symbol overlay. Subtle 0.25s fade-in on load.
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

    // MARK: - Gradient Fallback

    private var gradientFallback: some View {
        ZStack {
            cardGradient
            Image(systemName: categoryIcon)
                .font(.system(size: height > 100 ? 64 : 24))
                .foregroundStyle(.white.opacity(0.15))
        }
    }

    /// Deterministic warm gradient based on recipe category.
    private var cardGradient: LinearGradient {
        let pair: (String, String) = switch recipe.recipeCategory {
        case .breakfast: ("F5C882", "D4A050")
        case .lunch:     ("7DB88F", "5A9E6E")
        case .dinner:    ("D4845A", "B86840")
        case .snack:     ("B5C9A8", "8EB088")
        case .dessert:   ("D4A0B0", "C08098")
        case .side:      ("8AB0A0", "5A9080")
        case .drink:     ("A0B8D0", "7898B8")
        }
        return LinearGradient(
            colors: [Color(hex: pair.0), Color(hex: pair.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// SF Symbol per meal category.
    private var categoryIcon: String {
        switch recipe.recipeCategory {
        case .breakfast: "sunrise.fill"
        case .lunch:     "sun.max.fill"
        case .dinner:    "moon.stars.fill"
        case .snack:     "leaf.fill"
        case .dessert:   "birthday.cake.fill"
        case .side:      "carrot.fill"
        case .drink:     "cup.and.saucer.fill"
        }
    }
}
