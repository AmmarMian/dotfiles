"""Helpers for `backup search` / `backup versions` (stdin = restic JSON).

  versions.py list   <out.tsv>   < restic ls --json   → TSV: ~path, path, size, mtime (files only)
  versions.py versions <path> <snapshots.json> [--tsv] < restic find --json --long <path>
      distinct versions of <path> (same mtime+size = same version), newest first;
      --tsv: snapshot-to-restore-from, label   (for fzf)
"""
import sys, json, os

def human(n):
    for u in ("B", "KB", "MB", "GB"):
        if n < 1024 or u == "GB": return f"{n:.0f} {u}" if u == "B" else f"{n:.1f} {u}"
        n /= 1024

def cmd_list(out):
    home = os.path.expanduser("~")
    tmp = out + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        for line in sys.stdin:
            try: n = json.loads(line)
            except ValueError: continue
            if n.get("type") != "file": continue
            p = n["path"]
            disp = "~" + p[len(home):] if p.startswith(home + "/") else p
            f.write(f"{disp}\t{p}\t{human(n.get('size', 0))}\t{n.get('mtime', '')[:16].replace('T', ' ')}\n")
    os.replace(tmp, out)

def cmd_versions(path, snaps_file, tsv):
    snaps = {s["id"]: s for s in json.load(open(snaps_file))}
    try: found = json.load(sys.stdin) or []
    except ValueError: found = []
    groups = {}
    for hit in found:
        s = snaps.get(hit.get("snapshot"))
        if not s: continue
        for m in hit.get("matches", []):
            if m.get("path") != path or m.get("type", "file") != "file": continue
            key = (m.get("mtime", "")[:19], m.get("size", 0))
            groups.setdefault(key, []).append(s)
    if not groups:
        print("no version of this file in the backups", file=sys.stderr); sys.exit(1)
    rows = sorted(groups.items(), key=lambda kv: kv[0][0], reverse=True)
    for i, ((mtime, size), ss) in enumerate(rows, 1):
        ss.sort(key=lambda s: s["time"])
        first, last = ss[0]["time"][:10], ss[-1]["time"][:10]
        span = first if first == last else f"{first} → {last}"
        label = (f"{'latest ' if i == 1 else 'v-' + str(i - 1):<8} modified {mtime.replace('T', ' ')[:16]}  "
                 f"{human(size):>9}  in {len(ss)} snapshot{'s' if len(ss) > 1 else ''} ({span})")
        print(f"{ss[-1]['short_id']}\t{label}" if tsv else label)

if __name__ == "__main__":
    if sys.argv[1] == "list": cmd_list(sys.argv[2])
    else: cmd_versions(sys.argv[2], sys.argv[3], "--tsv" in sys.argv)
