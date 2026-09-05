# WordScene Reimagining — Open Questions

1. **Level-switch UX (blocking phase 1 browsing UI).** The brief says "keep the old level-switch UX; change what the levels mean" — but no level switch exists in the current app or anywhere in git history (checked both the original 30-word version and the 100-word rebuild; tabs only). Is David remembering a different app, a planned-but-unbuilt feature, or an Apple Notes sketch? Options if it doesn't exist: (a) build a precision-tier switch fresh (Broad / Narrow / Needle, mapping to ladderRank bands), or (b) skip levels and browse by domain ladder only. Ask David before phase 1 UI.

2. **Etymology "Deeper" mode.** Existing feature (10 words, own tab, own progress model), not mentioned in the brief. Keep as-is, retire, or fold its spirit into the sideshow track? Costs nothing to leave dormant during phase 1.

3. **Fresh-scene supply for reviews.** Decision #4 requires a *fresh* scene at review time, but the seed carries one system scene per word. Phase 1 will reuse the system scene (weak but workable for first reviews); real fix is phase 2: a second authored scene per word, user-authored scenes, and/or Claude API generation (Meal Planner has the integration pattern). Which mix does David want, and is on-device-only a constraint?

4. **TTS quality.** Phase 1 starts with AVSpeechSynthesizer (free, offline). If the voice undermines the mood of the scenes, alternatives: pre-generated audio bundled per scene, or API voices. Decide after hearing it.

5. **Sideshow fifth slot.** Held open deliberately (4/5 used). Candidates can come from direction-(b) scenes that resolve to undeployable-but-delightful words.
