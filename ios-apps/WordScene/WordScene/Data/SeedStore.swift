import Foundation

/// Loads and indexes the seed catalog from the app bundle.
/// All content questions ("what words exist", "what's next on this ladder")
/// are answered here; user-progress questions belong to SwiftData.
enum SeedStore {

    /// The decoded catalog. Crashing on failure is deliberate: a missing or
    /// malformed seed file is a build error, not a runtime condition to handle.
    static let catalog: SeedCatalog = {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json") else {
            fatalError("Seed file words.json missing from bundle — check the Resources synced group in the Xcode project.")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SeedCatalog.self, from: data)
        } catch {
            fatalError("Seed file words.json failed to decode: \(error)")
        }
    }()

    /// All words, main track and sideshow alike.
    static let allWords: [SeedWord] = catalog.words

    /// O(1) lookup by word ID — used wherever a WordState needs its content.
    static let wordsByID: [String: SeedWord] = Dictionary(
        uniqueKeysWithValues: allWords.map { ($0.id, $0) }
    )

    /// The teachable track, excluding sideshow words.
    static let mainWords: [SeedWord] = allWords.filter { $0.track == .main }

    /// Sideshow shelf (browse-only until phase 3).
    static let sideshowWords: [SeedWord] = allWords.filter { $0.track == .sideshow }

    /// Domain names in catalog order, restricted to domains that have a ladder.
    static let ladderDomains: [String] = catalog.domains.filter { domain in
        mainWords.contains { $0.domain == domain }
    }

    /// One domain's ladder, ordered broadest (rank 1) to narrowest.
    static func ladder(for domain: String) -> [SeedWord] {
        mainWords
            .filter { $0.domain == domain }
            .sorted { $0.ladderRank < $1.ladderRank }
    }

    /// Main-track words in a precision tier, ordered so that words from the
    /// same domain arrive together, walking each ladder bottom-up. This is
    /// what makes neighbours get learned next to each other (decision #3).
    static func mainWords(in tier: PrecisionTier) -> [SeedWord] {
        mainWords
            .filter { $0.tier == tier }
            .sorted {
                if $0.domain != $1.domain { return $0.domain < $1.domain }
                return $0.ladderRank < $1.ladderRank
            }
    }
}
