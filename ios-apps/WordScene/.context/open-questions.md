# WordScene Reimagining — Open Questions

Closed 2026-09-05 (answers recorded in decisions.md): #1 level switch (build Broad/Narrow/Needle fresh), #2 etymology mode (retire; sideshow shelf if revived), #3 teal (fixed in phase 1), plus the usesUnprompted constraint now encoded in WordState.

Still open:

1. **Fresh-scene supply for reviews.** Decision #4 requires a *fresh* scene at review time, but the seed carries one system scene per word. Phase 1 reuses the system scene (weak but workable for first reviews); real fix is phase 2: a second authored scene per word, user-authored scenes, and/or Claude API generation (Meal Planner has the integration pattern). Which mix does David want, and is on-device-only a constraint?

2. **TTS quality.** Phase 1 starts with AVSpeechSynthesizer (free, offline). If the voice undermines the mood of the scenes, alternatives: pre-generated audio bundled per scene, or API voices. Decide after hearing it on device.

3. **Sideshow fifth slot.** Held open deliberately (4/5 used). Candidates can come from direction-(b) scenes that resolve to undeployable-but-delightful words.
