"""Reads `restic backup --json` on stdin. Writes the latest progress to argv[1]
(atomically) and prints a human summary + errors for the log."""
import sys, json, os, time
prog, target = sys.argv[1], sys.argv[2]
started = time.time()
def stamp(): return time.strftime("%Y-%m-%d %H:%M:%S")
for line in sys.stdin:
    try: m = json.loads(line)
    except ValueError:
        print(f"{stamp()} [{target}] {line.rstrip()}"); continue
    t = m.get("message_type")
    if t == "status":
        m["started"] = started; m["updated"] = time.time()
        tmp = prog + ".tmp"
        with open(tmp, "w") as f: json.dump(m, f)
        os.replace(tmp, prog)
    elif t == "error":
        e = m.get("error", {}); print(f"{stamp()} [{target}] error: {m.get('item','')}: {e.get('message', e)}")
    elif t == "summary":
        G = 2**30
        print(f"{stamp()} [{target}] snapshot {m.get('snapshot_id','')[:8]}: "
              f"{m.get('files_new',0)} new, {m.get('files_changed',0)} changed, {m.get('files_unmodified',0)} unchanged files; "
              f"{m.get('data_added',0)/G:.2f} GB added; {m.get('total_bytes_processed',0)/G:.1f} GB scanned "
              f"in {m.get('total_duration',0)/60:.1f} min")
