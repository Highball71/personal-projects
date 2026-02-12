import Foundation
import SwiftData

/// Tracks whether the user has seen a word and if they already knew it.
/// A word is "mastered" when the user taps "Knew it."
@Model
final class WordProgress {
    var wordID: String
    var knewIt: Bool
    var dateEncountered: Date

    init(wordID: String, knewIt: Bool) {
        self.wordID = wordID
        self.knewIt = knewIt
        self.dateEncountered = Date()
    }
}
