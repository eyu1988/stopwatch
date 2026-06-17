[English](README.md) | 中文

# stopwatch

自动将 AI 编程助手的对话记录到按周归档的 Markdown 文件中，按 session 分组，适配 Obsidian 阅读模式。

支持 **Claude Code** 和 **Codex CLI**。

## 工作原理

每个工具在回复结束后触发 Stop hook，adapter 解析该工具的 transcript 格式，将最后一轮对话交给公共写入核心处理。

```
工具 Stop hook 触发
  → adapter_claude.py  （读取 ~/.claude/projects/…/*.jsonl）
  → adapter_codex.py   （读取 ~/.codex/sessions/YYYY/MM/DD/*.jsonl）
    → core.py          （写入 Markdown）
```

两个工具均使用原生 Stop hook 配置——Claude 写入 `~/.claude/settings.json`，Codex 写入 `~/.codex/hooks.json`。

每个 session 生成一张独立卡片，执行 `/clear` 后开启新卡片。

```
~/.stopwatch/timeline/
├── claude/
│   └── 2026-W25.md
│       ├── ## 06-16
│       │   ├── 💬 11:19–11:40 · 项目A   ← session 1
│       │   └── 💬 14:02–14:35 · 项目B   ← session 2（/clear 后）
│       └── ## 06-17
│           └── 💬 09:11–09:58 · 项目A
└── codex/
    └── 2026-W25.md
```

## 安装

```bash
sh <(curl -fsSL https://raw.githubusercontent.com/eyu1988/stopwatch/main/install.sh)
```

安装过程中会依次询问：
1. 时间线文件的保存目录（默认：`~/.stopwatch/timeline`）
2. 周文件标题（默认：`stopwatch`）
3. 启用哪些工具——Claude Code 和/或 Codex CLI（多选复选框）

## 环境要求

- Python 3
- [Claude Code](https://claude.ai/code) 和/或 [Codex CLI](https://github.com/openai/codex)

## 配置

两个环境变量控制行为：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `STOPWATCH_DIR` | `~/.stopwatch/timeline` | `.md` 文件保存路径 |
| `STOPWATCH_TITLE` | `stopwatch` | 每个周文件顶部的标题 |

Claude 的配置写在 `~/.claude/settings.json`：

```json
{
  "env": {
    "STOPWATCH_DIR": "/your/path",
    "STOPWATCH_TITLE": "your title"
  }
}
```

Codex 的配置以内联变量的形式写在 `~/.codex/hooks.json` 的 Stop hook 命令中。

## 架构

```
~/.stopwatch/
├── core.py             — 与工具无关的 Markdown 写入逻辑
├── adapter_claude.py   — Claude Code Stop hook 入口
├── adapter_codex.py    — Codex CLI shell wrapper 入口
└── install.sh
```

新增工具支持只需添加一个 adapter，`core.py` 不需要改动。

## 卸载

```bash
rm -rf ~/.stopwatch
```

Claude：从 `~/.claude/settings.json` 中删除 `env.STOPWATCH_DIR`、`env.STOPWATCH_TITLE` 和 `hooks.Stop`。

Codex：从 `~/.codex/hooks.json` 的 `hooks.Stop` 中删除 stopwatch 条目。
