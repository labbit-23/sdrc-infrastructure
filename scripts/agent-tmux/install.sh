#!/usr/bin/env bash
set -euo pipefail

# Install the agent-tmux kit on this machine: Claude Code / Codex sessions that survive a reboot,
# each tmux session reopening ITS OWN conversation. See runbooks/tmux-agent-sessions.md.
#
#   ./install.sh [--dry-run] [--no-plugins] [--boot] [--prefix DIR]
#
#   --dry-run      show what would change, change nothing
#   --no-plugins   do not git-clone tpm / tmux-resurrect / tmux-continuum (already installed or offline)
#   --boot         also start tmux at boot (continuum systemd unit + loginctl enable-linger)
#   --prefix DIR   where the launchers go (default ~/.local/bin; must be on PATH)
#
# Idempotent: re-running replaces the marked block in ~/.tmux.conf and never duplicates a setting
# you already have configured by hand.

DRY=0; PLUGINS=1; BOOT=0; PREFIX="${HOME}/.local/bin"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;; --no-plugins) PLUGINS=0 ;; --boot) BOOT=1 ;;
    --prefix) PREFIX="$2"; shift ;;
    -h|--help) sed -n '3,16p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac; shift
done
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
conf="${TMUX_CONF:-$HOME/.tmux.conf}"
do_() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }

command -v tmux >/dev/null    || { echo "tmux is not installed" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required (launchers generate UUIDs)" >&2; exit 1; }
command -v git >/dev/null || [ "$PLUGINS" = 0 ] || { echo "git is required to fetch tmux plugins (or use --no-plugins)" >&2; exit 1; }

echo "== launchers -> $PREFIX"
do_ mkdir -p "$PREFIX"
for f in claude-tmux codex-tmux agent-adopt; do do_ install -m 0755 "$here/$f" "$PREFIX/$f"; done
case ":$PATH:" in *":$PREFIX:"*) ;; *) echo "WARNING: $PREFIX is not on PATH; tmux restore will not find the launchers." >&2 ;; esac
# A launcher named 'cc' would shadow the C compiler -- these names are deliberate.
for n in cc cx; do [ "$(command -v $n 2>/dev/null)" = "$PREFIX/$n" ] && echo "WARNING: $PREFIX/$n shadows a system command" >&2; done

if [ "$PLUGINS" = 1 ]; then
  echo "== tmux plugins -> ~/.tmux/plugins"
  do_ mkdir -p "$HOME/.tmux/plugins"
  for p in tpm tmux-resurrect tmux-continuum; do
    [ -d "$HOME/.tmux/plugins/$p" ] && { echo "have $p"; continue; }
    do_ git clone --depth 1 "https://github.com/tmux-plugins/$p" "$HOME/.tmux/plugins/$p"
  done
fi

echo "== $conf"
BOOT="$BOOT" DRY="$DRY" CONF="$conf" python3 - <<'PY'
import os, re
conf, boot, dry = os.environ["CONF"], os.environ["BOOT"] == "1", os.environ["DRY"] == "1"
BEGIN = "# >>> agent-tmux (managed by sdrc-infrastructure/scripts/agent-tmux/install.sh) >>>"
END = "# <<< agent-tmux <<<"
text = open(conf).read() if os.path.exists(conf) else ""
# drop any previous managed block
text = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?", "", text, flags=re.S)

def has(pattern):  # already configured by hand, outside our block
    return re.search(pattern, text, re.M) is not None

lines = []
for plugin in ("tmux-plugins/tpm", "tmux-plugins/tmux-sensible", "tmux-plugins/tmux-resurrect", "tmux-plugins/tmux-continuum"):
    if not has(r"@plugin\s+'?" + re.escape(plugin)):
        lines.append(f"set -g @plugin '{plugin}'")
wanted = [
    (r"@continuum-restore", "set -g @continuum-restore 'on'"),
    (r"@continuum-save-interval", "set -g @continuum-save-interval '10'"),
    (r"@resurrect-processes", """set -g @resurrect-processes '"~claude->claude-tmux" "~codex->codex-tmux"'"""),
]
if boot:
    wanted.append((r"@continuum-boot", "set -g @continuum-boot 'on'"))
for key, line in wanted:
    if has(r"^\s*set(-option)?\s+-g\s+" + key + r"\b"):
        print(f"  keep your existing {key}")
    else:
        lines.append(line)

block = "\n".join([BEGIN, *lines, END]) + "\n" if lines else ""
run = re.search(r"^\s*run(-shell)?\s+['\"]?[^\n]*tpm/tpm['\"]?\s*$", text, re.M)
if block:
    if run:   # settings must come BEFORE tpm runs (e.g. @continuum-boot is read at load)
        text = text[:run.start()] + block + text[run.start():]
    else:
        text = text.rstrip("\n") + ("\n\n" if text.strip() else "") + block + "run '~/.tmux/plugins/tpm/tpm'\n"
    print("  managed block:\n    " + "\n    ".join(lines))
else:
    print("  nothing to add (already configured)")
if not dry and block:
    open(conf, "w").write(text)
PY

if [ "$BOOT" = 1 ]; then
  echo "== start tmux at boot"
  if command -v loginctl >/dev/null; then
    do_ loginctl enable-linger "$USER" || echo "could not enable lingering: run 'sudo loginctl enable-linger $USER'" >&2
  fi
  echo "continuum creates ~/.config/systemd/user/tmux.service when tmux next loads this config."
  echo "NEVER run 'systemctl --user stop tmux.service' on a live machine: its ExecStop kills every session."
fi

cat <<MSG

Next:
  1. Reload:            tmux source-file $conf     (or start a fresh tmux)
  2. Start agents with: claude-tmux / codex-tmux   (not plain claude / codex)
  3. Running sessions:  agent-adopt   (read-only list), then  agent-adopt --apply
  4. Test a restore:    see runbooks/tmux-agent-sessions.md ("Testing")
MSG
