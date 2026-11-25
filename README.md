# dotfiles

zsh (oh-my-zsh, zoxide, atuin, fzf-tab), Neovim (LazyVim), git and btop config,
for a macOS laptop and Linux servers (no sudo needed).

On the Mac this repo **is** `~/.config`. On servers it is cloned to `~/.dotfiles`
and symlinked into `~/.config`.

## New Linux server

```sh
git clone https://github.com/AmmarMian/dotfiles ~/.dotfiles
~/.dotfiles/install.sh
exec zsh
machine icon 🚀 && machine name gpu-box    # optional, see below
```

`install.sh` puts everything under `$HOME`:

- links `~/.config/{nvim,zsh,git,btop}` to the repo and writes `~/.zshenv`
  (`ZDOTDIR=~/.config/zsh`); existing files are moved to `*.bak.<date>`
- clones oh-my-zsh + fzf-tab, zsh-autosuggestions, fast-syntax-highlighting
- installs zoxide, fzf, atuin, ripgrep, fd, uv and Neovim (pinned version) into
  `~/.local/bin`, `~/.fzf`, `~/.atuin`
- if your login shell isn't zsh, adds a hand-off to `~/.bashrc`
  (`NO_ZSH=1 bash` to stay in bash); `chsh -s "$(command -v zsh)"` makes it permanent
- restores Neovim plugins at the versions in `nvim/lazy-lock.json`

zsh itself must already be installed (`apt install zsh`, or
`conda install -c conda-forge zsh` without root).

Options: `--links` (no downloads), `--update` (update plugins and tools),
`NVIM_VERSION=v0.x.y`, `NO_UV=1`.

## Keeping machines in sync

- Edit and commit on the Mac (`cd ~/.config && git add -A && git commit && git push`).
  The `.gitignore` is an allow-list: a new tool's folder is ignored until you
  add `!toolname/` to it.
- On a server: `cd ~/.dotfiles && git pull && ./install.sh`

## Machine indicator

The prompt and the terminal tab title start with `<icon> <name>` in a color
taken from the hostname, so every machine looks different by default.

```
machine                 show the current indicator
machine icon 🔥         set the icon (emoji or Nerd Font glyph)
machine color 208       set the color (0-255; `machine colors` shows them)
machine name lab-gpu    set the displayed name
machine reset           back to the defaults
```

Settings are saved per machine in `~/.config/zsh/machine.zsh` (not in git).

## Per-machine files (not in git)

| File | Contents |
|---|---|
| `~/.config/zsh/local.zsh` | anything specific to one machine (PATH, conda init, aliases, secrets) |
| `~/.config/zsh/machine.zsh` | written by `machine` |
| `~/.config/git/local` | `[user] email = ...` |

macOS-only shell settings (nvm, TeX Live, Angular CLI, opencode) are in
`zsh/macos.zsh` and only load on macOS.

## Backups (macOS)

`restic/` — a small CLI (`backup status`, `backup doctor`, `backup restore …`) for
restic backups to a NAS (daily, automatic) and a USB stick (manual).
See [restic/README.md](restic/README.md). Personal settings go in the git-ignored
`restic/config.sh`.

## Notes

- atuin binds **Ctrl-R** only; the Up arrow keeps the normal per-session history.
  To import existing history: `atuin import auto`. Sync is off until you run `atuin login`.
- `nvim/lua/plugins/llm.lua` only loads where the `llm` CLI is installed.
- vimtex is pinned to v2.18 because of Neovim 0.12.3 (see `tex.lua`); when you
  bump `NVIM_VERSION` in `install.sh`, remove the pin.
