#!/usr/bin/env python3
"""One-time generation of WordScene's bundled audio via OpenAI TTS.

Renders every main-track asset — scene, word, definition, neighbour line, and
review scene — as MP3 into Resources/audio/, plus audio-manifest.json mapping
asset IDs to filenames and text hashes. The app's AudioStore serves these
bundle-first; AVSpeech remains the fallback only for content the bundle can't
know about (user-authored scenes).

Request format and narration instructions mirror OpenAITTSGenerator.swift —
keep them in sync.

Usage:
  OPENAI_API_KEY=... python3 generate_bundled_audio.py --voice ash
  (add --force to regenerate assets whose files already exist and match)

Cost: ~230 requests, roughly 60k characters — around a dollar.
"""

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.request

MODEL = "gpt-4o-mini-tts"

INSTRUCTIONS = {
    "scene": (
        "Narrate this second-person scene like a warm, unhurried audiobook "
        "narrator. Measured pace, vivid but calm. Do not rush."
    ),
    "word": (
        "Say this single word slowly and clearly, like the satisfying answer "
        "to a riddle. Nothing else."
    ),
}


def sha256(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()


def tts(key: str, text: str, voice: str, style: str) -> bytes:
    body = json.dumps({
        "model": MODEL,
        "voice": voice,
        "input": text,
        "instructions": INSTRUCTIONS[style],
        "response_format": "mp3",
    }).encode()
    req = urllib.request.Request(
        "https://api.openai.com/v1/audio/speech",
        data=body,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=180) as resp:
                return resp.read()
        except Exception as e:
            if attempt == 3:
                raise
            print(f"    retry after error: {e}", file=sys.stderr)
            time.sleep(5)


def assets_for(word: dict):
    """Mirrors AudioStore.AssetRequest.lessonAssets + reviewScene."""
    n = word["neighbors"][0]
    yield f"{word['id']}.scene", word["systemScene"], "scene"
    yield f"{word['id']}.word", word["word"], "word"
    yield f"{word['id']}.definition", word["definition"], "scene"
    yield f"{word['id']}.neighbor", f"Not to be confused with {n['word']}. {n['distinction']}", "scene"
    if word.get("reviewScene"):
        yield f"{word['id']}.review", word["reviewScene"], "scene"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--voice", required=True, help="OpenAI voice, e.g. ash, sage, onyx")
    parser.add_argument("--force", action="store_true", help="regenerate even if file exists and text matches")
    args = parser.parse_args()

    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        sys.exit("OPENAI_API_KEY not set")

    here = os.path.dirname(os.path.abspath(__file__))
    seed_path = os.path.join(here, "..", "Resources", "seed", "words.json")
    audio_dir = os.path.join(here, "..", "Resources", "audio")
    manifest_path = os.path.join(audio_dir, "audio-manifest.json")
    os.makedirs(audio_dir, exist_ok=True)

    words = [w for w in json.load(open(seed_path))["words"] if w["track"] == "main"]

    manifest = {"provider": "openai-tts", "model": MODEL, "voice": args.voice, "entries": {}}
    if os.path.exists(manifest_path):
        old = json.load(open(manifest_path))
        if old.get("voice") == args.voice and not args.force:
            manifest["entries"] = old.get("entries", {})
        # A different voice starts a clean manifest; stale files get replaced below

    total = sum(1 for w in words for _ in assets_for(w))
    done = 0
    for w in words:
        for asset_id, text, style in assets_for(w):
            done += 1
            entry = manifest["entries"].get(asset_id)
            filename = f"{asset_id}.mp3"
            path = os.path.join(audio_dir, filename)
            if (entry and not args.force and entry.get("textHash") == sha256(text)
                    and os.path.exists(path)):
                continue  # up to date
            print(f"[{done}/{total}] {asset_id}", flush=True)
            audio = tts(key, text, args.voice, style)
            with open(path, "wb") as f:
                f.write(audio)
            manifest["entries"][asset_id] = {"filename": filename, "textHash": sha256(text)}
            # Save the manifest as we go so an interruption resumes cleanly
            with open(manifest_path, "w") as f:
                json.dump(manifest, f, indent=2, sort_keys=True)

    # Prune manifest entries and files for assets that no longer exist
    valid = {a for w in words for a, _, _ in assets_for(w)}
    for stale in sorted(set(manifest["entries"]) - valid):
        fn = manifest["entries"].pop(stale)["filename"]
        try:
            os.remove(os.path.join(audio_dir, fn))
        except FileNotFoundError:
            pass
        print(f"pruned {stale}")
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)

    size = sum(os.path.getsize(os.path.join(audio_dir, e["filename"]))
               for e in manifest["entries"].values())
    print(f"\nDone: {len(manifest['entries'])} assets, {size / 1e6:.1f} MB → {audio_dir}")


if __name__ == "__main__":
    main()
