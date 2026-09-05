# WordScene Reimagining — Open Questions

Closed 2026-09-05 (answers recorded in decisions.md): #1 level switch (build Broad/Narrow/Needle fresh), #2 etymology mode (retire; sideshow shelf if revived), #3 teal (fixed in phase 1), plus the usesUnprompted constraint now encoded in WordState.

Still open:

1. ~~Fresh-scene supply~~ CLOSED 2026-09-05: 46 authored reviewScenes shipped (words.json v2); user-authored scenes preferred when present; API generation remains a future option for variety.

2. ~~OpenAI voice pick~~ CLOSED 2026-09-05: **sage** (ranking: sage > ash > onyx). Full set generated and bundled; AudioStore serves it bundle-first. Regenerate after any seed-text edit with `python3 scripts/generate_bundled_audio.py --voice sage` (only changed assets re-render).

3. **Sideshow fifth slot.** Held open deliberately (4/5 used). Candidates can come from direction-(b) scenes that resolve to undeployable-but-delightful words.
