import json
import logging

import anthropic

import database
import google_calendar
from config import ANTHROPIC_API_KEY, CLAUDE_MODEL, CLAUDE_MAX_TOKENS, get_system_prompt

logger = logging.getLogger(__name__)

_client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

TOOLS = [
    {
        "name": "save_appointment",
        "description": (
            "Save an appointment or scheduled event. Use this whenever Sir mentions "
            "an upcoming appointment, meeting, event, or anything with a date/time."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "title": {
                    "type": "string",
                    "description": "Short description of the appointment",
                },
                "datetime": {
                    "type": "string",
                    "description": "ISO 8601 datetime string, e.g. 2026-03-01T14:00:00",
                },
                "reminder_minutes": {
                    "type": "integer",
                    "description": "Minutes before the appointment to send a reminder (default 30)",
                },
            },
            "required": ["title", "datetime"],
        },
    },
    {
        "name": "list_appointments",
        "description": "List all upcoming appointments for the current chat.",
        "input_schema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "cancel_appointment",
        "description": "Cancel an appointment by its ID.",
        "input_schema": {
            "type": "object",
            "properties": {
                "appointment_id": {
                    "type": "integer",
                    "description": "The ID of the appointment to cancel",
                },
            },
            "required": ["appointment_id"],
        },
    },
]


def _execute_tool(name: str, tool_input: dict, chat_id: int) -> str:
    if name == "save_appointment":
        reminder_minutes = tool_input.get("reminder_minutes", 30)
        appt_id = database.save_appointment(
            chat_id=chat_id,
            title=tool_input["title"],
            dt=tool_input["datetime"],
            reminder_minutes=reminder_minutes,
        )
        event_id = google_calendar.create_event(
            tool_input["title"], tool_input["datetime"], reminder_minutes
        )
        if event_id:
            database.set_google_event_id(appt_id, event_id)
        return json.dumps({"success": True, "appointment_id": appt_id})

    elif name == "list_appointments":
        appointments = database.list_appointments(chat_id)
        return json.dumps({"appointments": appointments})

    elif name == "cancel_appointment":
        appt = database.get_appointment(tool_input["appointment_id"], chat_id)
        if appt and appt.get("google_event_id"):
            google_calendar.delete_event(appt["google_event_id"])
        deleted = database.cancel_appointment(chat_id, tool_input["appointment_id"])
        return json.dumps({"success": deleted})

    return json.dumps({"error": f"Unknown tool: {name}"})


def get_response(history: list[dict], chat_id: int = None) -> str:
    system = get_system_prompt()
    kwargs = dict(
        model=CLAUDE_MODEL,
        max_tokens=CLAUDE_MAX_TOKENS,
        system=system,
        messages=history,
    )
    if chat_id is not None:
        kwargs["tools"] = TOOLS

    # Local copy of messages for the tool use loop — intermediate tool
    # messages are NOT added to the caller's history list.
    messages = list(history)

    while True:
        kwargs["messages"] = messages
        response = _client.messages.create(**kwargs)

        if response.stop_reason != "tool_use":
            # Extract final text
            for block in response.content:
                if hasattr(block, "text"):
                    return block.text
            return ""

        # Process tool calls
        tool_results = []
        for block in response.content:
            if block.type == "tool_use":
                logger.info("Tool call: %s(%s)", block.name, block.input)
                result = _execute_tool(block.name, block.input, chat_id)
                logger.info("Tool result: %s", result)
                tool_results.append(
                    {"type": "tool_result", "tool_use_id": block.id, "content": result}
                )

        # Append assistant response + tool results for the next loop iteration
        messages.append({"role": "assistant", "content": response.content})
        messages.append({"role": "user", "content": tool_results})
