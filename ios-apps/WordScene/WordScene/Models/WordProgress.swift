import Foundation
import SwiftData

/// Tracks a user's spaced-repetition progress for a single vocabulary word.
/// SM-2 fields control when the word next appears for review.
@Model
final class WordProgress {
    /// Links to VocabularyWord.id
    var wordID: String

    // MARK: - SM-2 State

    /// Ease factor — controls how fast intervals grow (starts at 2.5, min 1.3)
    var easeFactor: Double

    /// Current interval in days between reviews
    var interval: Int

    /// Number of consecutive successful reviews (quality >= 3)
    var repetitions: Int

    /// When this word is next due for review
    var nextReviewDate: Date

    // MARK: - Tracking

    /// When the user first encountered this word
    var dateFirstSeen: Date

    /// When the user last reviewed this word
    var lastReviewDate: Date

    init(wordID: String) {
        self.wordID = wordID
        self.easeFactor = 2.5
        self.interval = 0
        self.repetitions = 0
        self.nextReviewDate = Date()
        self.dateFirstSeen = Date()
        self.lastReviewDate = Date()
    }

    /// Derived status based on SM-2 state.
    /// A word is "mastered" when it has been successfully reviewed at least 3 times
    /// and the interval has grown to at least 21 days.
    var status: WordStatus {
        if repetitions >= 3 && interval >= 21 {
            return .mastered
        } else {
            return .learning
        }
    }

    /// Applies an SM-2 review result to this progress entry
    func applyReview(_ result: SM2Engine.ReviewResult) {
        self.easeFactor = result.easeFactor
        self.interval = result.interval
        self.repetitions = result.repetitions
        self.nextReviewDate = result.nextReviewDate
        self.lastReviewDate = Date()
    }
}

/// The learning status of a word, derived from SM-2 state
enum WordStatus: String, CaseIterable {
    case new       // no WordProgress entry exists (determined externally)
    case learning  // entry exists but not yet mastered
    case mastered  // repetitions >= 3 AND interval >= 21 days
}
