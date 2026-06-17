# Changelog

All notable changes to this project will be documented in this file.

## [0.4.0] - 2026-06-17

### Added
- Codex native Stop hook: install now writes to `~/.codex/hooks.json` instead of injecting a shell wrapper into `~/.zshrc`

### Fixed
- Codex adapter now correctly reads session files at `~/.codex/sessions/YYYY/MM/DD/*.jsonl` (recursive, date-partitioned structure)
- Codex adapter parses `event_msg` event stream format: `user_message.message` for user input, `task_complete.last_agent_message` for final AI response; also extracts `session_id` and `cwd` from `session_meta`

### Changed
- Installer tools selection replaced with lark-style multi-select: `•`/`✓` checkboxes, `>` cursor, space=toggle, enter=confirm; "Both" option removed in favor of independent checkboxes
- Text input prompts now display `[default]` hint so the fallback value is always visible
- Removed zshrc shell wrapper approach for Codex; both Claude and Codex now use native Stop hooks

## [0.3.0] - 2026-06-16

### Added
- Multi-agent support via adapter architecture: `core.py` handles Markdown writing, `adapter_claude.py` and `adapter_codex.py` handle tool-specific transcript parsing
- Codex CLI adapter (`adapter_codex.py`) using a shell wrapper approach
- Per-agent subdirectories: logs are now organized as `STOPWATCH_DIR/<agent>/YYYY-WXX.md`
- Install prompt to choose which tools to enable: Claude only / Codex only / Both

### Changed
- Renamed install directory from `~/.claude-timeline` to `~/.stopwatch`
- `timeline_logger.py` split into `core.py` + `adapter_claude.py`

## [0.2.0] - 2026-06-16

### Added
- `STOPWATCH_TITLE` env var to customize the weekly file title
- Language switcher in README (`English | 中文`)
- Separate `README.zh-CN.md` for Simplified Chinese

### Changed
- Renamed env vars from `CLAUDE_TIMELINE_DIR` / `CLAUDE_TIMELINE_TITLE` to `STOPWATCH_DIR` / `STOPWATCH_TITLE` for tool-agnostic naming
- Default save path changed to `~/.stopwatch/timeline`
- Weekly file title changed from hardcoded `AI对话录` to configurable (default: `stopwatch`)

## [0.1.0] - 2026-06-16

### Added
- Claude Code Stop hook integration: fires after every response turn
- Weekly Markdown files (`YYYY-WXX.md`) with daily sections
- Session-based grouping: each `session_id` gets its own callout card; `/clear` starts a new card
- Time range in callout header (`💬 HH:MM–HH:MM · project`)
- Obsidian Callout format (`> [!quote]`) for reading mode rendering
- `install.sh` with interactive prompts for save directory and file title
- Duplicate hook prevention: re-running install does not add redundant hooks
