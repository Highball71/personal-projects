# WordScene Reimagining — Plan

Precision tool for words David half-recognizes. Scene first, word second; the gap is the teaching. Difficulty = how narrow the word's job is, never frequency. Full design decisions live in `.context/decisions.md`; data model in `.context/data-model.md`; seed content in `Resources/seed/words.json`.

## Phase 1 — Voice learning loop (MVP) — SHIPPED 2026-09-05

Ships:
- Seed import: decode `words.json`, group into domain ladders.
- New SwiftData models (`WordState`, `UserScene`, `ReviewLog`); retire old word content and `WordProgress`.
- **Voice-first lesson**: hear the scene (AVSpeechSynthesizer to start), a beat of silence, hear the word + IPA-guided pronunciation, then reveal card with definition and neighbors. Visual reading mode as fallback.
- Recognition review: fresh-ish scene shown, pick which learned word fits (system scene reworded/re-cued for now — see open question on scene supply), scheduled by SM2Engine.
- Mastery states Seen → Recognizes wired up; Progress tab shows the ladder per word.
- Domain-ladder browsing (replaces old Words tab) with the Broad / Narrow / Needle precision switch (decision 2026-09-05; unlearned words stay locked so the reveal isn't spoiled).
- Design pass: no deep teal anywhere (removes existing `.teal` in ProgressTabView).

## Phase 2 — Owning the words

Ships:
- Production prompts (scene shown → user says/types the word) → `producesOnPrompt` rung.
- "I used it" self-report → `usesUnprompted` rung; gentle weekly nudge to review the produces-tier words.
- User-authored scenes, direction (a): write a scene for a word you just learned; becomes review material for that word.
- Review-scene supply: second authored scene per word and/or Claude API generation (Meal Planner already has the integration pattern) with the same no-word-in-scene rule.
- Better TTS if AVSpeech quality disappoints (pre-generated audio or API voices).

## Phase 3 — The word finder + sideshow

Ships:
- Direction (b): write a scene for a feeling you have no word for; app proposes the word (Claude API). Good matches feed the content pipeline as candidate seed words.
- Sideshow track UI: clearly labelled, separate shelf (borborygmus et al.); never mixed into main reviews.
- Second 50-word pack, curated with the same precision axis; new domains as ladders fill up.
- Collection view: the learned-word shelf, browsable by domain, mastery shown per word.

## Explicitly out of scope
- Old etymology "Deeper" mode: retired in phase 1 (decision 2026-09-05); if revived, it lives on the sideshow shelf.
- Any frequency-based ranking, ever.
