#!/usr/bin/env bash
# Install the backup tooling (macOS): commands in ~/.local/bin + hourly launchd job.
# Safe to re-run.  ./install.sh --uninstall removes the launchd job and the links.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LABEL=local.restic-nas
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BIN="$HOME/.local/bin"

if [[ ${1:-} == --uninstall ]]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST" "$BIN/backup" "$BIN/backup-stick"
  echo "uninstalled (config.sh, repositories and logs are untouched)"; exit 0
fi

[[ $(uname -s) == Darwin ]] || { echo "macOS only"; exit 1; }
command -v restic >/dev/null || [[ -x $BIN/restic ]] || { echo "install restic first (brew install restic)"; exit 1; }
[[ -f $DIR/config.sh ]] || { cp "$DIR/config.example.sh" "$DIR/config.sh"; echo "created config.sh — edit it, then re-run"; exit 1; }
security find-generic-password -s "$(source "$DIR/config.sh"; echo "${KEYCHAIN_SERVICE:-restic-backup}")" -a "$USER" >/dev/null 2>&1 \
  || { echo "no Keychain password yet: security add-generic-password -s restic-backup -a \"\$USER\" -T /usr/bin/security -w"; exit 1; }

mkdir -p "$BIN" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
chmod +x "$DIR/backup.sh" "$DIR/backup" "$DIR/backup-stick"
ln -sf "$DIR/backup" "$BIN/backup"
ln -sf "$DIR/backup-stick" "$BIN/backup-stick"

sed -e "s|__HOME__|$HOME|g" -e "s|__DIR__|$DIR|g" "$DIR/restic-nas.plist.template" > "$PLIST"
plutil -lint "$PLIST" >/dev/null
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "installed: backup, backup-stick → $BIN; launchd job $LABEL (hourly check)"
