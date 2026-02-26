#!/usr/bin/env python3
"""One-time OAuth2 setup for Google Calendar integration.

Run this interactively in a terminal — it opens a browser for consent
and saves the refresh token for the bot to use.
"""

import os

from google_auth_oauthlib.flow import InstalledAppFlow

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GOOGLE_CLIENT_SECRET_PATH = os.path.join(_SCRIPT_DIR, "client_secret.json")
GOOGLE_CREDENTIALS_PATH = os.path.join(_SCRIPT_DIR, "google_credentials.json")

SCOPES = ["https://www.googleapis.com/auth/calendar.events"]


def main():
    flow = InstalledAppFlow.from_client_secrets_file(GOOGLE_CLIENT_SECRET_PATH, SCOPES)
    creds = flow.run_local_server(port=0)

    with open(GOOGLE_CREDENTIALS_PATH, "w") as f:
        f.write(creds.to_json())

    print(f"Credentials saved to {GOOGLE_CREDENTIALS_PATH}")


if __name__ == "__main__":
    main()
