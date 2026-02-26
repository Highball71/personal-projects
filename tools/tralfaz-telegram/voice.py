import httpx
from config import OPENAI_API_KEY

WHISPER_URL = "https://api.openai.com/v1/audio/transcriptions"
TTS_URL = "https://api.openai.com/v1/audio/speech"


async def transcribe_voice(oga_bytes: bytes) -> str:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            WHISPER_URL,
            headers={"Authorization": f"Bearer {OPENAI_API_KEY}"},
            files={"file": ("voice.oga", oga_bytes, "audio/ogg")},
            data={"model": "whisper-1"},
        )
        response.raise_for_status()
        return response.json()["text"]


async def synthesize_speech(text: str) -> bytes:
    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(
            TTS_URL,
            headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": "tts-1",
                "input": text,
                "voice": "nova",
                "response_format": "opus",
            },
        )
        response.raise_for_status()
        return response.content
