import Foundation

/// All etymology words for the "Deeper Than You Knew" mode.
let allEtymologyWords: [EtymologyWord] = etymologyWords

/// O(1) lookup by etymology word ID
let etymologyByID: [String: EtymologyWord] = Dictionary(
    uniqueKeysWithValues: allEtymologyWords.map { ($0.id, $0) }
)
