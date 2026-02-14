import Foundation
import SwiftData

/// Builds and manages a learning session for etymology words.
/// Similar to SessionManager but works with EtymologyWord and EtymologyProgress.
@Observable
class EtymologySessionManager {

    /// A single card in the session
    struct SessionCard: Identifiable {
        let id = UUID()
        let word: EtymologyWord
        let isReview: Bool
    }

    /// Session types
    enum SessionType {
        case mixed
        case reviewOnly
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

    /// Builds a session by selecting etymology words.
    init(modelContext: ModelContext, type: SessionType = .mixed) {
        let descriptor = FetchDescriptor<EtymologyProgress>()
        let allProgress = (try? modelContext.fetch(descriptor)) ?? []
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        // Words due for review
        let reviewCandidates = allProgress.filter { $0.nextReviewDate < tomorrow }

        // Words never seen before
        let allProgressIDs = Set(allProgress.map(\.wordID))
        let newCandidates = allEtymologyWords.filter { !allProgressIDs.contains($0.id) }

        var selectedCards: [SessionCard] = []

        switch type {
        case .reviewOnly:
            let reviewWords = reviewCandidates.shuffled().prefix(10)
            for progress in reviewWords {
                if let word = etymologyByID[progress.wordID] {
                    selectedCards.append(SessionCard(word: word, isReview: true))
                }
            }

        case .mixed:
            // Pick up to 2 review words
            let reviewCount = min(reviewCandidates.count, 2)
            let selectedReviews = reviewCandidates.shuffled().prefix(reviewCount)
            for progress in selectedReviews {
                if let word = etymologyByID[progress.wordID] {
                    selectedCards.append(SessionCard(word: word, isReview: true))
                }
            }

            // Pick up to 3 new words
            let newCount = min(newCandidates.count, 3)
            let selectedNew = newCandidates.shuffled().prefix(newCount)
            for word in selectedNew {
                selectedCards.append(SessionCard(word: word, isReview: false))
            }

            // Fill to at least 3 cards if possible
            if selectedCards.count < 3 {
                let currentIDs = Set(selectedCards.map(\.word.id))
                let remainingNew = newCandidates.filter { !currentIDs.contains($0.id) }
                for word in remainingNew.shuffled().prefix(3 - selectedCards.count) {
                    selectedCards.append(SessionCard(word: word, isReview: false))
                }
            }
        }

        self.cards = selectedCards.shuffled()
    }

    /// Advance to the next card
    func advance() {
        currentIndex += 1
    }
}
