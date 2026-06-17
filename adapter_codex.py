#!/usr/bin/env python3
"""
adapter_codex.py — OpenAI Codex CLI adapter
Codex does not have a built-in hook system. Use a shell wrapper instead:

  # ~/.zshrc or ~/.bashrc
  codex() {
    command codex "$@"
    python3 ~/.stopwatch/adapter_codex.py --cwd "$PWD"
  }

Codex stores sessions at: ~/.codex/sessions/<session_id>.json (verify on your machine)
This adapter reads the most recently modified session file.
"""
import sys
import os
import json
import glob
import argparse

sys.path.insert(0, os.path.dirname(__file__))
import core

CODEX_SESSIONS_DIR = os.path.expanduser("~/.codex/sessions")


def find_latest_session():
    pattern = os.path.join(CODEX_SESSIONS_DIR, "*.json")
    files = glob.glob(pattern)
    if not files:
        return None
    return max(files, key=os.path.getmtime)


def parse_session(session_path):
    with open(session_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    last_user, last_assistant = "", ""
    messages = data if isinstance(data, list) else data.get("messages", [])
    for msg in messages:
        role = msg.get("role", "")
        content = msg.get("content", "")
        if isinstance(content, list):
            content = "\n".join(p.get("text", "") for p in content if p.get("type") == "text")
        if role == "user":
            last_user = content
        elif role == "assistant":
            last_assistant = content

    session_id = data.get("id", os.path.basename(session_path)) if isinstance(data, dict) else os.path.basename(session_path)
    return session_id, last_user, last_assistant


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cwd", default=os.getcwd())
    args = parser.parse_args()

    session_path = find_latest_session()
    if not session_path:
        print(f"stopwatch/codex: no session found in {CODEX_SESSIONS_DIR}", file=sys.stderr)
        return

    try:
        session_id, last_user, last_assistant = parse_session(session_path)
    except Exception as e:
        print(f"stopwatch/codex: parse error: {e}", file=sys.stderr)
        return

    project = os.path.basename(args.cwd.rstrip("/")) if args.cwd else "unknown"

    try:
        core.write_entry(session_id, project, last_user, last_assistant)
    except Exception as e:
        print(f"stopwatch/codex: write error: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
