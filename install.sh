#!/usr/bin/env bash
# Dotfiles installer: macOS laptop + Linux servers (no sudo needed).
# Safe to re-run: existing files are backed up, installed tools are skipped.
#
#   ./install.sh            links + tools
#   ./install.sh --links    links only (no downloads)
#   ./install.sh --update   also update oh-my-zsh plugins and re-fetch tools
#
# Env: NVIM_VERSION (default below), NO_UV=1 to skip uv.
set -euo pipefail

NVIM_VERSION="${NVIM_VERSION:-v0.12.3}"   # vimtex pin in nvim/lua/plugins/tex.lua depends on it

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN="$HOME/.local/bin"
ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM_DIR="$ZSH_DIR/custom"
STAMP="$(date +%Y%m%d-%H%M%S)"

LINKS_ONLY=0 UPDATE=0
for a in "$@"; do
  case $a in
    --links)  LINKS_ONLY=1 ;;
    --update) UPDATE=1 ;;
    -h|--help) sed -n 2,10p "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 1 ;;
  esac
done

OS="$(uname -s)"; ARCH="$(uname -m)"
case $ARCH in arm64) ARCH=aarch64 ;; amd64) ARCH=x86_64 ;; esac

c_blue=$'\e[34m' c_yel=$'\e[33m' c_grn=$'\e[32m' c_off=$'\e[0m'
step() { printf '%s==>%s %s\n' "$c_blue" "$c_off" "$*"; }
ok()   { printf '    %s✓%s %s\n' "$c_grn" "$c_off" "$*"; }
warn() { printf '    %s!%s %s\n' "$c_yel" "$c_off" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

mkdir -p "$BIN" "$CONFIG" "$HOME/.cache/zsh"
export PATH="$BIN:$HOME/.fzf/bin:$HOME/.atuin/bin:$PATH"

# Move a real file/dir out of the way before we replace it.
backup() { if [[ -e $1 || -L $1 ]]; then mv "$1" "$1.bak.$STAMP"; warn "backed up $1 -> $1.bak.$STAMP"; fi; }

link() {  # link <src> <dst>
  local src=$1 dst=$2
  if [[ -L $dst && "$(readlink "$dst")" == "$src" ]]; then ok "$dst"; return; fi
  backup "$dst"
  ln -s "$src" "$dst"; ok "$dst -> $src"
}

write_file() {  # write_file <path> <content>  (backs up if different)
  local dst=$1 content=$2
  if [[ -f $dst && ! -L $dst && "$(cat "$dst")" == "$content" ]]; then ok "$dst"; return; fi
  backup "$dst"
  printf '%s\n' "$content" > "$dst"; ok "wrote $dst"
}

# ── 1. Links ────────────────────────────────────────────────────────────────
step "Linking config"
if [[ "$(cd "$CONFIG" && pwd -P)" == "$DOTFILES" ]]; then
  ok "repo is $CONFIG itself, nothing to link"
else
  for d in nvim zsh git btop ipython-profile; do link "$DOTFILES/$d" "$CONFIG/$d"; done
fi

# IPython reads its config from ~/.ipython, not ~/.config: link the one file.
# (The folder is not named "ipython": IPython warns about a legacy ~/.config/ipython.)
mkdir -p "$HOME/.ipython/profile_default"
link "$CONFIG/ipython-profile/ipython_config.py" "$HOME/.ipython/profile_default/ipython_config.py"

write_file "$HOME/.zshenv" '# Managed by dotfiles/install.sh — real config is in ~/.config/zsh
export ZDOTDIR="$HOME/.config/zsh"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"'

# With ZDOTDIR set, ~/.zshrc is never read: move it away so it doesn't confuse.
if [[ -f $HOME/.zshrc && ! -L $HOME/.zshrc ]]; then backup "$HOME/.zshrc"; fi

# git: per-machine email
if [[ ! -f $CONFIG/git/local ]]; then
  email="$(git config --file "$HOME/.gitconfig" user.email 2>/dev/null || true)"
  if [[ -n $email ]]; then
    printf '[user]\n\temail = %s\n' "$email" > "$CONFIG/git/local"; ok "git email from ~/.gitconfig"
  else
    warn "set your git email: git config --file ~/.config/git/local user.email you@example.com"
  fi
fi

[[ $LINKS_ONLY == 1 ]] && { step "Done (links only)"; exit 0; }

# ── 2. oh-my-zsh + plugins ──────────────────────────────────────────────────
have git  || { echo "git is required" >&2; exit 1; }
have curl || { echo "curl is required" >&2; exit 1; }

clone() {  # clone <url> <dir>
  if [[ -d $2/.git ]]; then
    if [[ $UPDATE == 1 ]]; then git -C "$2" pull -q --ff-only && ok "updated $(basename "$2")"; else ok "$(basename "$2")"; fi
  else
    git clone -q --depth 1 "$1" "$2" && ok "cloned $(basename "$2")"
  fi
}

step "oh-my-zsh"
clone https://github.com/ohmyzsh/ohmyzsh.git "$ZSH_DIR"
clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM_DIR/plugins/fzf-tab"
clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
clone https://github.com/zdharma-continuum/fast-syntax-highlighting "$ZSH_CUSTOM_DIR/plugins/fast-syntax-highlighting"

# ── 3. CLI tools ────────────────────────────────────────────────────────────
need() { [[ $UPDATE == 1 ]] || ! have "$1"; }

# Download the newest Linux release asset of a GitHub repo, extract one binary.
gh_release_bin() {  # gh_release_bin <owner/repo> <binary>
  local repo=$1 bin=$2 url tmp
  url="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
    | grep -o '"browser_download_url": *"[^"]*'"$ARCH"'-unknown-linux-\(musl\|gnu\)\.tar\.gz"' \
    | sed 's/.*"\(http[^"]*\)"/\1/' | sort -r | head -1)"   # musl sorts before gnu with -r
  [[ -n $url ]] || { warn "no $ARCH Linux build found for $repo"; return 1; }
  tmp="$(mktemp -d)"
  curl -fsSL "$url" | tar -xz -C "$tmp"
  find "$tmp" -type f -name "$bin" -perm -u+x -exec mv {} "$BIN/$bin" \;
  rm -rf "$tmp"
  ok "$bin -> $BIN/$bin"
}

step "CLI tools ($OS $ARCH)"
if [[ $OS == Darwin ]]; then
  if have brew; then
    for pair in zoxide:zoxide fzf:fzf atuin:atuin rg:ripgrep fd:fd nvim:neovim; do
      cmd=${pair%%:*} pkg=${pair#*:}
      if have "$cmd"; then ok "$cmd"; else HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew install -q "$pkg" && ok "$cmd (brew)"; fi
    done
  else
    warn "Homebrew not found, skipping tool installs"
  fi
else
  if need zoxide; then
    curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh \
      | sh -s -- --bin-dir "$BIN" >/dev/null && ok "zoxide"
  else ok "zoxide"; fi

  if [[ ! -d $HOME/.fzf ]] || [[ $UPDATE == 1 ]]; then
    clone https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --bin >/dev/null 2>&1 && ok "fzf"
  else ok "fzf"; fi

  if need atuin; then
    curl --proto '=https' --tlsv1.2 -fsSL \
      https://github.com/atuinsh/atuin/releases/latest/download/atuin-installer.sh \
      | ATUIN_NO_MODIFY_PATH=1 sh -s -- --quiet && ok "atuin"
  else ok "atuin"; fi

  if need rg; then gh_release_bin BurntSushi/ripgrep rg || true; else ok "rg"; fi
  if need fd; then gh_release_bin sharkdp/fd fd || true; else ok "fd"; fi

  # Neovim: pinned version from the official tarball
  if [[ "$(nvim --version 2>/dev/null | head -1)" != "NVIM $NVIM_VERSION" ]]; then
    case $ARCH in x86_64) nv=nvim-linux-x86_64 ;; aarch64) nv=nvim-linux-arm64 ;; *) nv= ;; esac
    if [[ -n $nv ]]; then
      dest="$HOME/.local/opt/nvim-$NVIM_VERSION"
      rm -rf "$dest"; mkdir -p "$dest"
      curl -fsSL "https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/$nv.tar.gz" \
        | tar -xz -C "$dest" --strip-components=1
      ln -sf "$dest/bin/nvim" "$BIN/nvim"; ok "nvim $NVIM_VERSION"
    else warn "no nvim build for $ARCH"; fi
  else ok "nvim $NVIM_VERSION"; fi

  if [[ ${NO_UV:-0} != 1 ]] && need uv; then
    curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh >/dev/null 2>&1 && ok "uv"
  elif have uv; then ok "uv"; fi
fi

# ── 4. Default shell ────────────────────────────────────────────────────────
step "Default shell"
if ! have zsh; then
  warn "zsh is not installed. Ask an admin (apt install zsh), or use conda: conda install -c conda-forge zsh"
elif [[ "$(basename "${SHELL:-}")" == zsh ]]; then
  ok "login shell is already zsh"
else
  marker='# >>> dotfiles: switch to zsh >>>'
  if ! grep -qF "$marker" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" <<EOF

$marker
# Interactive bash hands over to zsh (set NO_ZSH=1 to stay in bash).
if [[ \$- == *i* ]] && [ -z "\${BASH_EXECUTION_STRING:-}" ] && [ -z "\${NO_ZSH:-}" ] && command -v zsh >/dev/null 2>&1; then exec zsh -l; fi
# <<< dotfiles: switch to zsh <<<
EOF
    ok "added zsh hand-off to ~/.bashrc"
  else ok "~/.bashrc already hands off to zsh"; fi
  warn "if allowed, make it permanent with: chsh -s \"\$(command -v zsh)\""
fi

# ── 5. Neovim plugins ───────────────────────────────────────────────────────
step "Neovim plugins (lazy-lock.json)"
if have nvim; then
  nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 && ok "plugins restored" \
    || warn "plugin restore had errors — open nvim and run :Lazy"
else warn "nvim not found"; fi

step "Done. Start a new shell (exec zsh), then try: machine help"
