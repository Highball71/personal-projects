import asyncio
import logging
from datetime import datetime

from telegram import Update
from telegram.constants import ChatAction
from telegram.ext import ContextTypes

import claude_client
import database
from voice import transcribe_voice, synthesize_speech

logger = logging.getLogger(__name__)


async def _send_reply(message, text: str):
    await message.reply_text(text)
    try:
        audio_bytes = await synthesize_speech(text)
        await message.reply_voice(audio_bytes)
    except Exception:
        logger.exception("TTS failed")


async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "Good day, Sir. Tralfaz at your service. How may I be of assistance?"
    )


async def clear_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    database.clear_history(update.effective_chat.id)
    await update.message.reply_text(
        "Very good, Sir. The slate has been wiped clean. A fresh start, as it were."
    )


async def handle_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    user_text = update.message.text

    database.store_message(chat_id, "user", user_text)
    history = database.get_history(chat_id)

    reply = await asyncio.to_thread(claude_client.get_response, history, chat_id)

    database.store_message(chat_id, "assistant", reply)
    await _send_reply(update.message, reply)


async def handle_voice(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id

    await update.message.chat.send_action(ChatAction.TYPING)

    voice_file = await update.message.voice.get_file()
    oga_bytes = await voice_file.download_as_bytearray()

    try:
        transcription = await transcribe_voice(bytes(oga_bytes))
    except Exception:
        logger.exception("Voice transcription failed")
        await update.message.reply_text(
            "I'm terribly sorry, Sir. I couldn't quite make that out. "
            "Perhaps you might try again?"
        )
        return

    await update.message.reply_text(f'[I heard: "{transcription}"]')

    database.store_message(chat_id, "user", transcription)
    history = database.get_history(chat_id)

    reply = await asyncio.to_thread(claude_client.get_response, history, chat_id)

    database.store_message(chat_id, "assistant", reply)
    await _send_reply(update.message, reply)


async def schedule_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    appointments = database.list_appointments(chat_id)

    if not appointments:
        await update.message.reply_text(
            "Your calendar is blissfully empty, Sir. A rare luxury."
        )
        return

    lines = ["Your upcoming engagements, Sir:\n"]
    for appt in appointments:
        dt = datetime.fromisoformat(appt["datetime"])
        lines.append(
            f"  #{appt['id']} — {appt['title']}\n"
            f"       {dt.strftime('%A, %B %d at %I:%M %p')}"
        )
    await update.message.reply_text("\n".join(lines))
