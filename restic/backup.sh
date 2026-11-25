#!/usr/bin/env bash
# restic backup of a Mac to a NAS (sftp) and/or a USB stick.  See README.md.
#
#   backup.sh nas            back up to the NAS now
#   backup.sh nas --if-due   only if the last NAS backup is >24h old and the NAS
#                            answers — what the launchd job runs every hour
#   backup.sh stick          back up to the stick (use `backup-stick`)
#   backup.sh <nas|stick> -- <restic args>   any restic command on that repository
#                            e.g. backup.sh nas -- snapshots
#
# Settings: config.sh next to this script (template: config.example.sh).
# Password: macOS Keychain. Log: ~/Library/Logs/restic-backup.log
set -uo pipefail

TARGET=${1:-}; shift || true
DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
[[ -f $DIR/config.sh ]] || { echo "Missing $DIR/config.sh — copy config.example.sh and edit it." >&2; exit 2; }
# shellcheck source=config.example.sh
source "$DIR/config.sh"

RESTIC="${RESTIC:-$HOME/.local/bin/restic}"; [[ -x $RESTIC ]] || RESTIC="$(command -v restic)"
STATE="$HOME/.local/state/restic"; mkdir -p "$STATE"
LOG="$HOME/Library/Logs/restic-backup.log"
export RESTIC_PASSWORD_COMMAND="/usr/bin/security find-generic-password -s ${KEYCHAIN_SERVICE:-restic-backup} -a $USER -w"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Folders: paths.txt ("both|nas|stick <folder>" per line; managed by `backup add/remove`),
# or the WORK_PATHS / STICK_EXTRA_PATHS arrays of config.sh if there is no paths.txt.
PATHS_FILE="${PATHS_FILE:-$DIR/paths.txt}"
paths_for() {  # paths_for nas|stick  → fills PATHS
  PATHS=()
  if [[ -f $PATHS_FILE ]]; then
    local where p
    while read -r where p; do
      [[ -z $where || $where == \#* ]] && continue
      [[ $where == both || $where == "$1" ]] && PATHS+=("${p/#\~/$HOME}")
    done < "$PATHS_FILE"
  else
    PATHS=("${WORK_PATHS[@]}"); [[ $1 == stick ]] && PATHS+=("${STICK_EXTRA_PATHS[@]}")
  fi
}
case $TARGET in
  nas)   export RESTIC_REPOSITORY="sftp:$NAS_SSH:$NAS_REPO"; paths_for nas ;;
  stick) export RESTIC_REPOSITORY="$STICK_REPO";             paths_for stick ;;
  *) sed -n '2,12p' "$0"; exit 2 ;;
esac

log()    { printf '%s [%s] %s\n' "$(date '+%F %T')" "$TARGET" "$*" | tee -a "$LOG"; }
notify() { /usr/bin/osascript -e "display notification \"$1\" with title \"Backup ($TARGET)\"" 2>/dev/null || true; }
age_h()  { local f="$STATE/$1"; [[ -f $f ]] || { echo 999999; return; }; echo $(( ($(date +%s) - $(cat "$f")) / 3600 )); }

# pass-through: backup.sh nas -- snapshots
if [[ ${1:-} == -- ]]; then shift; exec "$RESTIC" "$@"; fi

IF_DUE=0; [[ ${1:-} == --if-due ]] && IF_DUE=1
if [[ $IF_DUE == 1 ]] && (( $(age_h "last-$TARGET") < 24 )); then exit 0; fi

# Is the destination there?
if [[ $TARGET == nas ]]; then
  if ! /usr/bin/nc -z -G 5 "${NAS_CHECK%:*}" "${NAS_CHECK##*:}" >/dev/null 2>&1; then
    [[ $IF_DUE == 1 ]] && exit 0                 # e.g. VPN off: try again next hour
    log "NAS unreachable (${NAS_CHECK})"; exit 1
  fi
else
  [[ -d $STICK_REPO ]] || { log "stick not mounted ($STICK_REPO missing)"; exit 1; }
fi

existing=(); for p in "${PATHS[@]}"; do [[ -e $p ]] && existing+=("$p"); done

log "backup start: ${existing[*]/#$HOME/~}"
# --json: progress goes to $STATE/progress-$TARGET.json (shown by `backup status`),
# the summary and errors go to the log.
PROG="$STATE/progress-$TARGET.json"
RESTIC_PROGRESS_FPS=0.1 "$RESTIC" backup --json --exclude-file "$DIR/excludes.txt" --exclude-caches \
  --tag auto --host "$(scutil --get LocalHostName)" "${existing[@]}" 2>>"$LOG" \
  | /usr/bin/python3 -I -u "$DIR/progress_filter.py" "$PROG" "$TARGET" >>"$LOG"
rc=${PIPESTATUS[0]}
rm -f "$PROG"
if [[ $rc != 0 ]]; then
  # exit 3 = snapshot saved but some files could not be read
  if [[ $rc == 3 ]]; then log "backup saved, but some files could not be read (see log)"; notify "Saved with warnings — see the log"
  else log "BACKUP FAILED (exit $rc)"; notify "FAILED (exit $rc) — see ~/Library/Logs/restic-backup.log"; exit $rc; fi
fi
date +%s > "$STATE/last-$TARGET"
log "backup done"

# Retention every run (cheap); prune + partial integrity check at most weekly.
"$RESTIC" forget --group-by host "${KEEP[@]}" >>"$LOG" 2>&1 || log "forget failed (non-fatal)"
if (( $(age_h "maint-$TARGET") >= 24*7 )); then
  log "weekly maintenance: prune + check 5% of data"
  if "$RESTIC" prune >>"$LOG" 2>&1 && "$RESTIC" check --read-data-subset=5% >>"$LOG" 2>&1; then
    date +%s > "$STATE/maint-$TARGET"; log "maintenance OK"
  else
    log "MAINTENANCE PROBLEM — run: backup.sh $TARGET -- check"; notify "Check reported a problem — see the log"
  fi
fi
exit 0
