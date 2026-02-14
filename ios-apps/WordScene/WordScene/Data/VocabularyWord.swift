import Foundation

/// A vocabulary word with its definition, pronunciation, etymology, and funny scenarios.
/// This is static reference data — not persisted in SwiftData.
struct VocabularyWord: Identifiable {
    let id: String              // unique key (lowercase, hyphenated for multi-word)
    let word: String            // the vocabulary word as displayed
    let pronunciation: String   // phonetic pronunciation guide
    let definition: String
    let etymology: String       // word origin story
    let partOfSpeech: String
    let scenarios: [String]     // 2-3 funny scenarios using the word in context
}
