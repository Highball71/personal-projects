import sqlite3
from config import DB_PATH, MAX_HISTORY_MESSAGES, DEFAULT_REMINDER_MINUTES


def init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chat_id INTEGER NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_chat_id ON messages (chat_id)"
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS appointments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chat_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            datetime TEXT NOT NULL,
            reminder_minutes_before INTEGER DEFAULT 30,
            reminded INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_appt_chat_id ON appointments (chat_id)"
    )
    conn.commit()
    conn.close()
    _migrate_appointments()
    _seed_appointments()


def store_message(chat_id: int, role: str, content: str):
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        "INSERT INTO messages (chat_id, role, content) VALUES (?, ?, ?)",
        (chat_id, role, content),
    )
    conn.commit()
    conn.close()


def get_history(chat_id: int) -> list[dict]:
    conn = sqlite3.connect(DB_PATH)
    rows = conn.execute(
        """
        SELECT role, content FROM (
            SELECT role, content, id
            FROM messages
            WHERE chat_id = ?
            ORDER BY id DESC
            LIMIT ?
        ) sub ORDER BY id ASC
        """,
        (chat_id, MAX_HISTORY_MESSAGES),
    ).fetchall()
    conn.close()
    return [{"role": role, "content": content} for role, content in rows]


def clear_history(chat_id: int):
    conn = sqlite3.connect(DB_PATH)
    conn.execute("DELETE FROM messages WHERE chat_id = ?", (chat_id,))
    conn.commit()
    conn.close()


# --- Appointments ---


def save_appointment(chat_id: int, title: str, dt: str, reminder_minutes: int = DEFAULT_REMINDER_MINUTES) -> int:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.execute(
        "INSERT INTO appointments (chat_id, title, datetime, reminder_minutes_before) VALUES (?, ?, ?, ?)",
        (chat_id, title, dt, reminder_minutes),
    )
    conn.commit()
    appt_id = cur.lastrowid
    conn.close()
    return appt_id


def list_appointments(chat_id: int) -> list[dict]:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        """
        SELECT id, title, datetime, reminder_minutes_before, google_event_id
        FROM appointments
        WHERE chat_id = ? AND datetime >= datetime('now', 'localtime')
        ORDER BY datetime ASC
        """,
        (chat_id,),
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def cancel_appointment(chat_id: int, appointment_id: int) -> bool:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.execute(
        "DELETE FROM appointments WHERE id = ? AND chat_id = ?",
        (appointment_id, chat_id),
    )
    conn.commit()
    deleted = cur.rowcount > 0
    conn.close()
    return deleted


def get_appointment(appointment_id: int, chat_id: int) -> dict | None:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    row = conn.execute(
        "SELECT id, title, datetime, reminder_minutes_before, google_event_id FROM appointments WHERE id = ? AND chat_id = ?",
        (appointment_id, chat_id),
    ).fetchone()
    conn.close()
    return dict(row) if row else None


def set_google_event_id(appointment_id: int, event_id: str):
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        "UPDATE appointments SET google_event_id = ? WHERE id = ?",
        (event_id, appointment_id),
    )
    conn.commit()
    conn.close()


def get_due_reminders() -> list[dict]:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        """
        SELECT id, chat_id, title, datetime, reminder_minutes_before
        FROM appointments
        WHERE reminded = 0
          AND datetime >= datetime('now', 'localtime')
          AND datetime <= datetime('now', 'localtime', '+' || reminder_minutes_before || ' minutes')
        """
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def mark_reminded(appointment_id: int):
    conn = sqlite3.connect(DB_PATH)
    conn.execute("UPDATE appointments SET reminded = 1 WHERE id = ?", (appointment_id,))
    conn.commit()
    conn.close()


def _migrate_appointments():
    conn = sqlite3.connect(DB_PATH)
    columns = [row[1] for row in conn.execute("PRAGMA table_info(appointments)").fetchall()]
    if "google_event_id" not in columns:
        conn.execute("ALTER TABLE appointments ADD COLUMN google_event_id TEXT")
        conn.commit()
    conn.close()


def _seed_appointments():
    conn = sqlite3.connect(DB_PATH)
    count = conn.execute("SELECT COUNT(*) FROM appointments").fetchone()[0]
    if count == 0:
        seeds = [
            (7122294517, "Joey's appointment at Presby", "2026-02-27T10:30:00", 30),
            (7122294517, "Safelite Auto Glass in Butler", "2026-03-03T08:00:00", 30),
            (7122294517, "Dishwasher and microwave installation", "2026-03-03T13:00:00", 30),
            (7122294517, "Lunch with Liz", "2026-03-05T12:00:00", 30),
        ]
        conn.executemany(
            "INSERT INTO appointments (chat_id, title, datetime, reminder_minutes_before) VALUES (?, ?, ?, ?)",
            seeds,
        )
        conn.commit()
    conn.close()
