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
