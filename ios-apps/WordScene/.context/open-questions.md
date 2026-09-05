# WordScene Reimagining — Open Questions

Closed 2026-09-05 (answers recorded in decisions.md): #1 level switch (build Broad/Narrow/Needle fresh), #2 etymology mode (retire; sideshow shelf if revived), #3 teal (fixed in phase 1), plus the usesUnprompted constraint now encoded in WordState.

Still open:

1. ~~Fresh-scene supply~~ CLOSED 2026-09-05: 46 authored reviewScenes shipped (words.json v2); user-authored scenes preferred when present; API generation remains a future option for variety.

2. **TTS quality / OpenAI probe.** Pipeline is provider-pluggable and running on AVSpeech Premium en-AU (rate 0.44/0.42). Voice probe deferred — OPENAI_API_KEY unavailable this session. When the key exists: probe OpenAI TTS, and if it wins, add one `SpeechAudioGenerator` conformer + flip `SpeechAudioGeneratorFactory.make()`. Also still awaiting David's ears on the Premium-voice loop.

3. **Sideshow fifth slot.** Held open deliberately (4/5 used). Candidates can come from direction-(b) scenes that resolve to undeployable-but-delightful words.
