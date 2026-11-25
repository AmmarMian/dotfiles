# Machine indicator: puts "<icon> <name>" in front of the prompt and in the
# terminal tab title, so you always know which machine a shell is on.
#
# Defaults: icon from the OS, color derived from the hostname (so every server
# gets its own color automatically), name = short hostname.
# Overrides are stored per machine in $ZDOTDIR/machine.zsh (git-ignored).
# Run `machine help` for usage.

_MACHINE_FILE="$ZDOTDIR/machine.zsh"

_machine_defaults() {
  case $OSTYPE in
    darwin*) MACHINE_ICON="💻" ;;
    linux*)  MACHINE_ICON="🐧" ;;
    *)       MACHINE_ICON="🖥️" ;;
  esac
  # macOS $HOST follows the network (DHCP name); LocalHostName is stable.
  local host=${HOST%%.*}
  [[ $OSTYPE == darwin* ]] && host=$(scutil --get LocalHostName 2>/dev/null || print -r -- $host)
  # Stable color from the hostname, picked from a palette of readable colors.
  local -a palette=(39 45 49 82 112 141 171 178 202 208 214 220)
  local sum=0 c
  for c in ${(s::)host}; do (( sum += #c )); done
  MACHINE_COLOR=${palette[$(( sum % ${#palette} + 1 ))]}
  MACHINE_NAME=$host
}

_machine_render() {
  local name=${MACHINE_NAME//\%/%%} icon=${MACHINE_ICON//\%/%%} picon
  # Emoji with variation selector U+FE0F (⛩️ 🗄️ ☁️ ...) are drawn 2 columns
  # wide but zsh counts them as 1: declare the width so the cursor stays put.
  if [[ $icon == *$'️'* ]]; then picon="%{${icon}%2G%}"; else picon=$icon; fi
  _machine_seg="%B%F{$MACHINE_COLOR}${picon}${icon:+ }${name}%f%b "
  # oh-my-zsh tab/window title (lib/termsupport.zsh)
  ZSH_THEME_TERM_TAB_TITLE_IDLE="${icon}${icon:+ }${name}: %15<..<%~%<<"
  ZSH_THEME_TERM_TITLE_IDLE="${icon}${icon:+ }${name}: %~"
}

_machine_save() {
  {
    print -r -- "# Written by the \`machine\` command — per-machine, not in git."
    print -r -- "MACHINE_ICON=${(qq)MACHINE_ICON}"
    print -r -- "MACHINE_COLOR=${(qq)MACHINE_COLOR}"
    print -r -- "MACHINE_NAME=${(qq)MACHINE_NAME}"
  } >| "$_MACHINE_FILE"
}

machine() {
  case $1 in
    icon)  shift; MACHINE_ICON="$*" ;;        # `machine icon` alone = no icon
    color)
      [[ -n $2 ]] || { print "usage: machine color <0-255|red|green|...>"; return 1 }
      MACHINE_COLOR=$2 ;;
    name)  shift; MACHINE_NAME="$*" ;;
    reset) rm -f "$_MACHINE_FILE"; _machine_defaults; _machine_render
           print "Machine indicator reset to defaults."; return ;;
    colors)
      local i
      for i in {0..255}; do
        print -nP "%F{$i}${(l:3::0:)i}%f "
        (( (i + 1) % 16 == 0 )) && print
      done
      return ;;
    ""|show)
      print -P "Current: ${_machine_seg}%f  (icon='$MACHINE_ICON' color=$MACHINE_COLOR name='$MACHINE_NAME')"
      [[ -f $_MACHINE_FILE ]] && print "Saved in $_MACHINE_FILE" || print "Using defaults"
      return ;;
    help|-h|--help|*)
      cat <<'EOF'
machine                 show the current indicator
machine icon 🚀         set the icon (emoji or Nerd Font glyph; empty = none)
machine color 208       set the color (0-255, or red/green/blue/...)
machine name gpu-box    set the displayed name (default: short hostname)
machine colors          print the 256-color palette
machine reset           go back to the defaults
EOF
      [[ $1 == (help|-h|--help) ]]; return ;;
  esac
  _machine_save
  _machine_render
}

_machine_defaults
[[ -f $_MACHINE_FILE ]] && source "$_MACHINE_FILE"
_machine_render

# Prepend the segment once; it updates live because prompt_subst is on.
setopt prompt_subst
[[ $PROMPT == *'${_machine_seg}'* ]] || PROMPT='${_machine_seg}'"$PROMPT"
