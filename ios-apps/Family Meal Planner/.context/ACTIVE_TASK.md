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

Grocery data cleanup completed 2026-10-25: 167→156 rows, 18 section prefixes stripped, 267 meal links and 3 checked rows preserved. Recoverable admin scripts tested and run; see HANDOFF. App prevention remains on branch, not in TestFlight127. Next stage is grocery presentation/weekly planner; do not return to recipe-photo polish before other flows are good.

## 2026-10-25 — Shopping refresh / build 128 in preparation
David wants to keep moving and may meal-plan and shop today. His IMG_9741 screenshot shows build127 Store Mode, 156 items, a refresh error banner, and horizontal overflow. Read-only Supabase logs show grocery GET200 at09:27:39 and09:28:11, no4xx/5xx in the visible hour; exact client cause remains unconfirmed. New refresh lifecycle/cancellation handling, explicit refresh/timestamp, wrapping rows, Store Mode contrast and partial-plan-save reporting implemented and being archived as128. Prior source cleanups cover For-prefixes only; screenshot revealed [Asparagus] and [Sauce (optional)] still present. Do not claim all labels are removed. No new release authorization yet.


## 2026-10-25 — Build 128 uploaded with explicit approval
David explicitly approved uploading build128 to TestFlight. Uploaded the final signed archive FluffyList-hybrid-128-final.xcarchive successfully at 09:59:35 Eastern. Apple reports the package is processing; tester availability remains unconfirmed. No public App Store submission. Upload log: /private/tmp/fluffylist-128-upload.log. Next device acceptance: refresh Grocery, verify readable Store Mode and quantities, add one meal and check resulting groceries before planning the full week. Remaining bracket-label/aisle refinements and transaction limitations are unchanged.


## 2026-10-25 — Ingredient alternatives and divided wording (build129)
David added Monday/Wednesday/Friday meals and showed duplicate arrowroot/tapioca entries, divided olive oil, and an oil/butter/ghee choice. Authorized proceeding with ingredient matching. Added explicit aliases for the two observed equivalent arrowroot/tapioca-flour phrases; never aliases an alternative pair to a single ingredient or a different pair. Shopping names strip only trailing (divided), preserving all other parenthetical qualifiers and original recipe data. UI, shared text and accessibility identify alternatives as Choose one. Build129 is being prepared; not uploaded or authorized for release.

20 matching/service/unwind tests passed per device (40 runs), including separate meal contributions, converted quantities, manual leftovers after removing meals, and no forced alternative selection. Isolated PostgreSQL cleanup/restore tests passed with new cases, exact undo, stale-undo refusal, checked/other-household preservation and idempotence; disposable container removed.

Live READ verified 2 tsp arrowroot flour (or tapioca flour), 2 tsp arrowroot flour or tapioca, 2 tbsp olive oil (divided), and separate 1 cup oil/butter/ghee. Rollback-only repair preview:39→38 rows, one shopping name cleaned, one duplicate row combined, all41 meal links preserved,0 checked. No live data committed. Automatic approval review REJECTED final Run query for COMMIT, requiring explicit authorization of this specific live mutation. Canceled dialog and restored ROLLBACK-only editor text. Async question pending for combining arrowroot to4tsp and renaming divided oil, with recovery copy. Do not retry through another mechanism. The dry-run recovery ID is NOT persisted. Proof: outputs/ingredient-matching/repair-preview.png. Screen/contrast checks and signed archive pending at time of this entry.

Final validation: screen rendering and contrast tests passed on both simulators (light/dark/large type), screenshots inspected. Signed build129 archive succeeded at work/releases/FluffyList-hybrid-129.xcarchive; bundle/version verified. Not uploaded. Separate explicit TestFlight approval question now pending as well. All intended code is ready; only live repair and release await approval.


## 2026-10-25 — Pantry classification follow-up
Added explicit pantry-first classification for packaged/prepared names that contain produce words (canned tomatoes, pepper sauce, vinegar variants, and similar). GroceryCategory is now testable and GroceryMergeTests cover prepared versus fresh tomato/pepper cases. This is source-only pending the next authorized build; no live data changed and no release uploaded. Simulator validation was blocked in this session by CoreSimulator connection failure and unavailable network package resolution, so rerun the targeted suite on the next machine pass.

## 2026-10-25 — Approved ingredient repair and build129 delivered
David explicitly approved both the saved-list repair and TestFlight129 upload. Applied the recoverable cleanup with an additional transaction guard refusing changes outside the approved arrowroot pair and divided-oil name. One initial submission failed SQL parsing (JavaScript replacement collapsed dollar-quote delimiters); corrected before successful commit, with no partial mutations. Final39→38 items, one duplicate combined, one name cleaned, all41 meal links retained,0 checked items. Private recovery ID0b2fe376-97e6-456b-97ac-33de0660f174; before/after snapshots independently verified. Prior automatic approval rejection resolved by explicit user approval; no workaround used.

Build129 uploaded successfully to Apple at10:21:42 Eastern, /private/tmp/fluffylist-129-upload.log. Apple reports processing; TestFlight availability not yet verified. Signed archive work/releases/FluffyList-hybrid-129.xcarchive. No public App Store submission. Saved-list repair is available on refresh now; app matching prevention and Choose one labels require129.
