English | [中文](README.zh-CN.md)

# stopwatch

Automatically records every Claude Code conversation turn into weekly Markdown files, grouped by session. Optimized for Obsidian reading mode.

## How it works

Uses Claude Code's **Stop hook** — fires after every response. Each conversation session becomes a collapsible callout card. Starting a new session (`/clear`) creates a new card.

```
stopwatch/
└── 2026-W25.md
    ├── ## 06-16（周二）
    │   ├── 💬 11:19–11:40 · project-a  ← session 1
    │   └── 💬 14:02–14:35 · project-b  ← session 2 (after /clear)
    └── ## 06-17（周三）
        └── 💬 09:11–09:58 · project-a
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/eyu1988/stopwatch/main/install.sh | sh
```

The script will ask where to save timeline files. Leave blank to use the default (`~/.claude-timeline/timeline`).

## Requirements

- [Claude Code](https://claude.ai/code)
- Python 3

## Configuration

The install script sets `CLAUDE_TIMELINE_DIR` in `~/.claude/settings.json`. To change the save location after installation, edit that value directly:

```json
{
  "env": {
    "CLAUDE_TIMELINE_DIR": "/your/new/path"
  }
}
```

## Uninstall

```bash
rm -rf ~/.claude-timeline
```

Then remove the `env.CLAUDE_TIMELINE_DIR` and `hooks.Stop` entries from `~/.claude/settings.json`.
