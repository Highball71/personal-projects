import Foundation
import SwiftData

/// A user's progress on one seed word: where it sits on the mastery ladder,
/// and when it's next due for review. Content lives in SeedStore; this record
/// exists only once the user has met the word.
@Model
final class WordState {
    /// Links to SeedWord.id
    @Attribute(.unique) var wordID: String

    // MARK: - Mastery ladder

    /// Stored as MasteryStage.rawValue (SwiftData-friendly string).
    var masteryRaw: String

    /// Timestamps for each rung reached (nil = not reached yet)
    var dateSeen: Date
    var dateRecognized: Date?
    var dateProduced: Date?
    var dateUsedUnprompted: Date?

    // MARK: - Promotion evidence
    // Promotion is gated on evidence counts, not on SM-2 intervals.
    // "2 correct reviews on separate days" — so we count days, not answers.

    /// Days on which the user answered a recognition review correctly
    var recognitionEvidenceDays: Int
    /// Days on which the user answered a production prompt correctly (phase 2)
    var productionEvidenceDays: Int
    /// The last day recognition evidence was banked, so two answers in one
    /// sitting count once
    var lastEvidenceDate: Date?
    /// Same, for production prompts (separate so one day can bank both kinds)
    var lastProductionEvidenceDate: Date?
    /// Consecutive incorrect reviews; 2 demotes a rung and resets the schedule
    var consecutiveMisses: Int

    // MARK: - Review scheduling (SM-2)

    var easeFactor: Double
    var intervalDays: Int
    var repetitions: Int
    var dueDate: Date
    var lastReviewedAt: Date?

    init(wordID: String, seenOn date: Date = Date()) {
        self.wordID = wordID
        self.masteryRaw = MasteryStage.seen.rawValue
        self.dateSeen = date
        self.recognitionEvidenceDays = 0
        self.productionEvidenceDays = 0
        self.consecutiveMisses = 0
        self.easeFactor = 2.5
        self.intervalDays = 1
        self.repetitions = 0
        // First recognition review comes tomorrow — the gap needs a night's sleep
        self.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date)) ?? date
    }

    var mastery: MasteryStage {
        get { MasteryStage(rawValue: masteryRaw) ?? .seen }
        set { masteryRaw = newValue.rawValue }
    }

    /// Due for review if the due date is today or earlier.
    func isDue(on date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: dueDate) <= calendar.startOfDay(for: date)
    }

    // MARK: - Review outcomes

    /// Applies a recognition-review outcome: reschedules via SM-2 and banks
    /// promotion evidence.
    ///
    /// HARD CONSTRAINT (David, 2026-09-05): this path can never promote past
    /// `producesOnPrompt`. The `usesUnprompted` rung is reachable ONLY through
    /// `recordUnpromptedUse()` — review performance does not count as using
    /// the word in real life, no matter how strong it is.
    func applyRecognitionOutcome(correct: Bool, on date: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        // Reschedule with SM-2. Recognition is pass/fail, so we map to the
        // engine's extremes: confident-correct or no-clue.
        let result = SM2Engine.calculate(
            quality: correct ? .knewIt : .noClue,
            currentEaseFactor: easeFactor,
            currentInterval: intervalDays,
            currentRepetitions: repetitions
        )
        easeFactor = result.easeFactor
        intervalDays = result.interval
        repetitions = result.repetitions
        dueDate = result.nextReviewDate
        lastReviewedAt = date

        if correct {
            consecutiveMisses = 0
            // Bank at most one evidence day per calendar day
            let alreadyBankedToday = lastEvidenceDate.map { calendar.startOfDay(for: $0) == today } ?? false
            if !alreadyBankedToday {
                recognitionEvidenceDays += 1
                lastEvidenceDate = date
            }
            // seen → recognizes after 2 correct days. Note the cap: recognition
            // evidence alone never reaches producesOnPrompt (that needs
            // production prompts, phase 2) and NOTHING here reaches usesUnprompted.
            if mastery == .seen && recognitionEvidenceDays >= 2 {
                mastery = .recognizes
                dateRecognized = date
            }
        } else {
            consecutiveMisses += 1
            if consecutiveMisses >= 2 {
                demoteOneRung(on: date)
            }
        }
    }

    /// Applies a production-prompt outcome (scene shown, user supplies the
    /// word). Same shape as recognition, but banks production evidence and
    /// promotes recognizes → producesOnPrompt after 2 correct days.
    ///
    /// The same HARD CONSTRAINT applies: this path stops at producesOnPrompt.
    /// Producing the word on demand, however reliably, is not using it
    /// unprompted — only `recordUnpromptedUse()` reaches the top rung.
    func applyProductionOutcome(correct: Bool, on date: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        let result = SM2Engine.calculate(
            quality: correct ? .knewIt : .noClue,
            currentEaseFactor: easeFactor,
            currentInterval: intervalDays,
            currentRepetitions: repetitions
        )
        easeFactor = result.easeFactor
        intervalDays = result.interval
        repetitions = result.repetitions
        dueDate = result.nextReviewDate
        lastReviewedAt = date

        if correct {
            consecutiveMisses = 0
            let alreadyBankedToday = lastProductionEvidenceDate.map { calendar.startOfDay(for: $0) == today } ?? false
            if !alreadyBankedToday {
                productionEvidenceDays += 1
                lastProductionEvidenceDate = date
            }
            if mastery == .recognizes && productionEvidenceDays >= 2 {
                mastery = .producesOnPrompt
                dateProduced = date
            }
        } else {
            consecutiveMisses += 1
            if consecutiveMisses >= 2 {
                demoteOneRung(on: date)
            }
        }
    }

    /// The ONLY path to the top rung: the user explicitly reports having used
    /// the word unprompted in real life (decision #5 + hard constraint).
    /// Phase 1 ships the model support; the "I used it" UI arrives in phase 2.
    func recordUnpromptedUse(on date: Date = Date()) {
        mastery = .usesUnprompted
        dateUsedUnprompted = date
    }

    /// Drops one rung after repeated misses and resets the schedule so the
    /// word comes back like a near-new word.
    private func demoteOneRung(on date: Date) {
        switch mastery {
        case .usesUnprompted: mastery = .producesOnPrompt
        case .producesOnPrompt: mastery = .recognizes
        case .recognizes: mastery = .seen
        case .seen: break // nowhere lower to go
        }
        consecutiveMisses = 0
        recognitionEvidenceDays = 0
        productionEvidenceDays = 0
        easeFactor = 2.5
        intervalDays = 1
        repetitions = 0
        dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date)) ?? date
    }
}
