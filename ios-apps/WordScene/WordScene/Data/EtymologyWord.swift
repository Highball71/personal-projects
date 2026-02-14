import Foundation

/// A common English word with a surprising etymology or hidden meaning.
/// Used in the "Deeper Than You Knew" mode — static reference data, not persisted.
struct EtymologyWord: Identifiable {
    let id: String              // unique key (lowercase)
    let word: String            // the word as displayed
    let casualIntro: String     // casual "you probably use this" intro
    let originLanguage: String  // Greek, Latin, Arabic, etc.
    let breakdown: String       // root word breakdown, e.g. "sophos (wise) + moros (fool)"
    let literalMeaning: String  // what the roots literally translate to
    let originStory: String     // the full surprising origin story
}
