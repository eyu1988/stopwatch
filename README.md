# stopwatch

Automatically records every Claude Code conversation turn into weekly Markdown files, grouped by session. Optimized for Obsidian reading mode.

## How it works

Uses Claude Code's **Stop hook** — fires after every response. Each conversation session becomes a collapsible callout card. Starting a new session (`/clear`) creates a new card.

```
06_AI对话录/
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

The script will ask where to save timeline files. Leave blank to use the default (`~/Documents/stopwatch`).

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

---

# stopwatch（简体中文）

自动将每次 Claude Code 对话记录到按周归档的 Markdown 文件中，按 session 分组，适配 Obsidian 阅读模式。

## 工作原理

基于 Claude Code 的 **Stop hook**——每次回复结束后自动触发。每个对话 session 生成一张独立卡片，执行 `/clear` 后开启新卡片。

```
06_AI对话录/
└── 2026-W25.md
    ├── ## 06-16（周二）
    │   ├── 💬 11:19–11:40 · 项目A   ← session 1
    │   └── 💬 14:02–14:35 · 项目B   ← session 2（/clear 后）
    └── ## 06-17（周三）
        └── 💬 09:11–09:58 · 项目A
```

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/eyu1988/stopwatch/main/install.sh | sh
```

执行后会提示选择时间线文件的保存目录，直接回车使用默认路径（`~/Documents/stopwatch`）。

## 环境要求

- [Claude Code](https://claude.ai/code)
- Python 3

## 配置

安装脚本会在 `~/.claude/settings.json` 中写入 `CLAUDE_TIMELINE_DIR`。安装后如需修改保存路径，直接编辑该值：

```json
{
  "env": {
    "CLAUDE_TIMELINE_DIR": "/your/new/path"
  }
}
```

## 卸载

```bash
rm -rf ~/.claude-timeline
```

然后手动删除 `~/.claude/settings.json` 中的 `env.CLAUDE_TIMELINE_DIR` 和 `hooks.Stop` 条目。
