#!/usr/bin/env python3
"""
core.py — tool-agnostic Markdown writer for stopwatch
Called by adapters; does not read stdin or know about any specific AI tool.
"""
import os
import re
from datetime import datetime, timezone, timedelta

TIMELINE_DIR = os.environ.get(
    "STOPWATCH_DIR",
    os.path.expanduser("~/.stopwatch/timeline")
)
TIMELINE_TITLE = os.environ.get("STOPWATCH_TITLE", "stopwatch")

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


def week_info(now):
    iso_year, iso_week, _ = now.isocalendar()
    mon = now - timedelta(days=now.weekday())
    sun = mon + timedelta(days=6)
    label = f"{iso_year}-W{iso_week:02d}"
    span = f"{mon.strftime('%m-%d')} ~ {sun.strftime('%m-%d')}"
    return label, span


def day_header(date):
    return f"## {date.strftime('%m-%d')}（周{WEEKDAYS_ZH[date.weekday()]}）"


def round_to_hour(dt):
    rounded = dt.replace(minute=0, second=0, microsecond=0)
    if dt.minute >= 30:
        rounded += timedelta(hours=1)
    return rounded.strftime("%H:00")


def session_callout_header(hour_str, title, sid):
    return f"> [!quote] 💬 {hour_str} · {title} <!-- sid:{sid} -->"


def make_entry(time_str, user_text, ai_text, with_sep=False):
    sep = ">\n" if with_sep else ""
    return (
        f"{sep}> **{time_str}** 👤 {user_text}\n"
        f"> 🤖 {ai_text}\n"
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


def write_entry(session_id, project, user_text, ai_text, source="default"):
    sid = session_id[:8] if session_id else "unknown"
    now = datetime.now(CST)
    time_str = now.strftime("%H:%M")
    hour_str = round_to_hour(now)
    w_label, w_span = week_info(now)
    d_hdr = day_header(now)
    user_text = truncate(user_text)
    ai_text = last_paragraph(ai_text)
    session_title = truncate(user_text, limit=40)

    output_dir = os.path.join(TIMELINE_DIR, source)
    os.makedirs(output_dir, exist_ok=True)
    file_path = os.path.join(output_dir, f"{w_label}.md")

    if not os.path.isfile(file_path):
        hdr = session_callout_header(hour_str, session_title, sid)
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(f"# {TIMELINE_TITLE} {w_label}（{w_span}）\n\n")
            f.write(f"{d_hdr}\n\n")
            f.write(f"{hdr}\n")
            f.write(make_entry(time_str, user_text, ai_text))
        return

    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    flat = [l.rstrip("\n") for l in lines]
    day_start, day_end = find_section(flat, d_hdr)

    if day_start == -1:
        hdr = session_callout_header(hour_str, session_title, sid)
        block = f"\n{d_hdr}\n\n{hdr}\n{make_entry(time_str, user_text, ai_text)}"
        with open(file_path, "a", encoding="utf-8") as f:
            f.write(block)
        return

    c_start = find_session_callout(flat, day_start, day_end, sid)

    if c_start == -1:
        hdr = session_callout_header(hour_str, session_title, sid)
        new_block = f"\n{hdr}\n{make_entry(time_str, user_text, ai_text)}"
        lines.insert(day_end, new_block)
    else:
        # header is frozen after creation: title = first user message, time = creation hour
        c_end = callout_end(flat, c_start)
        lines.insert(c_end, make_entry(time_str, user_text, ai_text, with_sep=True))

    with open(file_path, "w", encoding="utf-8") as f:
        f.writelines(lines)
