#!/usr/bin/env python3
import json
import sys
import os
from datetime import datetime, timezone, timedelta

TIMELINE_DIR = os.environ.get(
    "CLAUDE_TIMELINE_DIR",
    os.path.expanduser("~/Documents/stopwatch")
)
CST = timezone(timedelta(hours=8))
WEEKDAYS_ZH = ["一", "二", "三", "四", "五", "六", "日"]


def truncate(text, limit=60):
    text = " ".join(text.split())
    return text[:limit] + "..." if len(text) > limit else text


def last_paragraph(text, limit=100):
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    if not paragraphs:
        return ""
    last = " ".join(paragraphs[-1].split())
    return last[:limit] + "..." if len(last) > limit else last


def extract_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
        return "\n".join(parts)
    return ""


def find_last_messages(transcript_path):
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


def week_info(now):
    iso_year, iso_week, _ = now.isocalendar()
    mon = now - timedelta(days=now.weekday())
    sun = mon + timedelta(days=6)
    label = f"{iso_year}-W{iso_week:02d}"
    span = f"{mon.strftime('%m-%d')} ~ {sun.strftime('%m-%d')}"
    return label, span


def day_header(date):
    return f"## {date.strftime('%m-%d')}（周{WEEKDAYS_ZH[date.weekday()]}）"


def session_callout_header(start_time, end_time, project, sid):
    return f"> [!quote] 💬 {start_time}–{end_time} · {project} <!-- sid:{sid} -->"


def make_entry(time_str, user_text, claude_text, with_sep=False):
    sep = ">\n" if with_sep else ""
    return (
        f"{sep}> **{time_str}** 👤 {user_text}\n"
        f"> 🤖 {claude_text}\n"
    )


def find_section(lines, header):
    start = next((i for i, l in enumerate(lines) if l.rstrip() == header), -1)
    if start == -1:
        return -1, -1
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    return start, end


def callout_end(lines, start):
    for i in range(start + 1, len(lines)):
        if not lines[i].startswith(">"):
            return i
    return len(lines)


def find_session_callout(flat, day_start, day_end, sid):
    marker = f"<!-- sid:{sid} -->"
    for i in range(day_start, day_end):
        if flat[i].startswith("> [!quote]") and marker in flat[i]:
            return i
    return -1


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception as e:
        print(f"timeline_logger: {e}", file=sys.stderr)
        return

    transcript_path = payload.get("transcript_path")
    cwd = payload.get("cwd", "")
    session_id = payload.get("session_id", "")
    sid = session_id[:8] if session_id else "unknown"

    if not transcript_path or not os.path.isfile(transcript_path):
        print(f"timeline_logger: transcript not found: {transcript_path}", file=sys.stderr)
        return

    try:
        last_user, last_assistant = find_last_messages(transcript_path)
    except Exception as e:
        print(f"timeline_logger: parse error: {e}", file=sys.stderr)
        return

    project = os.path.basename(cwd.rstrip("/")) if cwd else "unknown"
    now = datetime.now(CST)
    time_str = now.strftime("%H:%M")
    w_label, w_span = week_info(now)
    d_hdr = day_header(now)
    user_text = truncate(last_user)
    claude_text = last_paragraph(last_assistant)

    try:
        os.makedirs(TIMELINE_DIR, exist_ok=True)
        file_path = os.path.join(TIMELINE_DIR, f"{w_label}.md")

        if not os.path.isfile(file_path):
            hdr = session_callout_header(time_str, time_str, project, sid)
            with open(file_path, "w", encoding="utf-8") as f:
                f.write(f"# AI对话录 {w_label}（{w_span}）\n\n")
                f.write(f"{d_hdr}\n\n")
                f.write(f"{hdr}\n")
                f.write(make_entry(time_str, user_text, claude_text))
            return

        with open(file_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        flat = [l.rstrip("\n") for l in lines]
        day_start, day_end = find_section(flat, d_hdr)

        if day_start == -1:
            hdr = session_callout_header(time_str, time_str, project, sid)
            block = f"\n{d_hdr}\n\n{hdr}\n{make_entry(time_str, user_text, claude_text)}"
            with open(file_path, "a", encoding="utf-8") as f:
                f.write(block)
            return

        c_start = find_session_callout(flat, day_start, day_end, sid)

        if c_start == -1:
            # new session callout
            hdr = session_callout_header(time_str, time_str, project, sid)
            new_block = f"\n{hdr}\n{make_entry(time_str, user_text, claude_text)}"
            lines.insert(day_end, new_block)
        else:
            # update end time in header, append entry
            old_hdr = flat[c_start]
            # extract start time from existing header: "💬 HH:MM–..."
            import re
            m = re.search(r'💬 (\d{2}:\d{2})–\d{2}:\d{2}', old_hdr)
            start_time = m.group(1) if m else time_str
            new_hdr = session_callout_header(start_time, time_str, project, sid)
            lines[c_start] = new_hdr + "\n"
            c_end = callout_end(flat, c_start)
            lines.insert(c_end, make_entry(time_str, user_text, claude_text, with_sep=True))

        with open(file_path, "w", encoding="utf-8") as f:
            f.writelines(lines)

    except Exception as e:
        print(f"timeline_logger: write error: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
