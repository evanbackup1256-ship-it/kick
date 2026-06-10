#!/usr/bin/env python3
"""Pull updated Luxy obfuscated sources from Omnie7 and Anonimusluxydev404 on GitHub.

Compares remote files with local copies (SHA-256). When content changes:
  1. Updates tools/luxy-cache obfuscated files
  2. Runs XOR deobfuscation when applicable
  3. Runs configured emit scripts to refresh production games/ files
  4. Copies plain data files (e.g. KickBlox.luau) directly into games/

Usage:
  python tools/luxy_sync.py              # check and apply updates
  python tools/luxy_sync.py --check      # dry run only
  python tools/luxy_sync.py --force      # re-download everything
  python tools/luxy_sync.py --only kick_lucky_blox speed_keyboard_escape
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = Path(__file__).with_name("luxy_sync_manifest.json")
STATE_PATH = Path(__file__).with_name(".luxy-sync-state.json")
USER_AGENT = "alleral-luxy-sync/1.0"


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def fetch_bytes(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.read()


def is_xor_obfuscated(text: str) -> bool:
    return 'v7("' in text or "v7('" in text


def run_xor_deobfuscate(src: Path, dst: Path) -> None:
    subprocess.run(
        [sys.executable, str(ROOT / "tools" / "xor_deobfuscate.py"), str(src), str(dst)],
        check=True,
        cwd=ROOT,
    )


def run_post_update(commands: list[str]) -> None:
    for command in commands:
        print(f"  -> {command}")
        subprocess.run(command, shell=True, check=True, cwd=ROOT)


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def sync_entry(
    entry: dict,
    *,
    dry_run: bool,
    force: bool,
    state: dict,
) -> str:
    entry_id = entry["id"]
    label = entry.get("label", entry_id)
    url = entry["url"]
    local_obf = ROOT / entry["local_obfuscated"]
    deob_path = entry.get("local_deobfuscated")
    local_deob = ROOT / deob_path if deob_path else None
    production = entry.get("production")
    production_path = ROOT / production if production else None
    xor = entry.get("xor_deobfuscate", False)
    post_update = entry.get("post_update", [])

    print(f"[{entry_id}] {label}")

    try:
        remote_bytes = fetch_bytes(url)
    except urllib.error.URLError as exc:
        print(f"  ! fetch failed: {exc}")
        return "error"

    remote_hash = sha256_bytes(remote_bytes)
    prior = state.get("entries", {}).get(entry_id, {})
    local_hash = None
    if local_obf.is_file():
        local_hash = sha256_bytes(local_obf.read_bytes())

    unchanged = local_hash == remote_hash and not force
    if unchanged:
        print("  = unchanged")
        return "unchanged"

    if dry_run:
        print(f"  ~ would update ({len(remote_bytes):,} bytes)")
        if production_path:
            print(f"    obfuscated: {local_obf.relative_to(ROOT)}")
            if local_deob:
                print(f"    deobfuscated: {local_deob.relative_to(ROOT)}")
            print(f"    production: {production_path.relative_to(ROOT)}")
        return "would_update"

    ensure_parent(local_obf)
    local_obf.write_bytes(remote_bytes)
    print(f"  + updated {local_obf.relative_to(ROOT)}")

    text = remote_bytes.decode("utf-8", errors="replace")
    if xor and is_xor_obfuscated(text) and local_deob:
        run_xor_deobfuscate(local_obf, local_deob)
        print(f"  + deobfuscated -> {local_deob.relative_to(ROOT)}")
    elif local_deob and not xor:
        ensure_parent(local_deob)
        local_deob.write_bytes(remote_bytes)
        print(f"  + mirrored plain -> {local_deob.relative_to(ROOT)}")

    should_copy_production = (
        production_path
        and not entry.get("production_note")
        and not xor
        and not post_update
    )
    if should_copy_production:
        ensure_parent(production_path)
        production_path.write_bytes(remote_bytes)
        print(f"  + copied production -> {production_path.relative_to(ROOT)}")

    if post_update:
        print("  * running post-update hooks")
        run_post_update(post_update)

    if entry.get("production_note"):
        print(f"  ! {entry['production_note']}")

    state.setdefault("entries", {})[entry_id] = {
        "url": url,
        "sha256": remote_hash,
        "bytes": len(remote_bytes),
        "synced_at": utc_now(),
    }
    return "updated"


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync Luxy obfuscated sources from GitHub")
    parser.add_argument("--check", action="store_true", help="Dry run — report changes only")
    parser.add_argument("--force", action="store_true", help="Re-download even when SHA-256 matches")
    parser.add_argument("--only", nargs="*", help="Limit to specific manifest entry ids")
    args = parser.parse_args()

    if not MANIFEST_PATH.is_file():
        print(f"Missing manifest: {MANIFEST_PATH}", file=sys.stderr)
        return 1

    manifest = load_json(MANIFEST_PATH)
    state = load_json(STATE_PATH) if STATE_PATH.is_file() else {"entries": {}}

    selected = {item["id"]: item for item in manifest["entries"]}
    if args.only:
        missing = [name for name in args.only if name not in selected]
        if missing:
            print(f"Unknown entry ids: {', '.join(missing)}", file=sys.stderr)
            return 1
        entries = [selected[name] for name in args.only]
    else:
        entries = manifest["entries"]

    print(f"Luxy sync — {len(entries)} entr{'y' if len(entries) == 1 else 'ies'}")
    print(f"Sources: {', '.join(manifest.get('accounts', []))}")
    if args.check:
        print("Mode: check only (no writes)")
    print()

    counts = {"updated": 0, "would_update": 0, "unchanged": 0, "error": 0}
    for entry in entries:
        result = sync_entry(entry, dry_run=args.check, force=args.force, state=state)
        counts[result] = counts.get(result, 0) + 1
        print()

    if not args.check:
        state["last_run"] = utc_now()
        save_json(STATE_PATH, state)

    print("Summary:")
    for key in ("updated", "would_update", "unchanged", "error"):
        if counts.get(key):
            print(f"  {key}: {counts[key]}")

    return 1 if counts.get("error") else 0


if __name__ == "__main__":
    raise SystemExit(main())
