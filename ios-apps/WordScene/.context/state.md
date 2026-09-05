# WordScene Reimagining — State

## Session log

### 2026-09-05 — Phase 0 (Office iMac, branch main, started at e708752)
Repo audited, seed set curated, data model proposed, PLAN.md written. No UI work (by design).

**Repo audit findings:**
- Existing app: SwiftUI, 4 tabs (Home/Deeper/Progress/Words), 100 words in 7 hand-written Swift category files + 10 etymology words, SM-2 engine, `WordProgress` SwiftData model, streaks + calendar heat map.
- Old scenarios *contain the word* — incompatible with scene-first teaching (decision #1). Old word list is frequency/fame-shaped (schadenfreude, ennui, sonder) — the exact "too easy" failure mode.
- Reusable: `SM2Engine` (pure), `StreakCalculator`, `DailyActivity`, app scaffolding. Replace: `WordProgress`, all word content. Undecided: etymology mode.
- No level-switch UX exists in the working tree **or anywhere in git history** — contradicts brief decision #2. Flagged, not reconciled (open question #1).
- `.teal` used at `WordScene/Views/ProgressTabView.swift:73` — remove in phase 1 design pass (design rule #10).

**Deliverables produced:**
- `Resources/seed/words.json` — 50 words (46 main across 9 domain ladders, 4 sideshow), validated: unique ids, scenes 60–120 words, no scene contains its word, ladder ranks contiguous per domain.
- `.context/data-model.md` — SwiftData-friendly model (seed as Codable, user state in `WordState`/`UserScene`/`ReviewLog`).
- `PLAN.md` — phases 1–3, voice loop is phase 1.

### 2026-09-05 (later) — Phase 1: voice loop MVP (Office iMac, branch wordscene-phase1 from b62964b)
David answered all four open questions (recorded in decisions.md): level switch built fresh as Broad/Narrow/Needle; etymology mode retired; teal fixed now; usesUnprompted only via explicit self-report.

**Shipped:**
- Seed layer: `SeedWord`/`SeedStore` (Codable, bundle JSON via new Resources synced group in pbxproj), `PrecisionTier` bands (Broad 1–2, Narrow 3–4, Needle 5+).
- SwiftData: `WordState` (mastery ladder + SM-2 scheduling + evidence counters; hard constraint encoded — review path caps at producesOnPrompt, only `recordUnpromptedUse()` reaches the top), `UserScene`, `ReviewLog`, kept `DailyActivity`.
- Services: `SpeechService` (AVSpeechSynthesizer; scene → 1.6s beat → word; UI reveal lands when the word utterance starts), `LessonBuilder` (3 words/lesson, same-domain neighbours arrive together), `ReviewBuilder` (recognition questions, distractors prefer learned same-domain words), `ActivityRecorder`.
- Views: `LessonView` (voice-first; scene text hidden unless asked), `ReviewView` (which-word-fits, shows the blurred distinction after a wrong pick), `HomeView` (tier switch + learn/review cards), `CollectionView` (domain ladders; unlearned words fully locked to protect the reveal), `ProgressTabView` (mastery ladder, streak, heat map — teal gone), `WordCardView`.
- Retired: all 100 old words + scenarios, etymology mode, old session managers and 8 views.
- Verified: simulator build succeeds; words.json in bundle; app launches on iPhone 16e sim, Home renders with seed data (screenshot). Interactive flows not yet exercised — blocked headless (see below).

**Environment note:** the Claude Code iOS Simulator MCP refuses with "Xcode is installed but not selected" and asks for `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, though `xcode-select -p` already prints that path. Needs David's password / a look. `simctl` works fine via `DEVELOPER_DIR` env var.

## Current status
Phase 1 shipped (code complete, builds, launches). Needs a human pass on device/simulator: hear the voice loop (open question: TTS quality), run a lesson + next-day review end-to-end. Then phase 2: production prompts, "I used it" UI, user-authored scenes, fresh review scenes.

### 2026-09-05 (later still) — Phase 2 A–E (Office iMac, branch wordscene-phase2 from 76c9ef0)
David deferred the OpenAI voice probe (no OPENAI_API_KEY) and directed: build the audio pipeline on AVSpeech with the best downloaded en-AU Premium voice (rate ~0.42–0.45), provider-pluggable, then proceed through B–E. NOTE: the A–E lettering wasn't in the repo; interpreted as the five PLAN.md phase-2 items with audio promoted to A (flagged to David in-session).

**Shipped:**
- E first (content): 46 fresh `reviewScene`s merged into words.json (v2), validated 40–100 words / no word stem ("office" scrubbed from officious again).
- A: `VoiceProfile` (best en-AU premium→enhanced→any-en fallback; scene 0.44 / word 0.42), `SpeechAudioGenerator` protocol + `AVSpeechFileGenerator` (AAC .m4a via synthesizer.write — verified in a standalone harness: 5.44s file produced), `AudioStore` actor (manifest, SHA-256 fingerprints over provider+voice+rate+text, lazy per-session generation, stale-file cleanup), `Narrator` (file playback with completion-driven beat via AVAudioPlayer delegate; transparent live-TTS fallback; same Phase enum drives the lesson reveal). Swapping in OpenAI TTS = one conforming file + one line in `SpeechAudioGeneratorFactory`.
- B: production prompts (type the word) for words ≥ Recognizes; `WordState.applyProductionOutcome` mirrors recognition with separate evidence date; promotion recognizes→producesOnPrompt at 2 correct days; still hard-capped below usesUnprompted.
- C: "I used it unprompted" on WordDetailView (confirmation dialog → recordUnpromptedUse) + weekly nudge card on Home when produces-tier words exist and nothing reported in 7 days.
- D: SceneComposerView (20–120 words, rejects scenes containing the word); entry points after lesson reveal and on word detail; user scenes shown on detail and preferred as review scenes.
- Verified: build clean; generator harness OK; app launches with v2 seed + migrated store (screenshot). Not verified headless: audible loop, tap-through flows (simulator MCP still refusing — see environment note).

## Current status
Phases 1–2 shipped. Awaiting: David's ears on the AVSpeech Premium loop; OPENAI_API_KEY for the TTS probe + provider swap; then phase 3 (scene→word finder, sideshow shelf, second word pack).

### 2026-09-05 (evening) — Lesson tail: spoken definition + neighbour (branch wordscene-lesson-tail from f3a134f)
David confirmed the A–E mapping and flagged a real gap: phase-2 decision 1 (fully spoken loop: scene → beat → word → definition → nearest-neighbour distinction) was neither in decisions.md nor implemented — the loop stopped at the word. Fixed: two new phases (speakingDefinition, speakingNeighbor); SpeechService queues four utterances with 0.8s postUtteranceDelay pauses; Narrator refactored to a queued file player (per-item phase + gap, completion-driven); definition and neighbour-line assets go through the same AudioStore fingerprinting (`<id>.definition`, `<id>.neighbor`); the card reveals word → definition → neighbours in step with audio (manual Reveal shows all at once). Decision recorded in decisions.md with the correction note.
Simulator MCP: xcode-select fix worked — the old error is gone; attach now waits on the one-time device-access prompt, which needs David at the keyboard.
