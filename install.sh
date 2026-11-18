#!/usr/bin/env bash
# Points this macOS, Linux or WSL machine at the inkwell repo. Safe to re-run.
#
#   bash install.sh           add the shim to ~/.zshrc
#   bash install.sh --tools   also install oh-my-posh, eza, fzf, zoxide, bat and
#                             the two zsh plugins (uses brew or apt, asks for sudo on apt)
#   bash install.sh --claude  also point Claude Code's status line at
#                             claude/ink.claude.omp.json (replaces the one configured in
#                             ~/.claude/settings.json; the old file is backed up)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/inkwell"
BEGIN='# >>> inkwell >>>'
END='# <<< inkwell <<<'
TOOLS=0
CLAUDE=0
for arg in "$@"; do
  case "$arg" in
    --tools) TOOLS=1 ;;
    --claude) CLAUDE=1 ;;
    *) printf 'unknown option: %s\nusage: bash install.sh [--tools] [--claude]\n' "$arg" >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
have() { command -v "$1" > /dev/null 2>&1; }

# --- tools ---------------------------------------------------------------------
if (( TOOLS )); then
  say 'Tools'
  if have brew; then
    brew install jandedobbeleer/oh-my-posh/oh-my-posh eza fzf zoxide bat
    # The prompt's segment joins need a Nerd Font; this is the same face Windows uses.
    [[ "$(uname -s)" == "Darwin" ]] && brew install --cask font-caskaydia-cove-nerd-font
  elif have apt-get; then
    sudo apt-get update
    # One at a time: older releases don't carry every package, and one miss shouldn't stop the rest.
    for pkg in zsh git curl unzip fzf zoxide bat eza; do
      sudo apt-get install -y "$pkg" || say "  skipped $pkg (not in this release's repositories)"
    done
    if ! have oh-my-posh; then
      mkdir -p "$HOME/.local/bin"
      curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
    fi
  else
    say '  no brew or apt-get here; install oh-my-posh, eza, fzf, zoxide and bat by hand'
  fi
  mkdir -p "$DATA"
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if [[ -d "$DATA/$plugin" ]]; then
      git -C "$DATA/$plugin" pull --ff-only --quiet || true
    else
      git clone --depth 1 "https://github.com/zsh-users/$plugin" "$DATA/$plugin"
    fi
  done
fi

# --- ~/.zshrc shim ---------------------------------------------------------------
say "Profile  $ZSHRC"
touch "$ZSHRC"
if grep -qF "$BEGIN" "$ZSHRC"; then
  cp "$ZSHRC" "$ZSHRC.inkwell.bak"
  # Drop the old block so a moved repo gets its new path.
  awk -v b="$BEGIN" -v e="$END" '$0==b{skip=1;next} $0==e{skip=0;next} !skip' "$ZSHRC.inkwell.bak" > "$ZSHRC"
elif [[ -s "$ZSHRC" ]]; then
  cp "$ZSHRC" "$ZSHRC.inkwell.bak"
fi
{
  # One blank line before the block, without stacking another on every re-run.
  [[ -n "$(tail -n 1 "$ZSHRC")" ]] && printf '\n'
  printf '%s\n' "$BEGIN"
  printf 'export INKWELL="%s"\n' "$ROOT"
  printf '[[ -r "$INKWELL/zsh/zshrc.zsh" ]] && source "$INKWELL/zsh/zshrc.zsh"\n'
  printf '%s\n' "$END"
} >> "$ZSHRC"
say "  wrote   shim pointing at $ROOT"

# --- Terminal.app (macOS only) -------------------------------------------------------
# Builds both Ink profiles from terminal/schemes.json and imports them. Terminal can't
# pin an image to a corner, so the Mac gets the colours and font but not the wash.
if [[ "$(uname -s)" == "Darwin" ]]; then
  say 'Terminal.app'
  mkdir -p "$DATA/terminal-app"
  imported=0
  for scheme in 'Ink Paper' 'Ink Parchment'; do
    target="$DATA/terminal-app/$scheme.terminal"
    if ! osascript -l JavaScript "$ROOT/terminal/make-terminal-profile.js" \
        "$ROOT/terminal/schemes.json" "$scheme" "$target.new"; then
      say "  failed  could not build the $scheme profile"
      continue
    fi
    if [[ -f "$target" ]] && cmp -s "$target" "$target.new"; then
      rm "$target.new"
      say "  ok      $scheme is already imported"
    else
      mv "$target.new" "$target"
      open "$target"   # Terminal imports a profile by opening it, in a new window
      imported=1
      say "  import  $scheme"
    fi
  done
  if (( imported )); then
    sleep 1
    if osascript -e 'tell application "Terminal"' \
        -e 'set default settings to settings set "Ink Parchment"' \
        -e 'set startup settings to settings set "Ink Parchment"' \
        -e 'end tell' > /dev/null 2>&1; then
      say '  set     Ink Parchment is the default profile'
    else
      say '  note    set it by hand: Terminal > Settings > Profiles > Ink Parchment > Default'
    fi
  fi
fi

# --- Claude Code status line (opt-in) --------------------------------------------------
if (( CLAUDE )); then
  settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  theme="$ROOT/claude/ink.claude.omp.json"
  say "Claude   $settings"
  # The theme needs a recent oh-my-posh, so render sample session data before changing anything.
  sample='{"cwd":"/","session_id":"inkwell-probe","model":{"id":"probe","display_name":"Probe"},"workspace":{"current_dir":"/","project_dir":"/"},"version":"0","cost":{"total_cost_usd":0,"total_duration_ms":0,"total_api_duration_ms":0,"total_lines_added":0,"total_lines_removed":0},"context_window":{"total_input_tokens":1,"total_output_tokens":1,"context_window_size":200000,"used_percentage":10,"remaining_percentage":90},"effort":{"level":"high"},"rate_limits":{"five_hour":{"used_percentage":10,"resets_at":0},"seven_day":{"used_percentage":10,"resets_at":0}}}'
  rendered=''
  if have oh-my-posh; then
    rendered="$(printf '%s' "$sample" | oh-my-posh claude --config "$theme" --plain 2> /dev/null || true)"
  fi
  if [[ "$rendered" != *Probe* || "$rendered" == *'unable to create text'* ]]; then
    say '  skipped oh-my-posh is missing or too old to render the Claude Code theme.'
    say '          Upgrade it (brew upgrade oh-my-posh, or oh-my-posh upgrade), then re-run with --claude.'
  elif ! have python3; then
    say '  skipped python3 is needed to edit the settings file. Add this to it by hand:'
    say "          \"statusLine\": {\"type\": \"command\", \"command\": \"$(command -v oh-my-posh) claude --config $theme\", \"padding\": 0}"
  else
    # Name the binary outright: the status line runs in a bare shell that may not have your PATH.
    python3 - "$settings" "\"$(command -v oh-my-posh)\" claude --config \"$theme\"" << 'PY'
import json, os, shutil, sys

path, command = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
wanted = {"type": "command", "command": command, "padding": 0}
current = data.get("statusLine")
if current == wanted:
    print("  ok      status line already set")
    sys.exit(0)
if os.path.exists(path):
    shutil.copy2(path, path + ".inkwell.bak")
os.makedirs(os.path.dirname(path), exist_ok=True)
data["statusLine"] = wanted
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
print("  wrote   " + command)
if isinstance(current, dict) and current.get("command"):
    print("          replaced: " + current["command"])
PY
  fi
fi

# --- report ------------------------------------------------------------------------
missing=()
for tool in zsh oh-my-posh eza fzf zoxide; do have "$tool" || missing+=("$tool"); done
have bat || have batcat || missing+=(bat)
[[ -d "$DATA/zsh-autosuggestions" ]] || missing+=(zsh-autosuggestions)
if (( ${#missing[@]} )); then
  say "Tools    missing: ${missing[*]}"
  say '         The profile works without them; run  bash install.sh --tools  to add them.'
fi
case "${SHELL:-}" in
  */zsh) ;;
  *) have zsh && say "Note     your login shell is ${SHELL:-unknown}; switch with:  chsh -s $(command -v zsh)" ;;
esac
say 'Done. Open a new shell to see it.'
