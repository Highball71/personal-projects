import logging
from datetime import datetime, timedelta

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

from config import GOOGLE_CREDENTIALS_PATH, GOOGLE_CALENDAR_TIMEZONE

logger = logging.getLogger(__name__)

SCOPES = ["https://www.googleapis.com/auth/calendar.events"]


def _get_credentials():
    """Load and refresh OAuth2 credentials. Returns None if unavailable."""
    try:
        creds = Credentials.from_authorized_user_file(GOOGLE_CREDENTIALS_PATH, SCOPES)
    except Exception:
        logger.warning("Google credentials file not found or invalid — calendar sync disabled")
        return None

    if creds.expired and creds.refresh_token:
        try:
            creds.refresh(Request())
            with open(GOOGLE_CREDENTIALS_PATH, "w") as f:
                f.write(creds.to_json())
        except Exception:
            logger.warning("Failed to refresh Google credentials — calendar sync disabled")
            return None

    return creds


def _get_service():
    """Build Calendar API service. Returns None if credentials unavailable."""
    creds = _get_credentials()
    if creds is None:
        return None
    try:
        return build("calendar", "v3", credentials=creds)
    except Exception:
        logger.exception("Failed to build Google Calendar service")
        return None


def create_event(title: str, dt_iso: str, reminder_minutes: int = 30) -> str | None:
    """Create a 1-hour calendar event. Returns event ID or None on failure."""
    service = _get_service()
    if service is None:
        return None

    try:
        start = datetime.fromisoformat(dt_iso)
        end = start + timedelta(hours=1)

        event = {
            "summary": title,
            "start": {
                "dateTime": start.isoformat(),
                "timeZone": GOOGLE_CALENDAR_TIMEZONE,
            },
            "end": {
                "dateTime": end.isoformat(),
                "timeZone": GOOGLE_CALENDAR_TIMEZONE,
            },
            "reminders": {
                "useDefault": False,
                "overrides": [
                    {"method": "popup", "minutes": reminder_minutes},
                ],
            },
        }

        result = service.events().insert(calendarId="primary", body=event).execute()
        event_id = result["id"]
        logger.info("Created Google Calendar event %s for '%s'", event_id, title)
        return event_id
    except Exception:
        logger.exception("Failed to create Google Calendar event for '%s'", title)
        return None


def delete_event(event_id: str) -> bool:
    """Delete a calendar event. Returns True on success, False on failure."""
    service = _get_service()
    if service is None:
        return False

    try:
        service.events().delete(calendarId="primary", eventId=event_id).execute()
        logger.info("Deleted Google Calendar event %s", event_id)
        return True
    except Exception:
        logger.exception("Failed to delete Google Calendar event %s", event_id)
        return False
