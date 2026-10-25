import SwiftUI
import Observation

/// Device-only appearance preference; never changes household or recipe data.
enum SeasonalPalette: String, CaseIterable, Identifiable {
    case spring = "Spring", summer = "Summer", autumn = "Autumn", winter = "Winter"
    var id: String { rawValue }

    static func automatic(month: Int, southernHemisphere: Bool) -> Self {
        let month = southernHemisphere ? (month + 5) % 12 + 1 : month
        switch month {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }

    // Dark inks on light paper and brighter equivalents on dark paper.
    var accent: (light: String, dark: String) {
        switch self {
        case .spring: return ("356441", "A0D5A9")
        case .summer: return ("AA392F", "FFAAA0")
        case .autumn: return ("BB3510", "FF956E")
        case .winter: return ("205E58", "8CD0C7")
        }
    }
    var pale: (light: String, dark: String) {
        switch self {
        case .spring: return ("E7EEDF", "253429")
        case .summer: return ("FBE7DE", "402A28")
        case .autumn: return ("FCE9DB", "422B22")
        case .winter: return ("E2EEEA", "203431")
        }
    }
}

@Observable
final class SeasonalAppearance {
    static let shared = SeasonalAppearance()
    var palette: SeasonalPalette = .autumn

    func refresh(choice: String, southernHemisphere: Bool, date: Date = Date()) {
        palette = SeasonalPalette(rawValue: choice)
            ?? .automatic(month: Calendar(identifier: .gregorian).component(.month, from: date),
                          southernHemisphere: southernHemisphere)
    }
}
