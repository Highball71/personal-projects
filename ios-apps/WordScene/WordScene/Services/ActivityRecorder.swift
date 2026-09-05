import Foundation
import SwiftData

/// Records learning events in one place: appends to the ReviewLog and bumps
/// today's DailyActivity row (which powers the streak and heat map).
struct ActivityRecorder {

    /// Logs a lesson reveal: the user met a new word.
    static func recordReveal(wordID: String, in context: ModelContext) {
        context.insert(ReviewLog(wordID: wordID, activity: .reveal))
        let today = todayActivity(in: context)
        today.wordsLearned += 1
        today.wordsReviewed += 1 // learning counts toward the streak too
    }

    /// Logs a recognition-review answer.
    static func recordRecognition(wordID: String, correct: Bool, in context: ModelContext) {
        context.insert(ReviewLog(wordID: wordID, activity: .recognitionReview, correct: correct))
        todayActivity(in: context).wordsReviewed += 1
    }

    /// Finds or creates today's DailyActivity row.
    private static func todayActivity(in context: ModelContext) -> DailyActivity {
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<DailyActivity>(
            predicate: #Predicate { $0.date == today }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let fresh = DailyActivity(date: Date())
        context.insert(fresh)
        return fresh
    }
}
