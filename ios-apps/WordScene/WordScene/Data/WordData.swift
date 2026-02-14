import Foundation

/// All vocabulary words, assembled from category files.
/// Each word has 2-3 funny scenarios, pronunciation, etymology, and definition.
let allWords: [VocabularyWord] =
    natureWords +
    emotionWords +
    languageWords +
    societyWords +
    intellectWords +
    bodyWords +
    miscWords

/// O(1) lookup by word ID — used by views mapping WordProgress.wordID back to full word data
let wordsByID: [String: VocabularyWord] = Dictionary(
    uniqueKeysWithValues: allWords.map { ($0.id, $0) }
)
