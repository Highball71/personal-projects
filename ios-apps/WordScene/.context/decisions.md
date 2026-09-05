# WordScene Reimagining — Decisions

## From David's brief (2026-09-05) — settled, do not relitigate
1. **Scene-first teaching.** Vivid specific moment WITHOUT the word; feel the gap; then reveal. The gap is the teaching.
2. **Difficulty = precision, not frequency.** Rank by how narrow the word's job is. (Brief also said "keep the old level-switch UX" — no such UX exists in repo/history; see open questions.)
3. **Progression by domain ladders.** Words sit next to their neighbours; learn distinctions, not definitions.
4. **Review = recognition in context.** Fresh scene, which learned word fits. Spaced over days. Never "here's the word, define it."
5. **Mastery = unprompted use.** States: Seen → Recognizes → Produces on prompt → Uses unprompted.
6. **User-authored scenes**, two directions: (a) scene for a learned word; (b) scene for an unnamed feeling → app finds the word (later; doubles as content pipeline).
7. **Voice is the primary learning mode.** Scene, beat of silence, word. Visual mode for browsing/spelling/writing.
8. **Curated seed, ~50 words**, every one deployable in real speech. Curation delegated to Claude.
9. **Sideshow track**, clearly labelled, ≤5 fun-but-undeployable words. Must not dilute main.
10. **No deep teal anywhere.**

## Phase-0 curation decisions (Claude, delegated under #8)
- **9 domain ladders**: states-of-mind, wounded-pride, social-manner, ways-of-speaking, argument-and-evasion, effort-and-care, bodily-sensations, weather-and-light, blandness. 46 main words; ladders of 3–7, ordered broadest→narrowest via `ladderRank`.
- **Deployability bar**: every main word must survive the test "could David say this at dinner without sounding like he swallowed a thesaurus." Cut for fame/ease: schadenfreude, ennui, sonder, visceral, equanimity. Cut for undeployability: torpor kept only as a stated neighbour, casuistry etc. never considered in.
- **Neighbours may be outside the seed set.** The distinction line is the payload; the neighbour word doesn't need its own entry.
- **Sideshow (4)**: borborygmus, sesquipedalian, apricity, defenestration. `ladderRank: 0` = off-ladder. One slot held open for a future find.
- **petrichor is main, not sideshow**: internet-famous but it *is* the archetype — an oddly specific experience everyone has had and can name in speech.
- **Scenes are written to be heard** (voice-first): second person, concrete, ending at the gap. Hard rule enforced by validation: 60–120 words, never contains the word (nor a root-priming cousin — e.g. "office" was removed from the officious scene).
- **Data split**: content in bundle JSON (Codable), user state in SwiftData, joined on `wordID` — matches the existing app's proven pattern; content iterates without migrations. Details in data-model.md.
- **Fresh start on user data** — old `WordProgress` rows are meaningless under the mastery ladder; app isn't on TestFlight; no migration.
