import Foundation
import SwiftData

/// Append-only event log: one row per learning event. Feeds streaks, the heat
/// map, and gives the promotion rules real data to be tuned against.
@Model
final class ReviewLog {
    var wordID: String
    var date: Date

    /// "reveal" | "recognitionReview" | "productionPrompt" | "unpromptedUse" | "sceneAuthored"
    var activity: String

    /// Whether the answer was right; nil where the event has no right/wrong
    /// (reveals, unprompted-use reports, scene authoring)
    var correct: Bool?

    init(wordID: String, activity: Activity, correct: Bool? = nil, date: Date = Date()) {
        self.wordID = wordID
        self.activity = activity.rawValue
        self.correct = correct
        self.date = date
    }

    enum Activity: String {
        case reveal
        case recognitionReview
        case productionPrompt
        case unpromptedUse
        case sceneAuthored
    }
}
