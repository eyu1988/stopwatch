#!/bin/sh
set -e

REPO="https://raw.githubusercontent.com/eyu1988/stopwatch/main"
INSTALL_DIR="$HOME/.stopwatch"
CLAUDE_HOOK_CMD="python3 ~/.stopwatch/adapter_claude.py 2>/dev/null || true"

# ── colors ───────────────────────────────────────────────────────────────────
BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'

step()    { printf "  ${CYAN}·${RESET} $1\n"; }
ok()      { printf "  ${GREEN}✓${RESET} $1\n"; }
warn()    { printf "  ${YELLOW}!${RESET} $1\n"; }
die()     { printf "  ${RED}✗${RESET} $1\n" >&2; exit 1; }
ask()     {
  # ask <question> <default>
  printf "\n  ${YELLOW}?${RESET} ${BOLD}$1${RESET} ${DIM}(default: $2)${RESET}\n  › "
}
divider() { printf "  ${DIM}────────────────────────────────────${RESET}\n"; }

# ── header ───────────────────────────────────────────────────────────────────
printf "\n${BOLD}  stopwatch${RESET}  ${DIM}AI session timeline recorder${RESET}\n\n"
divider

# ── preflight ────────────────────────────────────────────────────────────────
command -v python3 >/dev/null 2>&1 || die "python3 not found — please install it first"
command -v curl    >/dev/null 2>&1 || die "curl not found"

# ── download ─────────────────────────────────────────────────────────────────
step "Downloading files to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
curl -fsSL "$REPO/core.py"           -o "$INSTALL_DIR/core.py"
curl -fsSL "$REPO/adapter_claude.py" -o "$INSTALL_DIR/adapter_claude.py"
curl -fsSL "$REPO/adapter_codex.py"  -o "$INSTALL_DIR/adapter_codex.py"
ok "Files downloaded"

# ── configure ────────────────────────────────────────────────────────────────
printf "\n${BOLD}  Configuration${RESET}\n"

DEFAULT_DIR="$HOME/.stopwatch/timeline"
ask "Where should timeline files be saved?" "~/.stopwatch/timeline"
read -r STOPWATCH_DIR
STOPWATCH_DIR="${STOPWATCH_DIR:-$DEFAULT_DIR}"
# pass via env var to avoid shell-escaping issues in Python
STOPWATCH_DIR=$(RAWPATH="$STOPWATCH_DIR" python3 -c "
import os
p = os.environ['RAWPATH'].replace('\\ ', ' ')
print(os.path.expanduser(p))
")

ask "Weekly file title (shown at top of each .md)" "stopwatch"
read -r STOPWATCH_TITLE
STOPWATCH_TITLE="${STOPWATCH_TITLE:-stopwatch}"

printf "\n  ${YELLOW}?${RESET} ${BOLD}Which tools to enable?${RESET}\n"
printf "    ${DIM}1)${RESET} Claude Code\n"
printf "    ${DIM}2)${RESET} Codex CLI\n"
printf "    ${DIM}3)${RESET} Both\n"
printf "  › "
read -r TOOL_CHOICE
case "$TOOL_CHOICE" in
  2) TOOL_LABEL="Codex CLI" ;;
  3) TOOL_LABEL="Claude Code + Codex CLI" ;;
  *) TOOL_CHOICE=1; TOOL_LABEL="Claude Code" ;;
esac

# ── confirm ──────────────────────────────────────────────────────────────────
printf "\n"
divider
printf "  ${DIM}Directory${RESET}   $STOPWATCH_DIR\n"
printf "  ${DIM}Title${RESET}       $STOPWATCH_TITLE\n"
printf "  ${DIM}Tools${RESET}       $TOOL_LABEL\n"
divider
printf "\n  ${YELLOW}?${RESET} ${BOLD}Apply these settings?${RESET} ${DIM}[Y/n]${RESET} "
read -r CONFIRM
case "$CONFIRM" in
  [nN]*) printf "\n  Cancelled.\n\n"; exit 0 ;;
esac

# ── apply ────────────────────────────────────────────────────────────────────
printf "\n${BOLD}  Applying${RESET}\n"
mkdir -p "$STOPWATCH_DIR"

if [ "$TOOL_CHOICE" = "1" ] || [ "$TOOL_CHOICE" = "3" ]; then
  STOPWATCH_DIR_VAL="$STOPWATCH_DIR" \
  STOPWATCH_TITLE_VAL="$STOPWATCH_TITLE" \
  HOOK_CMD_VAL="$CLAUDE_HOOK_CMD" \
  python3 - <<'PYEOF'
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")
stopwatch_dir   = os.environ["STOPWATCH_DIR_VAL"]
stopwatch_title = os.environ["STOPWATCH_TITLE_VAL"]
hook_cmd        = os.environ["HOOK_CMD_VAL"]

try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

settings.setdefault("env", {})
settings["env"]["STOPWATCH_DIR"]   = stopwatch_dir
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
PYEOF
  ok "Updated ~/.claude/settings.json"
fi

if [ "$TOOL_CHOICE" = "2" ] || [ "$TOOL_CHOICE" = "3" ]; then
  SHELL_RC="$HOME/.zshrc"
  [ -f "$HOME/.bashrc" ] && SHELL_RC="$HOME/.bashrc"
  WRAPPER="
# stopwatch — Codex session logger
codex() {
  command codex \"\$@\"
  STOPWATCH_DIR=\"$STOPWATCH_DIR\" STOPWATCH_TITLE=\"$STOPWATCH_TITLE\" \\
    python3 ~/.stopwatch/adapter_codex.py --cwd \"\$PWD\" 2>/dev/null || true
}"
  if ! grep -q "stopwatch — Codex" "$SHELL_RC" 2>/dev/null; then
    printf '%s\n' "$WRAPPER" >> "$SHELL_RC"
    ok "Added Codex wrapper → $SHELL_RC"
    warn "Run: source $SHELL_RC"
  else
    ok "Codex wrapper already present in $SHELL_RC"
  fi
fi

# ── done ─────────────────────────────────────────────────────────────────────
printf "\n"
divider
printf "  ${GREEN}${BOLD}Done!${RESET} stopwatch is ready.\n"
divider
printf "\n"
