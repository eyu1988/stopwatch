[English](README.md) | 中文

# stopwatch

自动将每次 Claude Code 对话记录到按周归档的 Markdown 文件中，按 session 分组，适配 Obsidian 阅读模式。

## 工作原理

基于 Claude Code 的 **Stop hook**——每次回复结束后自动触发。每个对话 session 生成一张独立卡片，执行 `/clear` 后开启新卡片。

```
stopwatch/
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
