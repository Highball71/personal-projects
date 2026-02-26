import asyncio
import logging
from datetime import datetime

import claude_client
import database
from config import (
    OWNER_CHAT_ID,
    MORNING_BRIEFING_HOUR,
    EVENING_BRIEFING_HOUR,
    REMINDER_CHECK_INTERVAL,
    get_briefing_prompt,
)
from voice import synthesize_speech

logger = logging.getLogger(__name__)

_last_sent = {"morning": None, "evening": None}


def _format_appointments(appointments: list[dict]) -> str:
    if not appointments:
        return "None scheduled."
    lines = []
    for appt in appointments:
        dt = datetime.fromisoformat(appt["datetime"])
        lines.append(f"- {appt['title']} at {dt.strftime('%I:%M %p')}")
    return "\n".join(lines)


def _generate_briefing(briefing_type: str, chat_id: int) -> str:
    if briefing_type == "morning":
        appointments = database.get_todays_appointments(chat_id)
    else:
        appointments = database.get_tomorrows_appointments(chat_id)

    appointments_text = _format_appointments(appointments)
    system = get_briefing_prompt(briefing_type, appointments_text)
    messages = [{"role": "user", "content": "Please give me my briefing."}]
    return claude_client.get_response_with_system(system, messages)


async def send_briefing(app, briefing_type: str, chat_id: int):
    try:
        text = await asyncio.to_thread(_generate_briefing, briefing_type, chat_id)
    except Exception:
        logger.exception("Failed to generate %s briefing", briefing_type)
        return

    try:
        await app.bot.send_message(chat_id=chat_id, text=text)
    except Exception:
        logger.exception("Failed to send %s briefing message", briefing_type)
        return

    try:
        audio_bytes = await synthesize_speech(text)
        await app.bot.send_voice(chat_id=chat_id, voice=audio_bytes)
    except Exception:
        logger.exception("TTS failed for %s briefing", briefing_type)


async def briefing_loop(app):
    logger.info("Briefing background task started")
    while True:
        await asyncio.sleep(REMINDER_CHECK_INTERVAL)
        try:
            now = datetime.now()
            today = now.strftime("%Y-%m-%d")

            if now.hour == MORNING_BRIEFING_HOUR and _last_sent["morning"] != today:
                _last_sent["morning"] = today
                await send_briefing(app, "morning", OWNER_CHAT_ID)

            if now.hour == EVENING_BRIEFING_HOUR and _last_sent["evening"] != today:
                _last_sent["evening"] = today
                await send_briefing(app, "evening", OWNER_CHAT_ID)
        except Exception:
            logger.exception("Error in briefing loop")


async def start_briefings(app):
    asyncio.create_task(briefing_loop(app))
