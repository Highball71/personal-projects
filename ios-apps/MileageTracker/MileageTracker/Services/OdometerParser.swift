import Foundation

/// Parses spoken odometer readings into digit strings.
/// Handles multiple speech recognition formats: raw digits, comma-separated,
/// English number words, and digit-by-digit dictation.
///
/// Three-pass strategy:
/// 1. Digit extraction — strip commas/spaces, check for 4+ digit chars
/// 2. English word-to-number — dictionary + accumulator (e.g. "forty-five thousand two hundred thirty-one")
/// 3. Digit-by-digit words — concatenate individual digit words (e.g. "four five two three one")
///
/// Returns the first result with 4+ digits, or nil if nothing valid found.
struct OdometerParser {

    static func parse(_ spoken: String) -> String? {
        // Pass 1: Direct digit extraction
        // Handles "45231", "45,231", "4 5 2 3 1", "45.231"
        let digitsOnly = spoken.filter { $0.isNumber }
        if digitsOnly.count >= 4 {
            return digitsOnly
        }

        // Pass 2: English word-to-number
        // Handles "forty-five thousand two hundred thirty-one"
        if let number = englishToNumber(spoken), String(number).count >= 4 {
            return String(number)
        }

        // Pass 3: Digit-by-digit word concatenation
        // Handles "four five two three one" → "45231"
        if let digits = digitWordsToString(spoken), digits.count >= 4 {
            return digits
        }

        return nil
    }

    // MARK: - Pass 2: English Word-to-Number

    /// Single-word number values used by the accumulator algorithm.
    private static let wordValues: [String: Int] = [
        "zero": 0, "oh": 0,
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18,
        "nineteen": 19, "twenty": 20, "thirty": 30, "forty": 40,
        "fifty": 50, "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
    ]

    /// Multiplier words that scale the current accumulator.
    private static let multipliers: [String: Int] = [
        "hundred": 100,
        "thousand": 1_000,
    ]

    /// Convert an English number phrase to an integer.
    /// Uses an accumulator algorithm: small numbers add, multipliers scale.
    /// Example: "forty-five thousand two hundred thirty-one"
    ///   forty(40) + five(5) = 45 → × thousand(1000) = 45000
    ///   two(2) × hundred(100) = 200 + thirty(30) + one(1) = 231
    ///   total = 45231
    private static func englishToNumber(_ text: String) -> Int? {
        // Normalize: lowercase, replace hyphens with spaces, strip non-alpha/space
        let normalized = text.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        guard !normalized.isEmpty else { return nil }

        var total = 0       // Running total (captures values after "thousand")
        var current = 0     // Current group accumulator
        var foundAny = false

        for word in normalized {
            if let value = wordValues[word] {
                current += value
                foundAny = true
            } else if let mult = multipliers[word] {
                if current == 0 { current = 1 }
                if mult == 1_000 {
                    // "thousand" pushes the current group into total
                    total += current * mult
                    current = 0
                } else {
                    // "hundred" scales within the current group
                    current *= mult
                }
                foundAny = true
            }
            // Skip unrecognized words (articles, filler, etc.)
        }

        guard foundAny else { return nil }
        return total + current
    }

    // MARK: - Pass 3: Digit-by-Digit Words

    /// Maps single digit words to their character.
    private static let digitWords: [String: String] = [
        "zero": "0", "oh": "0",
        "one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
        "six": "6", "seven": "7", "eight": "8", "nine": "9",
    ]

    /// Concatenate digit-by-digit words: "four five two three one" → "45231"
    private static func digitWordsToString(_ text: String) -> String? {
        let words = text.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        var result = ""
        for word in words {
            if let digit = digitWords[word] {
                result += digit
            }
            // Skip non-digit words — allows "four five two three one" mixed with filler
        }

        return result.isEmpty ? nil : result
    }
}
