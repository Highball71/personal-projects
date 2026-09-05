# WordScene Reimagining — Open Questions

Closed 2026-09-05 (answers recorded in decisions.md): #1 level switch (build Broad/Narrow/Needle fresh), #2 etymology mode (retire; sideshow shelf if revived), #3 teal (fixed in phase 1), plus the usesUnprompted constraint now encoded in WordState.

Still open:

1. ~~Fresh-scene supply~~ CLOSED 2026-09-05: 46 authored reviewScenes shipped (words.json v2); user-authored scenes preferred when present; API generation remains a future option for variety.

2. **OpenAI voice pick (BLOCKING full audio generation).** Probe delivered 2026-09-05: ~/Desktop/WordScene-voice-probe/ has the full lesson beat for equivocate/obfuscate/insipid in ash, sage, and onyx (gpt-4o-mini-tts, real gap timings baked in). David picks; then run:
   `OPENAI_API_KEY=... python3 scripts/generate_bundled_audio.py --voice <pick>`
   which fills Resources/audio/ (~230 MP3s + audio-manifest.json, ~$1) — commit the output and the bundle serves it. Until then the app behaves as before (on-device AVSpeech).

3. **Sideshow fifth slot.** Held open deliberately (4/5 used). Candidates can come from direction-(b) scenes that resolve to undeployable-but-delightful words.
