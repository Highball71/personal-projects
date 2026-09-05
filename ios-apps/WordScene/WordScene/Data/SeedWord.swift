import Foundation

/// One curated word from the seed catalog (Resources/seed/words.json).
/// Static reference data — never persisted in SwiftData. User progress for a
/// word lives in `WordState`, joined to this by `id`.
struct SeedWord: Codable, Identifiable, Hashable {
    let id: String              // stable key, lowercase (e.g. "petrichor")
    let word: String            // the word as displayed
    let ipa: String             // IPA pronunciation, e.g. "/ˈpɛtrɪˌkɔːr/"
    let partOfSpeech: String
    let definition: String      // one line, precise
    let domain: String          // domain ladder this word belongs to, e.g. "wounded-pride"
    let ladderRank: Int         // 1 = broadest in its domain; 0 = off-ladder (sideshow)
    let track: Track
    let neighbors: [Neighbor]   // 2–3 near-neighbours, each with the distinction stated
    let systemScene: String     // 60–120 words; never contains the word or its definition

    /// A second, fresh scene used at review time (decision #4: review shows a
    /// FRESH scene, never a replay of the lesson). Main-track words only.
    let reviewScene: String?

    /// Which precision tier this word's ladder rank falls into.
    var tier: PrecisionTier { PrecisionTier(ladderRank: ladderRank) }

    /// Human-readable domain name: "wounded-pride" → "Wounded pride"
    var domainDisplayName: String {
        domain.replacingOccurrences(of: "-", with: " ").capitalized(firstWordOnly: true)
    }
}

/// A word that lives near a seed word in meaning, with the distinction spelled out.
/// The distinction is the payload — the neighbor itself need not be in the seed set.
struct Neighbor: Codable, Hashable {
    let word: String
    let distinction: String
}

/// Main track = deployable precision words. Sideshow = fun but undeployable,
/// kept on a clearly separate shelf so it never dilutes the main track.
enum Track: String, Codable {
    case main
    case sideshow
}

/// The level switch (decision, 2026-09-05): difficulty means precision, not
/// frequency, so the tiers band words by how narrow their job is (ladder rank).
enum PrecisionTier: String, CaseIterable, Identifiable {
    case broad   // ladder ranks 1–2: useful everyday distinctions
    case narrow  // ladder ranks 3–4: a more specific job
    case needle  // ladder ranks 5+: names one exact thing

    var id: String { rawValue }

    init(ladderRank: Int) {
        switch ladderRank {
        case ...2: self = .broad
        case 3...4: self = .narrow
        default: self = .needle
        }
    }

    var displayName: String {
        switch self {
        case .broad: return "Broad"
        case .narrow: return "Narrow"
        case .needle: return "Needle"
        }
    }

    var blurb: String {
        switch self {
        case .broad: return "Sturdy distinctions you can use every day"
        case .narrow: return "Words with a more specific job"
        case .needle: return "Each one names exactly one thing"
        }
    }
}

/// Top-level shape of Resources/seed/words.json.
struct SeedCatalog: Codable {
    let version: Int
    let generated: String
    let notes: String
    let domains: [String]
    let words: [SeedWord]
}

private extension String {
    /// Capitalizes only the first character, leaving the rest lowercase words
    /// intact ("wounded pride" → "Wounded pride", not "Wounded Pride").
    func capitalized(firstWordOnly: Bool) -> String {
        guard firstWordOnly, let first = first else { return capitalized }
        return first.uppercased() + dropFirst()
    }
}
