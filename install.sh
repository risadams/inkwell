#!/usr/bin/env bash
# Points this macOS, Linux or WSL machine at the inkwell repo. Safe to re-run.
#
#   bash install.sh           add the shim to ~/.zshrc
#   bash install.sh --tools   also install oh-my-posh, eza, fzf, zoxide, bat and
#                             the two zsh plugins (uses brew or apt, asks for sudo on apt)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/inkwell"
BEGIN='# >>> inkwell >>>'
END='# <<< inkwell <<<'
TOOLS=0
[[ "${1:-}" == "--tools" ]] && TOOLS=1

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
