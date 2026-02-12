//
//  FractionFormatter.swift
//  Family Meal Planner
//
//  Converts between decimal quantities and cooking fractions.
//  Used for both display ("1 1/2") and input parsing ("1/2" → 0.5).

import Foundation

enum FractionFormatter {

    // MARK: - Formatting (Double → String)

    /// Format a decimal quantity as a cooking fraction where appropriate.
    /// Examples: 0.5 → "1/2", 1.5 → "1 1/2", 2.0 → "2", 1.7 → "1.7"
    static func formatAsFraction(_ value: Double) -> String {
        guard value > 0 else { return "0" }

        let whole = Int(value)
        let fractional = value - Double(whole)

        // Whole number — no fraction needed
        if fractional < 0.01 {
            return "\(whole)"
        }

        // Try to match the fractional part to a common cooking fraction
        if let fractionStr = closestFraction(fractional) {
            if whole == 0 {
                return fractionStr
            }
            return "\(whole) \(fractionStr)"
        }

        // Not a common fraction — use one decimal place
        if value == value.rounded() {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    /// Match a fractional value (0.0–1.0) to a common cooking fraction string.
    /// Returns nil if no close match is found.
    private static func closestFraction(_ value: Double) -> String? {
        let fractions: [(Double, String)] = [
            (1.0/8.0, "1/8"),
            (1.0/4.0, "1/4"),
            (1.0/3.0, "1/3"),
            (3.0/8.0, "3/8"),
            (1.0/2.0, "1/2"),
            (5.0/8.0, "5/8"),
            (2.0/3.0, "2/3"),
            (3.0/4.0, "3/4"),
            (7.0/8.0, "7/8"),
        ]

        for (target, label) in fractions {
            if abs(value - target) < 0.02 {
                return label
            }
        }
        return nil
    }

    // MARK: - Parsing (String → Double)

    /// Parse a fraction string into a Double.
    /// Handles: "3", "0.75", "1/2", "1 1/2"
    /// Returns nil if the string can't be parsed.
    static func parseFraction(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Try plain number first: "3" or "0.75"
        if let plain = Double(trimmed) {
            return plain
        }

        // Try simple fraction: "1/2"
        if let slashIndex = trimmed.firstIndex(of: "/") {
            let beforeSlash = trimmed[trimmed.startIndex..<slashIndex]
            let afterSlash = trimmed[trimmed.index(after: slashIndex)...]

            // Check for mixed number: "1 1/2"
            if let spaceIndex = beforeSlash.lastIndex(of: " ") {
                let wholePart = beforeSlash[beforeSlash.startIndex..<spaceIndex]
                let numeratorPart = beforeSlash[beforeSlash.index(after: spaceIndex)...]
                if let whole = Double(wholePart.trimmingCharacters(in: .whitespaces)),
                   let numerator = Double(numeratorPart),
                   let denominator = Double(afterSlash),
                   denominator != 0 {
                    return whole + numerator / denominator
                }
            }

            // Simple fraction: "1/2"
            if let numerator = Double(beforeSlash.trimmingCharacters(in: .whitespaces)),
               let denominator = Double(afterSlash.trimmingCharacters(in: .whitespaces)),
               denominator != 0 {
                return numerator / denominator
            }
        }

        return nil
    }
}
