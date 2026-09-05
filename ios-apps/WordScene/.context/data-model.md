# WordScene Data Model Proposal (Phase 0, 2026-09-05)

Follows the existing app's proven split: **static content as Codable structs, user state in SwiftData**, joined by `wordID` string keys. Content iterates by editing JSON — no schema migrations.

## Seed layer (bundle JSON → Codable structs, not persisted)

`Resources/seed/words.json` → decoded at launch into:

```swift
struct SeedWord: Codable, Identifiable {
    let id: String              // stable key, lowercase
    let word: String
    let ipa: String
    let partOfSpeech: String
    let definition: String      // one line, precise
    let domain: String          // e.g. "wounded-pride"
    let ladderRank: Int         // 1 = broadest in domain; 0 = off-ladder (sideshow)
    let track: Track            // main | sideshow
    let neighbors: [Neighbor]   // 2–3, each with the distinction stated
    let systemScene: String     // 60–120 words; never contains the word/definition
}

struct Neighbor: Codable {
    let word: String
    let distinction: String
}
```

Domains and ladders are derived from the seed (group by `domain`, sort by `ladderRank`) — nothing to persist.

## SwiftData models (user state only)

### WordState — one per word the user has met

```swift
@Model final class WordState {
    @Attribute(.unique) var wordID: String

    // Mastery ladder (decision #5) — explicit, evidence-based states
    var mastery: String         // "seen" | "recognizes" | "producesOnPrompt" | "usesUnprompted"
    var dateSeen: Date
    var dateRecognized: Date?
    var dateProduced: Date?
    var dateUsedUnprompted: Date?

    // Review scheduling (reuse SM2Engine — it's pure and already tested)
    var easeFactor: Double      // 2.5 start
    var intervalDays: Int
    var repetitions: Int
    var dueDate: Date
    var lastReviewedAt: Date?
    var consecutiveMisses: Int  // 2 misses ⇒ demote one rung, reset schedule
}
```

**Promotion rules (proposed, tunable):**
- `seen → recognizes`: 2 correct recognition reviews on separate days
- `recognizes → producesOnPrompt`: 2 correct production prompts (scene shown, user supplies the word) on separate days
- `producesOnPrompt → usesUnprompted`: user self-report — one "I used it" tap, with optional note
- Demotion: 2 consecutive misses at any rung drops one rung and resets the schedule

Key point: **mastery transitions are gated on evidence counts, not on SM-2 intervals.** SM-2 only decides *when* the next check happens; the mastery ladder decides *what kind* of check it is.

### UserScene — decision #6, both directions

```swift
@Model final class UserScene {
    @Attribute(.unique) var id: UUID
    var wordID: String?         // nil for direction (b): scene written for an unnamed feeling
    var text: String
    var kind: String            // "forWord" (retention) | "seekingWord" (phase 3)
    var createdAt: Date
    var resolvedWordID: String? // for seekingWord, once the app finds the word
}
```

User scenes with `wordID` set become extra review material for that word — this is also the pressure valve for the fresh-scene supply problem (see open-questions).

### ReviewLog — append-only event log

```swift
@Model final class ReviewLog {
    var wordID: String
    var date: Date
    var activity: String  // "reveal" | "recognitionReview" | "productionPrompt" | "unpromptedUse" | "sceneAuthored"
    var correct: Bool?    // nil where not applicable
}
```

Feeds streaks/heat map (replaces the per-day counters in `DailyActivity` with derivable truth) and gives tunable promotion rules real data to run on.

## What carries over from the existing app

| Existing | Verdict |
|---|---|
| `SM2Engine` | **Keep** — pure, no dependencies, exactly what the scheduler needs |
| `StreakCalculator`, `DailyActivity` | **Keep initially**, migrate to derive from `ReviewLog` later |
| `WordProgress` | **Replace** with `WordState` (no mastery ladder, wrong mastery definition) |
| `VocabularyWord` + 100 words in `Data/Words/*.swift` | **Retire** — scenarios contain the word (opposite of scene-first), difficulty is frequency-shaped |
| Etymology mode (`EtymologyWord`, Deeper tab) | **Undecided** — see open-questions; don't delete yet |
| Views | Rebuild in phase 1 (out of scope for phase 0) |

No migration needed for existing users: WordScene is marked complete, not on TestFlight, and the old `WordProgress` rows are meaningless under the new mastery model. Fresh start is correct.
