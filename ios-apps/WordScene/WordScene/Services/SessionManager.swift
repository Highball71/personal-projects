import Foundation
import SwiftData

/// Builds and manages a learning session — a sequence of cards mixing new and review words.
/// Created fresh each time the user starts a session.
@Observable
class SessionManager {

    /// A single card in the session
    struct SessionCard: Identifiable {
        let id = UUID()
        let word: VocabularyWord
        let scenarioIndex: Int  // which scenario to show (cycles through on reviews)
        let isReview: Bool      // true = review word, false = new word
    }

    /// All cards in this session, in order
    private(set) var cards: [SessionCard] = []

    /// Current position in the session
    private(set) var currentIndex: Int = 0

    /// Whether the session is complete
    var isComplete: Bool { currentIndex >= cards.count }

    /// The current card, or nil if session is complete
    var currentCard: SessionCard? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    /// How many cards are in this session
    var totalCards: Int { cards.count }

    /// How many new words are in this session
    var newWordCount: Int { cards.filter { !$0.isReview }.count }

    /// How many review words are in this session
    var reviewWordCount: Int { cards.filter { $0.isReview }.count }

    /// Session types
    enum SessionType {
        case mixed      // new + review words (default)
        case reviewOnly // only review words due for repetition
    }

    /// Builds a session by selecting words from the vocabulary.
    /// - Parameters:
    ///   - modelContext: SwiftData context to query WordProgress
    ///   - type: Whether to include new words or only reviews
    init(modelContext: ModelContext, type: SessionType = .mixed) {
        let descriptor = FetchDescriptor<WordProgress>()
        let allProgress = (try? modelContext.fetch(descriptor)) ?? []
        let progressByID = Dictionary(uniqueKeysWithValues: allProgress.map { ($0.wordID, $0) })

        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        // Words due for review: nextReviewDate is today or earlier
        let reviewCandidates = allProgress.filter { $0.nextReviewDate < tomorrow }
        let reviewWordIDs = Set(reviewCandidates.map(\.wordID))

        // Words never seen before
        let allProgressIDs = Set(allProgress.map(\.wordID))
        let newCandidates = allWords.filter { !allProgressIDs.contains($0.id) }

        var selectedCards: [SessionCard] = []

        switch type {
        case .reviewOnly:
            // Take up to 10 review words
            let reviewWords = reviewCandidates.shuffled().prefix(10)
            for progress in reviewWords {
                if let word = wordsByID[progress.wordID] {
                    let scenarioIndex = progress.repetitions % word.scenarios.count
                    selectedCards.append(SessionCard(
                        word: word,
                        scenarioIndex: scenarioIndex,
                        isReview: true
                    ))
                }
            }

        case .mixed:
            // Pick 2-4 review words
            let reviewCount = min(reviewCandidates.count, Int.random(in: 2...4))
            let selectedReviews = reviewCandidates.shuffled().prefix(reviewCount)
            for progress in selectedReviews {
                if let word = wordsByID[progress.wordID] {
                    let scenarioIndex = progress.repetitions % word.scenarios.count
                    selectedCards.append(SessionCard(
                        word: word,
                        scenarioIndex: scenarioIndex,
                        isReview: true
                    ))
                }
            }

            // Pick 2-3 new words
            let desiredNew = Int.random(in: 2...3)
            let newCount = min(newCandidates.count, desiredNew)
            let selectedNew = newCandidates.shuffled().prefix(newCount)
            for word in selectedNew {
                selectedCards.append(SessionCard(
                    word: word,
                    scenarioIndex: 0,
                    isReview: false
                ))
            }

            // If we have fewer than 4 total cards, fill with more of whatever is available
            if selectedCards.count < 4 {
                let currentIDs = Set(selectedCards.map(\.word.id))
                let remainingNew = newCandidates.filter { !currentIDs.contains($0.id) }
                let remainingReview = reviewCandidates.filter { !currentIDs.contains($0.wordID) }

                let needed = 4 - selectedCards.count
                // Prefer new words for filling
                for word in remainingNew.shuffled().prefix(needed) {
                    selectedCards.append(SessionCard(
                        word: word,
                        scenarioIndex: 0,
                        isReview: false
                    ))
                }
                // If still short, fill with more reviews
                if selectedCards.count < 4 {
                    let stillNeeded = 4 - selectedCards.count
                    let usedIDs = Set(selectedCards.map(\.word.id))
                    for progress in remainingReview.shuffled().prefix(stillNeeded) {
                        if let word = wordsByID[progress.wordID], !usedIDs.contains(word.id) {
                            let scenarioIndex = progress.repetitions % word.scenarios.count
                            selectedCards.append(SessionCard(
                                word: word,
                                scenarioIndex: scenarioIndex,
                                isReview: true
                            ))
                        }
                    }
                }
            }
        }

        // Shuffle so new and review words are interleaved randomly
        self.cards = selectedCards.shuffled()
    }

    /// Advance to the next card
    func advance() {
        currentIndex += 1
    }
}
