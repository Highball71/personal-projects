import Foundation

/// A vocabulary word with its definition and a funny scenario that uses it in context.
/// The scenario text contains the word naturally — the app highlights it at display time.
struct VocabularyWord: Identifiable {
    let id: String          // unique key (the word itself, lowercased)
    let word: String        // the vocabulary word as displayed
    let definition: String
    let partOfSpeech: String
    let scenario: String    // 2-3 sentence scenario containing the word
}
