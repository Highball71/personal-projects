import Foundation
import SwiftData

/// Tracks vocabulary learning activity for a single calendar day.
/// Powers the streak counter and calendar heat map.
@Model
final class DailyActivity {
    /// The calendar date (normalized to midnight) for this activity record
    var date: Date

    /// Total words reviewed (both new and review) during this day
    var wordsReviewed: Int

    /// Words seen for the first time during this day
    var wordsLearned: Int

    init(date: Date) {
        // Normalize to start of day so we get one record per calendar day
        self.date = Calendar.current.startOfDay(for: date)
        self.wordsReviewed = 0
        self.wordsLearned = 0
    }
}
