# macOS-only settings, sourced from .zshrc. Everything is guarded so a
# missing tool never breaks the shell.

# nvm
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && . "$NVM_DIR/bash_completion"

# TeX Live (picks the newest installed year)
() {
  local tl=(/usr/local/texlive/<2000-2100>(N/On[1]))
  [[ -n $tl ]] || return
  path=("$tl/bin/universal-darwin" $path)
  export MANPATH="$MANPATH:$tl/texmf-dist/doc/man"
  export INFOPATH="$INFOPATH:$tl/texmf-dist/doc/info"
}

# Angular CLI completion
(( $+commands[ng] )) && source <(ng completion script)

# opencode
[[ -d "$HOME/.opencode/bin" ]] && path=("$HOME/.opencode/bin" $path)

# Backup reminders (state written by ~/.config/restic/backup.sh) — only where
# the backup is configured (restic/config.sh exists)
[[ -f $HOME/.config/restic/config.sh ]] && () {
  zmodload -F zsh/datetime p:EPOCHSECONDS
  local s=$HOME/.local/state/restic t days REMIND_DAYS_NAS=3 REMIND_DAYS_STICK=14
  eval "$(grep -E '^REMIND_DAYS_(NAS|STICK)=[0-9]+$' $HOME/.config/restic/config.sh)"
  local -A max=(nas $REMIND_DAYS_NAS stick $REMIND_DAYS_STICK) hint=(nas "is the NAS reachable? backup doctor" stick "plug the stick, run: backup stick")
  for t in nas stick; do
    [[ -f $s/last-$t ]] && days=$(( (EPOCHSECONDS - $(<$s/last-$t)) / 86400 )) || days=-1
    if (( days < 0 )); then print -P "%F{yellow}⚠ no $t backup yet — ${hint[$t]}%f"
    elif (( days > max[$t] )); then print -P "%F{yellow}⚠ last $t backup ${days} days ago — ${hint[$t]}%f"; fi
  done
}
