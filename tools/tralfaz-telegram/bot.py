import logging

from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, filters

import database
from config import TELEGRAM_BOT_TOKEN
from handlers import start_command, clear_command, schedule_command, handle_text, handle_voice
from briefings import start_briefings
from reminders import start_reminders

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger(__name__)


async def _post_init(app):
    await start_reminders(app)
    await start_briefings(app)


def main():
    database.init_db()

    app = ApplicationBuilder().token(TELEGRAM_BOT_TOKEN).post_init(_post_init).build()

    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("clear", clear_command))
    app.add_handler(CommandHandler("schedule", schedule_command))
    app.add_handler(MessageHandler(filters.VOICE, handle_voice))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))

    logger.info("Tralfaz is ready for duty, Sir.")
    app.run_polling()


if __name__ == "__main__":
    main()
