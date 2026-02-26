import os
import sys
from datetime import datetime

# --- Required environment variables (fail fast) ---

TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN")
ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")

_missing = []
if not TELEGRAM_BOT_TOKEN:
    _missing.append("TELEGRAM_BOT_TOKEN")
if not ANTHROPIC_API_KEY:
    _missing.append("ANTHROPIC_API_KEY")
if not OPENAI_API_KEY:
    _missing.append("OPENAI_API_KEY")

if _missing:
    print(f"ERROR: Missing required environment variables: {', '.join(_missing)}", file=sys.stderr)
    sys.exit(1)

# --- Constants ---

CLAUDE_MODEL = "claude-sonnet-4-20250514"
CLAUDE_MAX_TOKENS = 1024
MAX_HISTORY_MESSAGES = 40
DEFAULT_REMINDER_MINUTES = 30
REMINDER_CHECK_INTERVAL = 60

_BASE_PROMPT = (
    "You are Tralfaz, a snooty but deeply loyal British butler in the style of "
    "Tex Avery and classic Disney animation. You address your employer as 'Sir' "
    "and manage his schedule, reminders, and tasks with impeccable precision and "
    "dry wit. You are efficient, occasionally sardonic, but always devoted."
)


def get_system_prompt() -> str:
    now = datetime.now()
    return (
        f"{_BASE_PROMPT}\n\n"
        f"Current date and time: {now.strftime('%A, %B %d, %Y at %I:%M %p')}.\n\n"
        "You have access to appointment management tools. When Sir mentions an "
        "appointment, meeting, or scheduled event, use the save_appointment tool to "
        "record it. Use your knowledge of the current date/time to resolve relative "
        "dates like 'tomorrow', 'next Tuesday', etc. into ISO 8601 datetime strings. "
        "If no specific time is given, use a sensible default (noon for meals, "
        "9 AM for generic appointments). Always confirm what you saved."
    )

# Paths (same directory as this script)
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(_SCRIPT_DIR, "conversations.db")

# Google Calendar
GOOGLE_CLIENT_SECRET_PATH = os.path.join(_SCRIPT_DIR, "client_secret.json")
GOOGLE_CREDENTIALS_PATH = os.path.join(_SCRIPT_DIR, "google_credentials.json")
GOOGLE_CALENDAR_TIMEZONE = "America/New_York"
