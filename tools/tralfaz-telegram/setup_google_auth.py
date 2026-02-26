#!/usr/bin/env python3
"""One-time OAuth2 setup for Google Calendar integration.

Run this interactively in a terminal — it opens a browser for consent
and saves the refresh token for the bot to use.
"""

from google_auth_oauthlib.flow import InstalledAppFlow

from config import GOOGLE_CLIENT_SECRET_PATH, GOOGLE_CREDENTIALS_PATH

SCOPES = ["https://www.googleapis.com/auth/calendar.events"]


def main():
    flow = InstalledAppFlow.from_client_secrets_file(GOOGLE_CLIENT_SECRET_PATH, SCOPES)
    creds = flow.run_local_server(port=0)

    with open(GOOGLE_CREDENTIALS_PATH, "w") as f:
        f.write(creds.to_json())

    print(f"Credentials saved to {GOOGLE_CREDENTIALS_PATH}")


if __name__ == "__main__":
    main()
