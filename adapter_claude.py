#!/usr/bin/env python3
"""
adapter_claude.py — Claude Code Stop hook adapter
Reads JSON payload from stdin, parses JSONL transcript, calls core.write_entry.

Hook config in ~/.claude/settings.json:
  "Stop": [{ "hooks": [{ "type": "command",
    "command": "python3 ~/.stopwatch/adapter_claude.py 2>/dev/null || true" }] }]
"""
import json
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
import core


def extract_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
        return "\n".join(parts)
    return ""


_INJECTED_PREFIXES = (
    "<task-notification>",
    "<system-reminder>",
    "<local-command-caveat>",
    "<command-name>",
    "<command-message>",
)


def _is_injected(text):
    t = text.strip()
    return any(t.startswith(p) for p in _INJECTED_PREFIXES)


def parse_transcript(transcript_path):
    last_user, last_assistant = "", ""
    with open(transcript_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            msg = entry.get("message")
            if not isinstance(msg, dict):
                continue
            role = msg.get("role")
            text = extract_text(msg.get("content"))
            if not text:
                continue
            if role == "user":
                last_user = text
            elif role == "assistant":
                last_assistant = text
    return last_user, last_assistant


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception as e:
        print(f"stopwatch/claude: {e}", file=sys.stderr)
        return

    transcript_path = payload.get("transcript_path")
    cwd = payload.get("cwd", "")
    session_id = payload.get("session_id", "")

    if not transcript_path or not os.path.isfile(transcript_path):
        print(f"stopwatch/claude: transcript not found: {transcript_path}", file=sys.stderr)
        return

    try:
        last_user, last_assistant = parse_transcript(transcript_path)
    except Exception as e:
        print(f"stopwatch/claude: parse error: {e}", file=sys.stderr)
        return

    if not last_user or _is_injected(last_user):
        return

    project = os.path.basename(cwd.rstrip("/")) if cwd else "unknown"

    try:
        core.write_entry(session_id, project, last_user, last_assistant, source="claude")
    except Exception as e:
        print(f"stopwatch/claude: write error: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
