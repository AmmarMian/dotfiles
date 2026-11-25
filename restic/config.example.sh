# Copy to config.sh (git-ignored) and adapt. Sourced by backup.sh and backup.
# Nothing in this example is a real host or path.

# --- NAS / server: restic over sftp ---------------------------------------
# Use an ~/.ssh/config alias with a key whose passphrase is in the macOS
# Keychain (UseKeychain yes), so scheduled runs work without a terminal.
NAS_SSH="nas"                                   # ssh alias
NAS_CHECK="nas.example.org:22"                  # host:port probed first (e.g. "is the VPN up?")
NAS_REPO="/srv/backups/$USER/mac-restic"        # repository path on the server

# --- USB stick / external disk ---------------------------------------------
STICK_VOLUME="/Volumes/BACKUP"
STICK_REPO="$STICK_VOLUME/restic-mac"

# --- What to back up --------------------------------------------------------
WORK_PATHS=("$HOME/Research" "$HOME/Teaching")  # → NAS and stick
STICK_EXTRA_PATHS=("$HOME/Personal")            # → stick only

# --- Retention (restic forget) ----------------------------------------------
# Snapshots tagged "keep" are never deleted:  backup.sh nas -- tag --add keep <id>
KEEP=(--keep-daily 14 --keep-weekly 8 --keep-monthly 24 --keep-yearly 5 --keep-tag keep)

KEYCHAIN_SERVICE="restic-backup"                # Keychain item holding the repo password
REMIND_DAYS_NAS=3                               # shell warning after N days without backup
REMIND_DAYS_STICK=14

# Optional, shown by `backup status`
STATUS_NOTE=""                                  # e.g. "Not here: photos (iCloud)"
MAP_FILE=""                                     # path to your own "where is what" document
