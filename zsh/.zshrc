# ~/.config/zsh/.zshrc — portable zsh config (macOS + Linux servers).
# Loaded because ~/.zshenv sets ZDOTDIR=~/.config/zsh.
# Machine-specific settings go in $ZDOTDIR/local.zsh (git-ignored).

# ── PATH ────────────────────────────────────────────────────────────────────
typeset -U path PATH                      # no duplicate entries
path=("$HOME/.local/bin" "$HOME/.atuin/bin" "$HOME/.fzf/bin" $path)

# ── oh-my-zsh ───────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
# macOS /etc/zshrc would put history in $ZDOTDIR (the git repo): keep it in $HOME
HISTFILE="$HOME/.zsh_history"
ZSH_THEME="robbyrussell"
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${HOST%%.*}"
[[ -d ${ZSH_COMPDUMP:h} ]] || mkdir -p "${ZSH_COMPDUMP:h}"
fpath=("$ZDOTDIR/completions" $fpath)

plugins=(git)
(( $+commands[fzf] )) && plugins+=(fzf-tab)
plugins+=(zsh-autosuggestions fast-syntax-highlighting)   # highlighting last

if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  print -P "%F{yellow}oh-my-zsh not found — run ~/.config/install.sh (or ~/.dotfiles/install.sh)%f"
  autoload -Uz compinit && compinit -d "$ZSH_COMPDUMP"
fi

# ── Basics ──────────────────────────────────────────────────────────────────
bindkey -v
export KEYTIMEOUT=1                        # fast <Esc> in vi mode
(( $+commands[nvim] )) && export EDITOR=nvim VISUAL=nvim

# ── Tools (each only if installed) ──────────────────────────────────────────
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
# Ctrl-R opens atuin; Up arrow keeps normal per-session history.
(( $+commands[atuin] )) && eval "$(atuin init zsh --disable-up-arrow)"

# ── Machine indicator in the prompt (see `machine help`) ───────────────────
source "$ZDOTDIR/machine-indicator.zsh"

# ── OS / machine-specific ───────────────────────────────────────────────────
[[ $OSTYPE == darwin* && -f "$ZDOTDIR/macos.zsh" ]] && source "$ZDOTDIR/macos.zsh"
[[ -f "$ZDOTDIR/local.zsh" ]] && source "$ZDOTDIR/local.zsh"
