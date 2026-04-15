//
//  AppColors.swift
//  FluffyList
//
//  Category-specific stripe colours for recipe list cards.
//  Core palette lives in Color+FluffyList.swift.
//

import SwiftUI

// MARK: - Category stripe colours

extension RecipeCategory {
    /// 3 pt left-edge stripe colour used on recipe list cards.
    var stripeColor: Color {
        switch self {
        case .breakfast: return Color(hex: "E8A85A") // warm morning amber
        case .lunch:     return Color(hex: "6B9E7A") // fresh sage
        case .dinner:    return .fluffyAmber          // section accent
        case .snack:     return Color(hex: "9BB5A0") // soft sage
        case .dessert:   return Color(hex: "C49A6C") // caramel
        case .side:      return Color(hex: "4A7560") // deep sage
        case .drink:     return Color(hex: "7A9180") // muted sage
        }
    }
}
