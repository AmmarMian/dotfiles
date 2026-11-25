# restic backups for a Mac (NAS + USB stick)

A small CLI around [restic](https://restic.net) that backs up chosen folders of a
Mac to two independent places:

- a **NAS / server over sftp**, automatically once a day whenever it is
  reachable (e.g. when the VPN is up), via a launchd job;
- a **USB stick or external disk**, manually: plug it in, run `backup stick`.

restic does the real work (deduplication, compression, encryption, integrity
checks); these scripts only decide *when* to run, keep a retention policy, and
give short commands to see, find and restore things.

## Commands

```text
backup status               destinations, last backup, live progress
backup config [edit]        active settings and where everything is stored
backup doctor               check restic, config, password, ssh, repos, schedule
backup log [-n N] [-f]      backup log

backup now [nas|stick]      back up now (default: nas)
backup stick                back up to the stick, show the result, offer to eject

backup snapshots            list snapshots
backup find <pattern>       find files by name          [--all: every snapshot]
backup ls <folder>          a folder as it was           [--at YYYY-MM-DD]
backup restore <path>       restore a file or folder     [--at DATE] [--to DIR]

common option: --from nas|stick   (default: the NAS if reachable, else the stick)
```

`backup restore` never overwrites: files go to `~/Restored/<date>/<original path>`
(or `--to DIR`), Finder opens there, and you move back what you need.

## Files

| File | Role | In git |
|---|---|---|
| `backup` | the CLI (`~/.local/bin/backup`) | yes |
| `backup.sh` | one backup run: `backup.sh nas\|stick [--if-due]`, or `backup.sh nas -- <restic args>` | yes |
| `backup-stick` | stick backup + eject (`~/.local/bin/backup-stick`) | yes |
| `progress_filter.py` | turns `restic --json` into a progress file + log summary | yes |
| `excludes.txt` | never backed up: `node_modules`, venvs, caches, `.DS_Store`… | yes |
| `restic-nas.plist.template` | launchd job, filled in by `install.sh` | yes |
| `install.sh` | links the commands, installs the launchd job (`--uninstall` too) | yes |
| `config.example.sh` | template for your settings | yes |
| **`config.sh`** | **your hosts, paths, folders, retention** | **no (git-ignored)** |

Outside the repo: password in the macOS Keychain, log in
`~/Library/Logs/restic-backup.log`, state (last backup, progress) in
`~/.local/state/restic/`, job in `~/Library/LaunchAgents/local.restic-nas.plist`.

## Setup on a new Mac

```sh
brew install restic                                  # or the official binary in ~/.local/bin
cp config.example.sh config.sh && $EDITOR config.sh  # hosts, paths, folders

# repository password (type it; also keep it in a password manager!)
security add-generic-password -s restic-backup -a "$USER" -T /usr/bin/security -w
```

ssh access to the NAS without a terminal: an alias in `~/.ssh/config`, with the
key passphrase stored in the Keychain.

```sshconfig
Host nas
  HostName nas.example.org
  User me
  IdentityFile ~/.ssh/id_ed25519
  UseKeychain yes
  AddKeysToAgent yes
```

```sh
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
./backup.sh nas   -- init                            # create the repositories (once)
./backup.sh stick -- init
./install.sh                                         # commands + daily job
backup doctor
```

## How it behaves

- **Schedule.** launchd runs `backup.sh nas --if-due` every hour. It backs up
  only if the last *successful* NAS backup is more than 24 h old and the NAS
  answers on `NAS_CHECK`; otherwise it exits silently and tries again an hour
  later. A Mac that was asleep or off the VPN catches up at the next chance.
- **Retention.** After each backup, `restic forget` with `KEEP` (default: 14
  daily, 8 weekly, 24 monthly, 5 yearly). Snapshots tagged `keep` are never
  removed: `backup.sh nas -- tag --add keep <snapshot-id>`.
- **Maintenance.** At most weekly: `restic prune` and `restic check
  --read-data-subset=5%`. For a full check: `backup.sh nas -- check --read-data`.
- **Failures.** A failed run sends a macOS notification and is retried at the
  next hourly check. Independently, new shells print a warning when the last
  successful backup is older than `REMIND_DAYS_*` (see `zsh/macos.zsh`), so a
  job that silently stopped running does not go unnoticed.
- **Two copies, not synced.** The NAS and the stick are separate repositories
  filled from the Mac; a problem in one never touches the other.
- **Interruptions** (sleep, network loss) leave the repository consistent;
  leftover data is cleaned by the next prune.

## Disaster recovery (the Mac is gone)

```sh
brew install restic
export RESTIC_REPOSITORY=sftp:me@nas.example.org:/path/to/mac-restic   # or the stick path
restic snapshots                              # asks for the password
restic restore latest --target ~/restore-test # look first …
restic restore latest --target /              # … then put everything back in place
```

## Limits

- macOS only (Keychain, launchd, `nc -G`, `scutil`).
- The stick must be formatted with something restic can write to (APFS, exFAT…).
  exFAT has no journal: always eject before unplugging.
- Folders protected by macOS privacy settings (`~/Documents`, `~/Desktop`,
  Photos…) need Full Disk Access for the launchd job; keep backed-up folders
  outside them, or grant access to the restic binary.
