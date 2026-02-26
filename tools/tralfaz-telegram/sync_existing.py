#!/usr/bin/env python3
"""One-time script to sync existing future appointments to Google Calendar.

Finds all future appointments with no google_event_id and creates
Google Calendar events for them.
"""

import sqlite3

import database
import google_calendar
from config import DB_PATH


def main():
    database.init_db()

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        """
        SELECT id, title, datetime, reminder_minutes_before
        FROM appointments
        WHERE google_event_id IS NULL
          AND datetime >= datetime('now', 'localtime')
        ORDER BY datetime ASC
        """
    ).fetchall()
    conn.close()

    if not rows:
        print("No appointments to sync.")
        return

    print(f"Found {len(rows)} appointment(s) to sync:\n")
    for row in rows:
        row = dict(row)
        print(f"  [{row['id']}] {row['title']} — {row['datetime']}")
        event_id = google_calendar.create_event(
            row["title"], row["datetime"], row["reminder_minutes_before"]
        )
        if event_id:
            database.set_google_event_id(row["id"], event_id)
            print(f"       -> synced (event {event_id})")
        else:
            print("       -> FAILED to sync")

    print("\nDone.")


if __name__ == "__main__":
    main()
