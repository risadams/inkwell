# inkwell

One shell setup for PowerShell 7 on Windows and zsh on macOS, Linux and WSL: the same prompt, the same aliases, the same colours.

## What's here

| Path | What it does |
| --- | --- |
| `prompt/ink.omp.json` | The oh-my-posh prompt ("Ink strip"). Both shells load this one file. |
| `shared/aliases.conf` | Aliases, read by both shells. |
| `shared/env.conf` | Environment variables, read by both shells. |
| `pwsh/profile.ps1` | PowerShell: predictions, completion, fzf, zoxide, prompt. |
| `zsh/zshrc.zsh` | zsh: history, suggestions, fzf, zoxide, prompt. Loads after oh-my-zsh. |
| `terminal/schemes.json` | Ink Parchment (dark) and Ink Paper (light). The one colour source for every terminal. |
| `terminal/make-terminal-profile.js` | Turns a scheme into a macOS Terminal profile. `install.sh` runs it. |
| `terminal/wash.png` | The corner wash. `terminal/make-wash.ps1` repaints it. |
| `install.ps1`, `install.sh` | Point a machine at this repo. |

## Set up a machine

Clone the repo anywhere, then run the installer once.

Windows:

```powershell
./install.ps1 -WhatIf   # preview
./install.ps1 -Tools    # apply, and install eza, fzf, zoxide, bat, PSFzf
```

macOS, Linux, WSL:

```sh
bash install.sh --tools
```

On a Mac, `install.sh` also builds both Ink profiles for Terminal and makes Ink Parchment the default. Terminal opens a window per profile to import it. The Mac gets the colours and the font but not the corner wash, because Terminal can't pin an image to a corner.

WSL can use the Windows clone directly (`bash /mnt/<drive>/inkwell/install.sh`), so one checkout serves both sides of the same PC.

The installers only add a short shim to `$PROFILE` or `~/.zshrc` that loads the files in this repo. They back up every file they edit and are safe to re-run.

## Keep machines in sync

The repo is the only copy of the configuration. Each machine holds a pointer to it, not a copy, so syncing is a `git pull`.

1. Change something here, commit, push.
2. On every other machine, run `inksync` (a `git pull --ff-only` in this folder) and open a new shell.

One exception: terminal apps keep their own copy of the colours, so after a pull that changes `terminal/`, re-run the installer on that machine (`./install.ps1` on Windows, `bash install.sh` on a Mac).

Rules of thumb:

- Something that should be the same everywhere goes in `shared/`.
- Something for one shell goes in `pwsh/profile.ps1` or `zsh/zshrc.zsh`.
- Something for one machine goes in `local.ps1` or `local.zsh` at the repo root. Both are git-ignored and load last.

## Adding an alias

Add a line to `shared/aliases.conf`:

```
name = command and its arguments
```

Keep it to plain words (no quotes, pipes or variables) so PowerShell and zsh read it the same way. Anything fancier belongs in the shell-specific file.
