import asyncio
import logging
from datetime import datetime

import database
from config import REMINDER_CHECK_INTERVAL
from voice import synthesize_speech

logger = logging.getLogger(__name__)


async def reminder_loop(app):
    logger.info("Reminder background task started")
    while True:
        await asyncio.sleep(REMINDER_CHECK_INTERVAL)
        try:
            due = database.get_due_reminders()
            for appt in due:
                dt = datetime.fromisoformat(appt["datetime"])
                text = (
                    f"Pardon the interruption, Sir. A gentle reminder: "
                    f'"{appt["title"]}" is coming up at {dt.strftime("%I:%M %p")}.'
                )
                try:
                    await app.bot.send_message(chat_id=appt["chat_id"], text=text)
                except Exception:
                    logger.exception("Failed to send reminder for appointment %s", appt["id"])
                    continue

                try:
                    audio_bytes = await synthesize_speech(text)
                    await app.bot.send_voice(chat_id=appt["chat_id"], voice=audio_bytes)
                except Exception:
                    logger.exception("TTS failed for reminder %s", appt["id"])

                database.mark_reminded(appt["id"])
        except Exception:
            logger.exception("Error in reminder loop")


async def start_reminders(app):
    asyncio.create_task(reminder_loop(app))
