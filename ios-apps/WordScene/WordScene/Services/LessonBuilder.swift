import Foundation

/// Picks the next new words to teach. Pure — no SwiftData dependency; the
/// caller supplies the set of already-learned word IDs.
struct LessonBuilder {

    /// New words per lesson. Small on purpose: three vivid gaps beat ten blurry ones.
    static let wordsPerLesson = 3

    /// The next unseen main-track words in the chosen precision tier.
    /// Order comes from SeedStore: same-domain words arrive together, walking
    /// each ladder bottom-up, so neighbours get learned side by side.
    static func nextWords(
        tier: PrecisionTier,
        learnedWordIDs: Set<String>,
        count: Int = wordsPerLesson
    ) -> [SeedWord] {
        SeedStore.mainWords(in: tier)
            .filter { !learnedWordIDs.contains($0.id) }
            .prefix(count)
            .map { $0 }
    }

    /// How many unseen words remain in a tier (for the Home screen).
    static func remainingCount(tier: PrecisionTier, learnedWordIDs: Set<String>) -> Int {
        SeedStore.mainWords(in: tier).filter { !learnedWordIDs.contains($0.id) }.count
    }
}
