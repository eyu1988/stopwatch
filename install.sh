#!/bin/sh
set -e

REPO="https://raw.githubusercontent.com/eyu1988/stopwatch/main"
INSTALL_DIR="$HOME/.claude-timeline"
HOOK_CMD="python3 ~/.claude-timeline/timeline_logger.py 2>/dev/null || true"

echo "Installing stopwatch..."
echo ""

# 检查 python3
if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required but not found." >&2
  exit 1
fi

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# 下载脚本
echo "Downloading timeline_logger.py..."
curl -fsSL "$REPO/timeline_logger.py" -o "$INSTALL_DIR/timeline_logger.py"

# 询问存储目录
echo ""
printf "Timeline directory (where .md files are saved)\n"
printf "Default: ~/Documents/AI对话录\n"
printf "> "
read -r TIMELINE_DIR
TIMELINE_DIR="${TIMELINE_DIR:-$HOME/Documents/AI对话录}"
# 展开 ~
TIMELINE_DIR=$(python3 -c "import os; print(os.path.expanduser('$TIMELINE_DIR'))")
mkdir -p "$TIMELINE_DIR"

# 合并 settings.json
python3 - <<PYEOF
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")
timeline_dir = """$TIMELINE_DIR"""
hook_cmd = """$HOOK_CMD"""

try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

settings.setdefault("env", {})
settings["env"]["CLAUDE_TIMELINE_DIR"] = timeline_dir

settings.setdefault("hooks", {})
settings["hooks"].setdefault("Stop", [])

already = any(
    h.get("command") == hook_cmd
    for entry in settings["hooks"]["Stop"]
    for h in entry.get("hooks", [])
)

if not already:
    settings["hooks"]["Stop"].append({
        "hooks": [{"type": "command", "command": hook_cmd}]
    })

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")

print("Updated", settings_path)
PYEOF

echo ""
echo "Done! stopwatch is installed."
echo ""
echo "  Script  : $INSTALL_DIR/timeline_logger.py"
echo "  Timeline: $TIMELINE_DIR"
echo ""
echo "Start a new Claude Code session to activate."
