#!/usr/bin/env python3
"""Make Godot's import cache portable across checkouts.

Godot 4.3 re-imports an asset whenever its mtime, or its .import file's mtime,
differs from the value recorded in project/.godot/editor/filesystem_cache8, even
if the bytes are unchanged. A fresh checkout gives every file a new mtime, and
every import rewrites the .import sidecars, so a restored .godot cache would
still re-import everything.

  content_mtime.py              set each tracked file under project/ to an mtime
                                derived from its git blob id
  content_mtime.py --fix-cache  also rewrite the mtimes recorded in
                                filesystem_cache8 to those same values

Unchanged content then carries the same mtime on every runner; edited content
gets a different one and re-imports. Run both after an import, before saving
the cache, and the plain form after checkout, before importing.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT_REL = "project"
CACHE = ROOT / PROJECT_REL / ".godot" / "editor" / "filesystem_cache8"
BASE = 1_000_000_000


def tracked_stamps() -> dict[str, int]:
    out = subprocess.run(
        ["git", "ls-files", "-s", "-z", "--", PROJECT_REL],
        cwd=ROOT,
        capture_output=True,
        check=True,
    ).stdout
    stamps: dict[str, int] = {}
    for entry in out.split(b"\0"):
        if not entry:
            continue
        meta, _, path = entry.partition(b"\t")
        mode, sha, _stage = meta.split(b" ")
        if mode in (b"100644", b"100755"):
            stamps[os.fsdecode(path)] = BASE + int(sha[:7], 16)
    return stamps


def apply(stamps: dict[str, int]) -> int:
    count = 0
    for rel, stamp in stamps.items():
        try:
            os.utime(ROOT / rel, (stamp, stamp))
            count += 1
        except FileNotFoundError:
            pass
    return count


def fix_cache(stamps: dict[str, int]) -> int:
    if not CACHE.is_file():
        return 0
    lines = CACHE.read_text(encoding="utf-8").split("\n")
    current = ""
    fixed = 0
    for i, line in enumerate(lines):
        if line.startswith("::res://"):
            current = line[len("::res://") :].rsplit("::", 1)[0]
            continue
        fields = line.split("::")
        if len(fields) < 6 or i == 0:
            continue
        rel = f"{PROJECT_REL}/{current}{fields[0]}"
        if rel in stamps:
            fields[3] = str(stamps[rel])
        if fields[4] != "0" and f"{rel}.import" in stamps:
            fields[4] = str(stamps[f"{rel}.import"])
        new = "::".join(fields)
        if new != line:
            lines[i] = new
            fixed += 1
    CACHE.write_text("\n".join(lines), encoding="utf-8")
    return fixed


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fix-cache", action="store_true")
    args = ap.parse_args(argv)
    stamps = tracked_stamps()
    files = apply(stamps)
    fixed = fix_cache(stamps) if args.fix_cache else 0
    print(f"CONTENT MTIME files={files} cache_entries={fixed}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
