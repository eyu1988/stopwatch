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

INSTALL_DIR="$INSTALL_DIR" python3 - << 'PYEOF'
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
        val = input(f"\n  {Y}?{R} {B}{q}{R}\n  {D}›{R} ")
    except (EOFError, KeyboardInterrupt):
        print(); sys.exit(0)
    finally:
        if HAS_RL:
            readline.set_startup_hook(None)
    return val.strip() or default

# ── arrow-key single-select ───────────────────────────────────────────────────
def ask_select(q, opts, hints=None, default=0):
    """
    opts  : list of option labels
    hints : optional sub-labels (same length), shown dimmed after each option
    """
    cur = [default]
    n   = len(opts)

    def render_opts():
        for i, o in enumerate(opts):
            h = f"  {D}{hints[i]}{R}" if hints else ""
            if i == cur[0]:
                sys.stdout.write(f"  {G}❯{R} {o}{h}\n")
            else:
                sys.stdout.write(f"    {D}{o}{R}\n")

    # initial draw: blank line + prompt + options
    sys.stdout.write(f"\n  {Y}?{R} {B}{q}{R}\n")
    render_opts()
    sys.stdout.flush()

    while True:
        k = getch()

        if k in (b'\r', b'\n', b' '):
            # clear block (blank + prompt + n options) and show ✓ line
            sys.stdout.write(f'\033[{n + 2}A\033[J')
            sys.stdout.write(f"  {G}✓{R} {B}{q}{R}  {G}{opts[cur[0]]}{R}\n")
            sys.stdout.flush()
            return cur[0]

        elif k == b'\x03':  # Ctrl-C
            print(); sys.exit(0)

        elif k in (b'\x1b[A', b'k'):  # ↑
            cur[0] = (cur[0] - 1) % n
        elif k in (b'\x1b[B', b'j'):  # ↓
            cur[0] = (cur[0] + 1) % n
        else:
            continue

        # redraw only the option lines
        sys.stdout.write(f'\033[{n}A')
        for i, o in enumerate(opts):
            h = f"  {D}{hints[i]}{R}" if hints else ""
            if i == cur[0]:
                sys.stdout.write(f"\033[2K  {G}❯{R} {o}{h}\n")
            else:
                sys.stdout.write(f"\033[2K    {D}{o}{R}\n")
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

tool_i = ask_select(
    "Tools to enable",
    opts  = ["Claude Code", "Codex CLI", "Both"],
    hints = ["Stop hook", "shell wrapper", ""],
)
TOOL_KEYS   = ["claude", "codex", "both"]
TOOL_LABELS = ["Claude Code", "Codex CLI", "Claude Code + Codex CLI"]
tool_key    = TOOL_KEYS[tool_i]
tool_label  = TOOL_LABELS[tool_i]

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

if tool_key in ("claude", "both"):
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

if tool_key in ("codex", "both"):
    rc = os.path.expanduser("~/.zshrc")
    if os.path.exists(os.path.expanduser("~/.bashrc")):
        rc = os.path.expanduser("~/.bashrc")
    wrapper = (
        f'\n# stopwatch — Codex session logger\n'
        f'codex() {{\n'
        f'  command codex "$@"\n'
        f'  STOPWATCH_DIR="{stopwatch_dir}" STOPWATCH_TITLE="{title}" \\\n'
        f'    python3 ~/.stopwatch/adapter_codex.py --cwd "$PWD" 2>/dev/null || true\n'
        f'}}'
    )
    try:
        already = "stopwatch — Codex" in open(rc).read()
    except FileNotFoundError:
        already = False
    if not already:
        with open(rc, "a") as f: f.write(wrapper + "\n")
        ok(f"Added Codex wrapper → {rc}")
        warn(f"Run: source {rc}")
    else:
        ok(f"Codex wrapper already in {rc}")

divider()
print(f"\n  {G}{B}✓ Done!{R} stopwatch is ready.\n")
PYEOF
