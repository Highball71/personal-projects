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

## Current status
Phase 0 complete. Next session: resolve open question #1 (level switch), then start phase 1 (voice loop). Do not begin UI before David answers the level-switch question — or decide to build ladder-browse-only and skip levels.
