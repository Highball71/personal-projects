//
//  AppColors.swift
//  FluffyList
//
//  Slate & Sage design palette with amber accents.
//  All colours are defined here so changes stay in one place.
//

import SwiftUI

// MARK: - Palette

extension Color {
    /// App background — light sage-white
    static let fluffyBackground = Color(fluffyHex: "F0F2F0")
    /// Navigation and tab bar surface
    static let fluffyNavBar     = Color(fluffyHex: "E8EBE8")
    /// Card surface — slightly warmer than background
    static let fluffyCard       = Color(fluffyHex: "F7F9F7")
    /// Primary text — deep forest green
    static let fluffyPrimary    = Color(fluffyHex: "1E2E22")
    /// Secondary text — muted sage
    static let fluffySecondary  = Color(fluffyHex: "7A9180")
    /// Amber accent — buttons, badges, active states
    static let fluffyAccent     = Color(fluffyHex: "BA7517")
    /// Subtle border for cards and dividers
    static let fluffyBorder     = Color(fluffyHex: "CDD4CD")

    /// Initialise from a 6-digit hex string (no leading #).
    init(fluffyHex hex: String) {
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            .sRGB,
            red:     Double((int >> 16) & 0xFF) / 255,
            green:   Double((int >>  8) & 0xFF) / 255,
            blue:    Double( int        & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Category stripe colours

extension RecipeCategory {
    /// 3 pt left-edge stripe colour used on recipe list cards.
    /// Each category gets a distinct hue within the Slate & Sage family.
    var stripeColor: Color {
        switch self {
        case .breakfast: return Color(fluffyHex: "E8A85A") // warm morning amber
        case .lunch:     return Color(fluffyHex: "6B9E7A") // fresh sage
        case .dinner:    return Color(fluffyHex: "BA7517") // main accent amber
        case .snack:     return Color(fluffyHex: "9BB5A0") // soft sage
        case .dessert:   return Color(fluffyHex: "C49A6C") // caramel
        case .side:      return Color(fluffyHex: "4A7560") // deep sage
        case .drink:     return Color(fluffyHex: "7A9180") // secondary sage
        }
    }
}

