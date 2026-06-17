English | [中文](README.zh-CN.md)

# stopwatch

Automatically records every AI coding agent conversation into weekly Markdown files, grouped by session. Optimized for Obsidian reading mode.

Supports **Claude Code** and **Codex CLI**.

## How it works

Each tool's hook fires after a response. The adapter parses that tool's transcript format and passes the last turn to the shared core writer.

```
Tool hook fires
  → adapter_claude.py / adapter_codex.py   (parse transcript)
    → core.py                               (write Markdown)
```

Each session becomes a callout card. Starting a new session (`/clear`) creates a new card.

```
~/.stopwatch/timeline/
└── 2026-W25.md
    ├── ## 06-16
    │   ├── 💬 11:19–11:40 · project-a  ← session 1
    │   └── 💬 14:02–14:35 · project-b  ← session 2 (after /clear)
    └── ## 06-17
        └── 💬 09:11–09:58 · project-a
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/eyu1988/stopwatch/main/install.sh | sh
```

The installer will ask:
1. Where to save timeline files (default: `~/.stopwatch/timeline`)
2. Weekly file title (default: `stopwatch`)
3. Which tools to enable — Claude only / Codex only / Both

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

For Codex, they are set inline in the shell wrapper added to `~/.zshrc`.

## Architecture

```
~/.stopwatch/
├── core.py             — tool-agnostic Markdown writer
├── adapter_claude.py   — Claude Code Stop hook entry point
├── adapter_codex.py    — Codex CLI shell wrapper entry point
└── install.sh
```

Adding support for a new tool only requires a new adapter — `core.py` stays unchanged.

## Uninstall

```bash
rm -rf ~/.stopwatch
```

For Claude: remove `env.STOPWATCH_DIR`, `env.STOPWATCH_TITLE`, and `hooks.Stop` from `~/.claude/settings.json`.

For Codex: remove the `codex()` wrapper function from `~/.zshrc`.
