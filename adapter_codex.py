#!/usr/bin/env python3
"""
adapter_codex.py — OpenAI Codex CLI adapter

Codex stores sessions at:
  ~/.codex/sessions/YYYY/MM/DD/rollout-<ts>-<session_id>.jsonl

Each line is a JSON event. Relevant types:
  { "type": "event_msg", "payload": { "type": "user_message",  "message": "..." } }
  { "type": "event_msg", "payload": { "type": "task_complete", "last_agent_message": "..." } }
  { "type": "session_meta", "payload": { "id": "<session_id>", "cwd": "..." } }

Codex supports a native Stop hook via ~/.codex/hooks.json (same schema as Claude).
The install script writes to that file — no shell wrapper needed.
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
    pattern = os.path.join(CODEX_SESSIONS_DIR, "**", "*.jsonl")
    files = glob.glob(pattern, recursive=True)
    if not files:
        return None
    return max(files, key=os.path.getmtime)


def parse_session(session_path):
    session_id = os.path.basename(session_path).replace(".jsonl", "")
    cwd = None
    last_user = ""
    last_assistant = ""

    with open(session_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            t = obj.get("type")
            payload = obj.get("payload", {})

            if t == "session_meta":
                session_id = payload.get("id", session_id)
                cwd = payload.get("cwd")
            elif t == "event_msg":
                pt = payload.get("type", "")
                if pt == "user_message":
                    last_user = payload.get("message", "")
                elif pt == "task_complete":
                    last_assistant = payload.get("last_agent_message", "")

    return session_id, cwd, last_user, last_assistant


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cwd", default=None)
    args = parser.parse_args()

    session_path = find_latest_session()
    if not session_path:
        print(f"stopwatch/codex: no session found in {CODEX_SESSIONS_DIR}", file=sys.stderr)
        return

    try:
        session_id, file_cwd, last_user, last_assistant = parse_session(session_path)
    except Exception as e:
        print(f"stopwatch/codex: parse error: {e}", file=sys.stderr)
        return

    cwd = args.cwd or file_cwd or os.getcwd()
    project = os.path.basename(cwd.rstrip("/")) if cwd else "unknown"

    try:
        core.write_entry(session_id, project, last_user, last_assistant, source="codex")
    except Exception as e:
        print(f"stopwatch/codex: write error: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
