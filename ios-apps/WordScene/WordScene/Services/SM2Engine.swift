import Foundation

/// Pure implementation of the SM-2 spaced repetition algorithm.
/// No SwiftData or UI dependencies — operates on plain values.
struct SM2Engine {

    /// The three quality ratings a user can give after seeing a word
    enum Quality: Int {
        case noClue = 1      // had no idea what it meant
        case hadAHunch = 3   // recognized it or partially guessed
        case knewIt = 5      // knew the definition confidently
    }

    /// The result of an SM-2 calculation
    struct ReviewResult {
        let easeFactor: Double
        let interval: Int       // days until next review
        let repetitions: Int    // successful reviews in a row
        let nextReviewDate: Date
    }

    /// Runs the SM-2 algorithm given the user's quality rating and the word's current state.
    ///
    /// - Parameters:
    ///   - quality: How well the user knew the word
    ///   - currentEaseFactor: The word's current ease factor (starts at 2.5)
    ///   - currentInterval: The word's current interval in days
    ///   - currentRepetitions: How many consecutive successful reviews
    /// - Returns: Updated SM-2 values to store back in WordProgress
    static func calculate(
        quality: Quality,
        currentEaseFactor: Double,
        currentInterval: Int,
        currentRepetitions: Int
    ) -> ReviewResult {
        let q = Double(quality.rawValue)
        var ef = currentEaseFactor
        var interval = currentInterval
        var reps = currentRepetitions

        if quality.rawValue < 3 {
            // Failed — reset the chain
            reps = 0
            interval = 1
        } else {
            // Passed — advance
            reps += 1
            switch reps {
            case 1: interval = 1
            case 2: interval = 6
            default: interval = Int(round(Double(currentInterval) * ef))
            }
        }

        // Update ease factor using SM-2 formula
        ef = ef + (0.1 - (5.0 - q) * (0.08 + (5.0 - q) * 0.02))
        ef = max(1.3, ef) // minimum ease factor

        let nextDate = Calendar.current.date(
            byAdding: .day, value: interval, to: Date()
        ) ?? Date()

        return ReviewResult(
            easeFactor: ef,
            interval: interval,
            repetitions: reps,
            nextReviewDate: nextDate
        )
    }
}
