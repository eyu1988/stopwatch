#!/bin/sh
set -e

REPO="https://raw.githubusercontent.com/eyu1988/stopwatch/main"
INSTALL_DIR="$HOME/.stopwatch"
CLAUDE_HOOK_CMD="python3 ~/.stopwatch/adapter_claude.py 2>/dev/null || true"

echo "Installing stopwatch..."
echo ""

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required but not found." >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"

echo "Downloading files..."
curl -fsSL "$REPO/core.py"           -o "$INSTALL_DIR/core.py"
curl -fsSL "$REPO/adapter_claude.py" -o "$INSTALL_DIR/adapter_claude.py"
curl -fsSL "$REPO/adapter_codex.py"  -o "$INSTALL_DIR/adapter_codex.py"

# 存储目录
echo ""
printf "Timeline directory (where .md files are saved)\n"
printf "Default: ~/.stopwatch/timeline\n"
printf "> "
read -r STOPWATCH_DIR </dev/tty
STOPWATCH_DIR="${STOPWATCH_DIR:-$HOME/.stopwatch/timeline}"
STOPWATCH_DIR=$(python3 -c "import os; print(os.path.expanduser('$STOPWATCH_DIR'))")
mkdir -p "$STOPWATCH_DIR"

# 文件标题
echo ""
printf "Weekly file title (shown at the top of each .md file)\n"
printf "Default: stopwatch\n"
printf "> "
read -r STOPWATCH_TITLE </dev/tty
STOPWATCH_TITLE="${STOPWATCH_TITLE:-stopwatch}"

# 选择工具
echo ""
printf "Which tools to enable? [1] Claude only  [2] Codex only  [3] Both\n"
printf "Default: 1\n"
printf "> "
read -r TOOL_CHOICE </dev/tty
TOOL_CHOICE="${TOOL_CHOICE:-1}"

# 更新 Claude settings.json
if [ "$TOOL_CHOICE" = "1" ] || [ "$TOOL_CHOICE" = "3" ]; then
  python3 - <<PYEOF
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")
stopwatch_dir = """$STOPWATCH_DIR"""
stopwatch_title = """$STOPWATCH_TITLE"""
hook_cmd = """$CLAUDE_HOOK_CMD"""

try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

settings.setdefault("env", {})
settings["env"]["STOPWATCH_DIR"] = stopwatch_dir
settings["env"]["STOPWATCH_TITLE"] = stopwatch_title

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

print("Updated ~/.claude/settings.json")
PYEOF
fi

# 添加 Codex shell wrapper
if [ "$TOOL_CHOICE" = "2" ] || [ "$TOOL_CHOICE" = "3" ]; then
  SHELL_RC="$HOME/.zshrc"
  [ -f "$HOME/.bashrc" ] && SHELL_RC="$HOME/.bashrc"

  WRAPPER='
# stopwatch — Codex session logger
codex() {
  command codex "$@"
  STOPWATCH_DIR="'"$STOPWATCH_DIR"'" STOPWATCH_TITLE="'"$STOPWATCH_TITLE"'" \
    python3 ~/.stopwatch/adapter_codex.py --cwd "$PWD" 2>/dev/null || true
}'

  if ! grep -q "stopwatch — Codex" "$SHELL_RC" 2>/dev/null; then
    echo "$WRAPPER" >> "$SHELL_RC"
    echo "Added Codex wrapper to $SHELL_RC (run: source $SHELL_RC)"
  else
    echo "Codex wrapper already present in $SHELL_RC"
  fi
fi

echo ""
echo "Done! stopwatch is installed."
echo ""
echo "  Script  : $INSTALL_DIR"
echo "  Timeline: $STOPWATCH_DIR"
echo "  Title   : $STOPWATCH_TITLE"
