import SwiftUI

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    var hexString: String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Patient Color Palette
struct PatientColors {
    static let palette: [(name: String, hex: String)] = [
        ("Blue", "#4A90D9"),
        ("Green", "#27AE60"),
        ("Orange", "#E67E22"),
        ("Purple", "#8E44AD"),
        ("Red", "#E74C3C"),
        ("Teal", "#1ABC9C"),
        ("Pink", "#E91E8B"),
        ("Amber", "#F39C12"),
        ("Indigo", "#3F51B5"),
        ("Slate", "#607D8B")
    ]
}

// MARK: - App Theme
struct AppTheme {
    static let primary = Color(hex: "#2C5F8A")!
    static let secondary = Color(hex: "#4A90D9")!
    static let accent = Color(hex: "#27AE60")!
    static let background = Color(UIColor.systemGroupedBackground)
    static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
}
