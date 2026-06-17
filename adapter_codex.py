#!/usr/bin/env python3
"""
adapter_codex.py - OpenAI Codex CLI adapter

Codex stores sessions at:
  $CODEX_HOME/sessions/YYYY/MM/DD/rollout-<ts>-<session_id>.jsonl

Each line is a JSON event. Relevant types:
  { "type": "event_msg", "payload": { "type": "user_message",  "message": "..." } }
  { "type": "event_msg", "payload": { "type": "agent_message", "phase": "final_answer", "message": "..." } }
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
import time
import select
import hashlib

sys.path.insert(0, os.path.dirname(__file__))
import core

CODEX_HOME = os.path.expanduser(os.environ.get("CODEX_HOME", "~/.codex"))
CODEX_SESSIONS_DIR = os.path.join(CODEX_HOME, "sessions")
POLL_SECONDS = float(os.environ.get("STOPWATCH_CODEX_POLL_SECONDS", "2.5"))
POLL_INTERVAL = 0.25


def _norm_path(path):
    return os.path.realpath(os.path.expanduser(path)) if path else None


def _read_hook_payload():
    if sys.stdin.isatty():
        return {}
    try:
        ready, _, _ = select.select([sys.stdin], [], [], 0)
    except Exception:
        ready = [sys.stdin]
    if not ready:
        return {}
    raw = sys.stdin.read().strip()
    if not raw:
        return {}
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return payload if isinstance(payload, dict) else {}


def _payload_session_path(payload):
    for key in ("session_path", "session_file", "transcript_path", "transcript"):
        value = payload.get(key)
        if isinstance(value, str) and value.endswith(".jsonl") and os.path.isfile(value):
            return value
    return None


def _payload_session_id(payload):
    for key in ("session_id", "sessionId", "id"):
        value = payload.get(key)
        if isinstance(value, str) and value:
            return value
    return None


def _payload_cwd(payload):
    value = payload.get("cwd")
    return value if isinstance(value, str) and value else None


def _iter_session_files():
    pattern = os.path.join(CODEX_SESSIONS_DIR, "**", "*.jsonl")
    files = glob.glob(pattern, recursive=True)
    return sorted(files, key=os.path.getmtime, reverse=True)


def _session_matches(session_path, session_id=None, cwd=None):
    if session_id and session_id in os.path.basename(session_path):
        return True
    try:
        parsed_id, parsed_cwd, _, _, _ = parse_session(session_path)
    except Exception:
        return False
    if session_id and parsed_id == session_id:
        return True
    if cwd and _norm_path(parsed_cwd) == _norm_path(cwd):
        return True
    return not session_id and not cwd


def find_latest_session(session_id=None, cwd=None):
    for path in _iter_session_files():
        if _session_matches(path, session_id=session_id, cwd=cwd):
            return path
    return None


def _extract_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        parts = []
        for item in value:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict):
                text = item.get("text") or item.get("message")
                if isinstance(text, str):
                    parts.append(text)
        return "\n".join(p for p in parts if p)
    return ""


def _user_text(payload):
    text = _extract_text(payload.get("message"))
    if text:
        return text
    return _extract_text(payload.get("text_elements"))


def _fallback_entry_id(session_id, user_text, assistant_text):
    digest = hashlib.sha1(f"{session_id}\0{user_text}\0{assistant_text}".encode("utf-8")).hexdigest()
    return digest[:16]


def parse_session(session_path):
    session_id = os.path.basename(session_path).replace(".jsonl", "")
    cwd = None
    last_user = ""
    last_assistant = ""
    entry_id = None

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
                    last_user = _user_text(payload)
                    last_assistant = ""
                    entry_id = None
                elif pt == "agent_message":
                    msg = payload.get("message", "")
                    phase = payload.get("phase")
                    if last_user and msg and phase == "final_answer":
                        last_assistant = msg
                elif pt == "task_complete":
                    msg = payload.get("last_agent_message", "")
                    if msg:
                        last_assistant = msg
                    entry_id = payload.get("turn_id") or entry_id

    if last_user and last_assistant and not entry_id:
        entry_id = _fallback_entry_id(session_id, last_user, last_assistant)

    return session_id, cwd, last_user, last_assistant, entry_id


def parse_when_ready(session_path):
    deadline = time.time() + POLL_SECONDS
    last_result = None
    while True:
        last_result = parse_session(session_path)
        _, _, last_user, last_assistant, _ = last_result
        if last_user and last_assistant:
            return last_result
        if time.time() >= deadline:
            return last_result
        time.sleep(POLL_INTERVAL)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cwd", default=None)
    parser.add_argument("--session-file", default=None)
    parser.add_argument("--session-id", default=None)
    args = parser.parse_args()

    payload = _read_hook_payload()
    cwd_hint = args.cwd or _payload_cwd(payload) or os.getcwd()
    session_id_hint = args.session_id or _payload_session_id(payload)
    session_path = args.session_file or _payload_session_path(payload)
    if session_path and not os.path.isfile(session_path):
        print(f"stopwatch/codex: session not found: {session_path}", file=sys.stderr)
        return
    if not session_path:
        session_path = find_latest_session(session_id=session_id_hint, cwd=cwd_hint)
    if not session_path:
        print(f"stopwatch/codex: no matching session found in {CODEX_SESSIONS_DIR}", file=sys.stderr)
        return

    try:
        session_id, file_cwd, last_user, last_assistant, entry_id = parse_when_ready(session_path)
    except Exception as e:
        print(f"stopwatch/codex: parse error: {e}", file=sys.stderr)
        return

    if not last_user or not last_assistant:
        print(f"stopwatch/codex: incomplete turn in {session_path}", file=sys.stderr)
        return

    cwd = cwd_hint or file_cwd or os.getcwd()
    project = os.path.basename(cwd.rstrip("/")) if cwd else "unknown"

    try:
        core.write_entry(session_id, project, last_user, last_assistant, source="codex", entry_id=entry_id)
    except Exception as e:
        print(f"stopwatch/codex: write error: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
