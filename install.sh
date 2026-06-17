#!/bin/sh
set -e

REPO="https://raw.githubusercontent.com/eyu1988/stopwatch/main"
INSTALL_DIR="$HOME/.stopwatch"

BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'

printf "\n  ${BOLD}stopwatch${RESET}  ${DIM}AI session timeline recorder${RESET}\n\n"
printf "  ${DIM}────────────────────────────────────${RESET}\n\n"

command -v python3 >/dev/null 2>&1 || { printf "  ${RED}✗${RESET} python3 not found\n\n"; exit 1; }
command -v curl    >/dev/null 2>&1 || { printf "  ${RED}✗${RESET} curl not found\n\n";    exit 1; }

printf "  ${CYAN}·${RESET} Downloading files...\n"
mkdir -p "$INSTALL_DIR"
curl -fsSL "$REPO/core.py"           -o "$INSTALL_DIR/core.py"
curl -fsSL "$REPO/adapter_claude.py" -o "$INSTALL_DIR/adapter_claude.py"
curl -fsSL "$REPO/adapter_codex.py"  -o "$INSTALL_DIR/adapter_codex.py"
printf "  ${GREEN}✓${RESET} Files ready\n"

# write Python UI to a temp file so stdin stays connected to the terminal
_PYUI=$(mktemp /tmp/stopwatch_XXXXXX.py)
trap 'rm -f "$_PYUI"' EXIT
cat > "$_PYUI" << 'PYEOF'
import sys, os, tty, termios, json, re

try:
    import readline
    HAS_RL = True
except ImportError:
    HAS_RL = False

# ── ANSI ─────────────────────────────────────────────────────────────────────
B='\033[1m'; D='\033[2m'; R='\033[0m'
G='\033[0;32m'; Y='\033[1;33m'; RE='\033[0;31m'

INSTALL_DIR = os.environ.get('INSTALL_DIR', os.path.expanduser('~/.stopwatch'))
HOOK_CMD    = 'python3 ~/.stopwatch/adapter_claude.py 2>/dev/null || true'

# ── primitives ────────────────────────────────────────────────────────────────
def divider(): print(f"\n  {D}────────────────────────────────────{R}")
def ok(m):     print(f"  {G}✓{R} {m}")
def warn(m):   print(f"  {Y}!{R} {m}")

def getch():
    fd  = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        c = sys.stdin.buffer.read(1)
        if c == b'\x1b':
            c += sys.stdin.buffer.read(2)
        return c
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)

# ── text input with pre-filled default ───────────────────────────────────────
def ask_text(q, default=''):
    if HAS_RL:
        readline.set_startup_hook(lambda: readline.insert_text(default))
    try:
        val = input(f"\n  {Y}?{R} {B}{q}{R}  {D}[{default}]{R}\n  {D}›{R} ")
    except (EOFError, KeyboardInterrupt):
        print(); sys.exit(0)
    finally:
        if HAS_RL:
            readline.set_startup_hook(None)
    return val.strip() or default

# ── multi-select: space=toggle ↑↓=move enter=confirm ─────────────────────────
def ask_multiselect(q, opts, hints=None, default_selected=None):
    selected = set(default_selected or [])
    cur      = [0]
    n        = len(opts)
    HINT_BAR = f"  {D}space=toggle  ↑↓=move  enter=confirm{R}"

    def render_opts():
        for i, o in enumerate(opts):
            h      = f"  {D}{hints[i]}{R}" if hints and hints[i] else ""
            check  = f"{G}✓{R}" if i in selected else f"{D}•{R}"
            cursor = f"{G}>{R}" if i == cur[0] else " "
            label  = f"{G}{o}{R}" if i in selected else (f"{B}{o}{R}" if i == cur[0] else o)
            sys.stdout.write(f"  {cursor} {check} {label}{h}\n")

    # initial draw: blank + prompt + opts + hint  (total = n+3 lines)
    sys.stdout.write(f"\n  {Y}?{R} {B}{q}{R}\n")
    render_opts()
    sys.stdout.write(f"{HINT_BAR}\n")
    sys.stdout.flush()

    while True:
        k = getch()

        if k in (b'\r', b'\n'):
            if not selected:             # require at least one
                selected.add(0)
            # clear block and show ✓ summary  (n+3 lines up)
            sys.stdout.write(f'\033[{n + 3}A\033[J')
            label = " + ".join(opts[i] for i in sorted(selected))
            sys.stdout.write(f"  {G}✓{R} {B}{q}{R}  {G}{label}{R}\n")
            sys.stdout.flush()
            return sorted(selected)

        elif k == b' ':
            if cur[0] in selected: selected.discard(cur[0])
            else:                  selected.add(cur[0])

        elif k == b'\x03':
            print(); sys.exit(0)
        elif k in (b'\x1b[A', b'k'):
            cur[0] = (cur[0] - 1) % n
        elif k in (b'\x1b[B', b'j'):
            cur[0] = (cur[0] + 1) % n
        else:
            continue

        # redraw opts + hint bar  (n+1 lines up from cursor)
        sys.stdout.write(f'\033[{n + 1}A')
        render_opts()
        sys.stdout.write(f"\033[2K{HINT_BAR}\n")
        sys.stdout.flush()

# ── single-keypress confirm ───────────────────────────────────────────────────
def ask_confirm(q):
    sys.stdout.write(f"\n  {Y}?{R} {B}{q}{R} {D}[Y/n]{R} ")
    sys.stdout.flush()
    k = getch()
    print()
    return k not in (b'n', b'N')

# ── configure ────────────────────────────────────────────────────────────────
print(f"\n  {B}Configure{R}")

raw_dir = ask_text("Timeline directory",
                   os.path.expanduser("~/.stopwatch/timeline"))
stopwatch_dir = os.path.expanduser(re.sub(r'\\(.)', r'\1', raw_dir))

title = ask_text("Weekly file title", "stopwatch")

tool_indices = ask_multiselect(
    "Tools to enable",
    opts  = ["Claude Code", "Codex CLI"],
    hints = ["Stop hook", "hooks.json"],
    default_selected = [0],
)
tool_key   = "both" if set(tool_indices) == {0, 1} else ("claude" if 0 in tool_indices else "codex")
tool_label = " + ".join(["Claude Code", "Codex CLI"][i] for i in tool_indices)

# ── confirm ───────────────────────────────────────────────────────────────────
divider()
print(f"\n  {D}Directory{R}   {stopwatch_dir}")
print(f"  {D}Title    {R}   {title}")
print(f"  {D}Tools    {R}   {tool_label}")
divider()

if not ask_confirm("Apply?"):
    print(f"\n  Aborted.\n"); sys.exit(0)

# ── apply ─────────────────────────────────────────────────────────────────────
print(f"\n  {B}Installing{R}")
os.makedirs(stopwatch_dir, exist_ok=True)

if 0 in tool_indices:  # Claude
    p = os.path.expanduser("~/.claude/settings.json")
    try:
        with open(p) as f: s = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        s = {}
    s.setdefault("env", {})
    s["env"]["STOPWATCH_DIR"]   = stopwatch_dir
    s["env"]["STOPWATCH_TITLE"] = title
    s.setdefault("hooks", {}).setdefault("Stop", [])
    if not any(h.get("command") == HOOK_CMD
               for e in s["hooks"]["Stop"] for h in e.get("hooks", [])):
        s["hooks"]["Stop"].append({"hooks": [{"type": "command", "command": HOOK_CMD}]})
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        json.dump(s, f, indent=2, ensure_ascii=False)
        f.write("\n")
    ok("Updated ~/.claude/settings.json")

if 1 in tool_indices:  # Codex — native Stop hook via ~/.codex/hooks.json
    CODEX_HOOK_CMD = (
        f'STOPWATCH_DIR="{stopwatch_dir}" STOPWATCH_TITLE="{title}" '
        f'python3 ~/.stopwatch/adapter_codex.py 2>/dev/null || true'
    )
    p = os.path.expanduser("~/.codex/hooks.json")
    try:
        with open(p) as f: ch = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        ch = {}
    ch.setdefault("hooks", {}).setdefault("Stop", [])
    already = any(
        h.get("command", "").startswith("python3 ~/.stopwatch/adapter_codex.py")
        for e in ch["hooks"]["Stop"] for h in e.get("hooks", [])
    )
    if not already:
        ch["hooks"]["Stop"].append({"hooks": [{"type": "command", "command": CODEX_HOOK_CMD, "timeout": 15}]})
    # always update env vars in existing stopwatch hook
    else:
        for e in ch["hooks"]["Stop"]:
            for h in e.get("hooks", []):
                if h.get("command", "").startswith("python3 ~/.stopwatch/adapter_codex.py") or \
                   "adapter_codex" in h.get("command", ""):
                    h["command"] = CODEX_HOOK_CMD
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        json.dump(ch, f, indent=2, ensure_ascii=False)
        f.write("\n")
    ok("Updated ~/.codex/hooks.json (native Stop hook)")

divider()
print(f"\n  {G}{B}✓ Done!{R} stopwatch is ready.\n")
PYEOF
INSTALL_DIR="$INSTALL_DIR" python3 "$_PYUI"
