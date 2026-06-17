English | [中文](README.zh-CN.md)

# stopwatch

Automatically records every AI coding agent conversation into weekly Markdown files, grouped by session. Optimized for Obsidian reading mode.

Supports **Claude Code** and **Codex CLI**.

## How it works

Each tool's Stop hook fires after a response. The adapter parses that tool's transcript format and passes the last turn to the shared core writer.

```
Tool Stop hook fires
  → adapter_claude.py  (reads ~/.claude/projects/…/*.jsonl)
  → adapter_codex.py   (reads ~/.codex/sessions/YYYY/MM/DD/*.jsonl)
    → core.py          (writes Markdown)
```

Both tools use native Stop hook configuration — Claude via `~/.claude/settings.json`, Codex via `~/.codex/hooks.json`.

Each session becomes a callout card. Starting a new session (`/clear`) creates a new card.

```
~/.stopwatch/timeline/
├── claude/
│   └── 2026-W25.md
│       ├── ## 06-16
│       │   ├── 💬 11:19–11:40 · project-a  ← session 1
│       │   └── 💬 14:02–14:35 · project-b  ← session 2 (after /clear)
│       └── ## 06-17
│           └── 💬 09:11–09:58 · project-a
└── codex/
    └── 2026-W25.md
```

## Install

```bash
sh <(curl -fsSL https://raw.githubusercontent.com/eyu1988/stopwatch/main/install.sh)
```

The installer will ask:
1. Where to save timeline files (default: `~/.stopwatch/timeline`)
2. Weekly file title (default: `stopwatch`)
3. Which tools to enable — Claude Code and/or Codex CLI (checkbox, multi-select)

## Requirements

- Python 3
- [Claude Code](https://claude.ai/code) and/or [Codex CLI](https://github.com/openai/codex)

## Configuration

Two environment variables control behavior:

| Variable | Default | Description |
|----------|---------|-------------|
| `STOPWATCH_DIR` | `~/.stopwatch/timeline` | Where `.md` files are saved |
| `STOPWATCH_TITLE` | `stopwatch` | Title shown at the top of each weekly file |

For Claude, these are set in `~/.claude/settings.json`:

```json
{
  "env": {
    "STOPWATCH_DIR": "/your/path",
    "STOPWATCH_TITLE": "your title"
  }
}
```

For Codex, they are set inline in the Stop hook command written to `~/.codex/hooks.json`.

## Architecture

```
~/.stopwatch/
├── core.py             — tool-agnostic Markdown writer
├── adapter_claude.py   — Claude Code Stop hook entry point
├── adapter_codex.py    — Codex CLI Stop hook entry point
└── install.sh
```

Adding support for a new tool only requires a new adapter — `core.py` stays unchanged.

## Uninstall

```bash
rm -rf ~/.stopwatch
```

For Claude: remove `env.STOPWATCH_DIR`, `env.STOPWATCH_TITLE`, and `hooks.Stop` from `~/.claude/settings.json`.

For Codex: remove the stopwatch entry from `hooks.Stop` in `~/.codex/hooks.json`.
