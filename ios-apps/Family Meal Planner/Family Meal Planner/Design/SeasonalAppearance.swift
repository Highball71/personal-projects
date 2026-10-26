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

    // Distinct, high-contrast inks on light paper and brighter equivalents
    // on dark paper. The automatic date calendar can add special moments
    // later without changing this stable seasonal foundation.
    var accent: (light: String, dark: String) {
        switch self {
        case .spring: return ("176B45", "8FE0B0")
        case .summer: return ("B52A35", "FF9EA5")
        case .autumn: return ("C74612", "FFAA7A")
        case .winter: return ("126B78", "86D7DE")
        }
    }
    var pale: (light: String, dark: String) {
        switch self {
        case .spring: return ("E3F3E8", "20372A")
        case .summer: return ("FBE2E5", "402326")
        case .autumn: return ("FBE8D9", "43281D")
        case .winter: return ("DFF2F3", "1E3538")
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
