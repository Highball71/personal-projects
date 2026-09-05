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

## Phase-1 decisions (David, 2026-09-05)
- **Level switch**: never existed in code — the brief was sourced from an old design discussion. Build fresh: **Broad / Narrow / Needle**, mapped to ladder-rank bands (Broad = ranks 1–2, Narrow = 3–4, Needle = 5+). Closes open question #1.
- **Etymology "Deeper" mode**: retired in phase 1. If revived later, it lives on the sideshow shelf. Closes open question #2.
- **`.teal` in ProgressTabView**: fixed in phase 1, not deferred. Closes open question #3.
- **Mastery constraint**: the `usesUnprompted` rung may ONLY be reached via an explicit user-reported "I used it" event. Review performance can never promote to it. Encoded in `WordState` (separate `recordUnpromptedUse()` method; review path caps at `producesOnPrompt`).

## Phase-2 decisions (David, 2026-09-05)
1. **Lesson loop is fully spoken**: scene → beat of silence (1.6s) → word → short pause (~0.8s) → one-line definition → short pause → one nearest-neighbour distinction. The nearest neighbour is the first listed in the seed. All four elements are generated through the same AudioStore fingerprinting; each has its own phase in the lesson phase enum so the card reveals word → definition → neighbours in step with the audio. (Was missing from this file until 2026-09-05 — the loop originally stopped at the word; corrected same day.)

## Audio provider decisions (David, 2026-09-05)
- **Seed audio is generated once and bundled**, not synthesized on-device and not fetched from the API at runtime: main-track content is fixed, so `scripts/generate_bundled_audio.py` renders every asset (scene, word, definition, neighbour line, review scene — main track only) with OpenAI TTS (gpt-4o-mini-tts) into `Resources/audio/` + `audio-manifest.json`, keyed by text hash so edited scenes stop matching automatically. AudioStore serves bundle-first.
- **AVSpeech remains the fallback for user scenes only** (and interim seed content until the bundle is generated). The factory still returns the AVSpeech generator; `OpenAITTSGenerator` implements the same seam for tooling/server use.
- **Voice: sage** (David, 2026-09-05). Probe ranking: sage > ash > onyx. Full main-track set generated with `--voice sage` and bundled in Resources/audio/.

## Phase-0 curation decisions (Claude, delegated under #8)
- **9 domain ladders**: states-of-mind, wounded-pride, social-manner, ways-of-speaking, argument-and-evasion, effort-and-care, bodily-sensations, weather-and-light, blandness. 46 main words; ladders of 3–7, ordered broadest→narrowest via `ladderRank`.
- **Deployability bar**: every main word must survive the test "could David say this at dinner without sounding like he swallowed a thesaurus." Cut for fame/ease: schadenfreude, ennui, sonder, visceral, equanimity. Cut for undeployability: torpor kept only as a stated neighbour, casuistry etc. never considered in.
- **Neighbours may be outside the seed set.** The distinction line is the payload; the neighbour word doesn't need its own entry.
- **Sideshow (4)**: borborygmus, sesquipedalian, apricity, defenestration. `ladderRank: 0` = off-ladder. One slot held open for a future find.
- **petrichor is main, not sideshow**: internet-famous but it *is* the archetype — an oddly specific experience everyone has had and can name in speech.
- **Scenes are written to be heard** (voice-first): second person, concrete, ending at the gap. Hard rule enforced by validation: 60–120 words, never contains the word (nor a root-priming cousin — e.g. "office" was removed from the officious scene).
- **Data split**: content in bundle JSON (Codable), user state in SwiftData, joined on `wordID` — matches the existing app's proven pattern; content iterates without migrations. Details in data-model.md.
- **Fresh start on user data** — old `WordProgress` rows are meaningless under the mastery ladder; app isn't on TestFlight; no migration.
