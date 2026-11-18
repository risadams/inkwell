# inkwell, zsh side.
# Sourced from ~/.zshrc (after oh-my-zsh, if you use it) by the shim install.sh adds.
# Everything here is guarded, so a missing tool never breaks shell startup.

INKWELL="${INKWELL:-${${(%):-%x}:A:h:h}}"
export INKWELL

# --- shared environment (shared/env.conf) ------------------------------------
if [[ -r "$INKWELL/shared/env.conf" ]]; then
  while IFS= read -r _ink_line || [[ -n "$_ink_line" ]]; do
    _ink_line="${_ink_line%$'\r'}"
    _ink_line="${_ink_line#"${_ink_line%%[![:space:]]*}"}"
    [[ -z "$_ink_line" || "$_ink_line" == \#* || "$_ink_line" != *=* ]] && continue
    export "${_ink_line%%=*}=${_ink_line#*=}"
  done < "$INKWELL/shared/env.conf"
fi

# Debian and Ubuntu ship bat as batcat.
(( $+commands[batcat] && ! $+commands[bat] )) && alias bat=batcat

# --- shared aliases (shared/aliases.conf) ------------------------------------
if [[ -r "$INKWELL/shared/aliases.conf" ]]; then
  while IFS= read -r _ink_line || [[ -n "$_ink_line" ]]; do
    _ink_line="${_ink_line%$'\r'}"
    _ink_line="${_ink_line#"${_ink_line%%[![:space:]]*}"}"
    [[ -z "$_ink_line" || "$_ink_line" == \#* || "$_ink_line" != *=* ]] && continue
    _ink_name="${${_ink_line%%=*}//[[:space:]]/}"
    _ink_cmd="${_ink_line#*=}"
    _ink_cmd="${_ink_cmd#"${_ink_cmd%%[![:space:]]*}"}"
    whence -- "${_ink_cmd%% *}" > /dev/null || continue
    alias -- "$_ink_name=$_ink_cmd"
  done < "$INKWELL/shared/aliases.conf"
fi
unset _ink_line _ink_name _ink_cmd

# --- history -------------------------------------------------------------------
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

# --- suggestions and highlighting (cloned by install.sh --tools) ---------------
_ink_plugins="${XDG_DATA_HOME:-$HOME/.local/share}/inkwell"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
[[ -r "$_ink_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] &&
  source "$_ink_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

# --- fzf: Ctrl+R history, Ctrl+T files ------------------------------------------
if (( $+commands[fzf] )); then
  if fzf --zsh > /dev/null 2>&1; then
    source <(fzf --zsh)
  elif [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
  fi
fi

# --- zoxide: z <part-of-a-path> ---------------------------------------------------
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# --- prompt: the same theme file PowerShell uses ----------------------------------
(( $+commands[oh-my-posh] )) &&
  eval "$(oh-my-posh init zsh --config "$INKWELL/prompt/ink.omp.json")"

# --- keeping machines in sync -------------------------------------------------------
inkcd() { cd "$INKWELL" }
inksync() {
  git -C "$INKWELL" pull --ff-only &&
    print 'Open a new shell to pick up the changes.'
}

# --- this machine only (git-ignored) ---------------------------------------------
[[ -r "$INKWELL/local.zsh" ]] && source "$INKWELL/local.zsh"

# Syntax highlighting has to load last so it sees every widget defined above.
[[ -r "$_ink_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] &&
  source "$_ink_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
unset _ink_plugins
