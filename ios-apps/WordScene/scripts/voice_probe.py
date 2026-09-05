#!/usr/bin/env python3
"""WordScene voice probe: render the full lesson beat for a few words in
several OpenAI TTS voices, one combined WAV per (voice, word), with the app's
real gap timings (1.6s beat, 0.8s short pauses) baked in as silence.

Usage:
  OPENAI_API_KEY=... python3 voice_probe.py [outdir]

Requires only the Python standard library. Never prints the API key.
"""

import json
import os
import sys
import time
import urllib.request
import wave

WORDS = ["equivocate", "obfuscate", "insipid"]  # same words as the AVSpeech lesson, for A/B
VOICES = ["ash", "sage", "onyx"]
MODEL = "gpt-4o-mini-tts"

BEAT = 1.6        # silence after the scene — the gap is the teaching
SHORT_PAUSE = 0.8  # after the word, and after the definition

INSTRUCTIONS = {
    "scene": (
        "Narrate this second-person scene like a warm, unhurried audiobook "
        "narrator. Measured pace, vivid but calm. Do not rush."
    ),
    "word": (
        "Say this single word slowly and clearly, like the satisfying answer "
        "to a riddle. Nothing else."
    ),
    "definition": "Read this definition clearly, at a calm, measured pace.",
    "neighbor": (
        "Read this contrast between two similar words clearly and calmly, "
        "with a slight emphasis on each word being contrasted."
    ),
}


def tts(key: str, text: str, voice: str, instructions: str) -> bytes:
    body = json.dumps({
        "model": MODEL,
        "voice": voice,
        "input": text,
        "instructions": instructions,
        "response_format": "wav",
    }).encode()
    req = urllib.request.Request(
        "https://api.openai.com/v1/audio/speech",
        data=body,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=180) as resp:
                return resp.read()
        except Exception as e:  # transient errors: brief backoff, retry
            if attempt == 2:
                raise
            print(f"    retry after error: {e}", file=sys.stderr)
            time.sleep(3)


def wav_frames(data: bytes):
    """Returns (params, frames) from a WAV byte string."""
    import io
    with wave.open(io.BytesIO(data)) as w:
        return w.getparams(), w.readframes(w.getnframes())


def combine(segments, gaps, out_path):
    """Concatenates WAV segments with the given silence gap (seconds) after
    each one. All segments must share sample format (they do: same model)."""
    params, _ = wav_frames(segments[0])
    silence_frame = b"\x00" * (params.sampwidth * params.nchannels)

    with wave.open(out_path, "wb") as out:
        # Set format fields individually — streamed WAVs carry a bogus
        # frame-count in their header, and copying it overflows the writer
        out.setnchannels(params.nchannels)
        out.setsampwidth(params.sampwidth)
        out.setframerate(params.framerate)
        for seg, gap in zip(segments, gaps):
            p, frames = wav_frames(seg)
            assert (p.framerate, p.sampwidth, p.nchannels) == (
                params.framerate, params.sampwidth, params.nchannels
            ), "segment format mismatch"
            out.writeframes(frames)
            if gap > 0:
                out.writeframes(silence_frame * int(p.framerate * gap))


def spoken_neighbor_line(word_entry) -> str:
    n = word_entry["neighbors"][0]
    return f"Not to be confused with {n['word']}. {n['distinction']}"


def main():
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        sys.exit("OPENAI_API_KEY not set")

    here = os.path.dirname(os.path.abspath(__file__))
    seed_path = os.path.join(here, "..", "Resources", "seed", "words.json")
    catalog = {w["id"]: w for w in json.load(open(seed_path))["words"]}

    outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Desktop/WordScene-voice-probe")
    os.makedirs(outdir, exist_ok=True)

    for voice in VOICES:
        voice_dir = os.path.join(outdir, voice)
        os.makedirs(voice_dir, exist_ok=True)
        for word_id in WORDS:
            w = catalog[word_id]
            print(f"[{voice}] {word_id} …", flush=True)
            segments = [
                tts(key, w["systemScene"], voice, INSTRUCTIONS["scene"]),
                tts(key, w["word"], voice, INSTRUCTIONS["word"]),
                tts(key, w["definition"], voice, INSTRUCTIONS["definition"]),
                tts(key, spoken_neighbor_line(w), voice, INSTRUCTIONS["neighbor"]),
            ]
            combine(segments, [BEAT, SHORT_PAUSE, SHORT_PAUSE, 0], os.path.join(voice_dir, f"{word_id}.wav"))

    with open(os.path.join(outdir, "README.txt"), "w") as f:
        f.write(
            "WordScene voice probe — OpenAI TTS (model: %s)\n\n"
            "One WAV per voice per word: the full lesson beat with real gaps\n"
            "(scene, 1.6s silence, word, 0.8s, definition, 0.8s, neighbour line).\n\n"
            "Voices: %s\n"
            "Words: %s (the same three the AVSpeech lesson played, for A/B).\n\n"
            "Pick a voice; the full asset set gets generated once with it and\n"
            "bundled into the app.\n" % (MODEL, ", ".join(VOICES), ", ".join(WORDS))
        )
    print(f"\nDone → {outdir}")


if __name__ == "__main__":
    main()
