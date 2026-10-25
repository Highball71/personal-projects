# ACTIVE_TASK.md — FluffyList

**Session Focus:** (2026-10-21 — Claude Code, MacBook Air) **Week Overlap badge in the recipe picker** (Ingredient Chaining Phase 1, observational only), on branch `week-overlap-badge` (NOT merged to main — David merges after his device pass). Details in HANDOFF, 2026-10-21 entry.

**Suite: 289 tests, 0 failures** (272 + 8 `PhotoAttachTests` from main + 9 `WeekOverlapTests`), after the rebase onto main `e3727ad`. Zero warnings.

### Device-pass checklist (David)

- [ ] Plan 2–3 recipes this week → open the picker on another day → the "ALSO USES …" line appears only on recipes sharing perishables with them.
- [ ] No badge on recipes already planned this week.
- [ ] A staple-only overlap (oil, salt, garlic, onion…) shows nothing.
- [ ] The badge composes with the seasonal leaf / "IN SEASON" line and the dietary hint without clipping on iPhone.
- [ ] Adding a badged recipe behaves exactly as before on the grocery list.

## Next up

0. **Device pass of `week-overlap-badge`** (checklist above), then merge.
1. **Device pass of empty-week + region prompt** (checklist in HANDOFF, 2026-09-04 later entry — includes the on-device location flow), then merge `empty-week-and-region` to main.
2. **iPad phase 2** (when David says go): week view, recipe list, grocery list on regular width.
3. Announcement email for the 113/116 rollout.
4. Seasonal v1.5 (parked): seasonal produce list into the AI suggestion prompt.
5. Parked: Engineer Mode; pantry-scan suggestions; community recipes; toast icon string-match cosmetic. Doc nit: RULES/CLAUDE.md still say "target iOS 17+" — the project's deployment target is 26.2.

## Current redesign continuation — October 25
Branch codex/fluffylist-hybrid-redesign: scan-first optional cookbook-photo step implemented and locally validated. Migration 021 and device delivery pending. See latest HANDOFF entries and RECIPE_CORRECTIONS.md. Shopping-list duplicates/section headings are the next investigation; no live grocery cleanup has run.


## 2026-10-25 — Prioritize breadth over recipe polish
David accepted the scan-first optional cookbook-photo experience and asked to move other areas to good before further polish. Next focus is grocery integrity: suppress legacy recipe-section headings on new additions and normalize explicit [For …] ingredient prefixes, then separately reconcile existing duplicates without losing contributions. Recipe crop/spacing polish deferred. No new release authorized in this turn.
