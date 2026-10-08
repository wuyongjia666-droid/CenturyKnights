#!/usr/bin/env python3
"""Estimate Godot export size from export_presets.cfg exclude filters.

Sums source bytes under project/ (not .godot, not *.import). A file is excluded
when any preset pattern matches its relative path. Godot's String.match treats
'*' as any run of characters, including slashes. Fails when the total is above
tools/ci/ratchet.json export_budget_bytes.

The 400MiB cap in the v9.2 card is not reachable while doll plates, hireuniq
faces and hub backdrops are still loaded by name. The active budget sits just
above the measured total. ART-02's docs/art/retired-assets-v92.json, when it
appears, adds more exclude globs; infra then lowers export_budget_bytes toward
250MiB.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"
PRESETS = PROJECT / "export_presets.cfg"
RATCHET = ROOT / "tools" / "ci" / "ratchet.json"
RETIRED = ROOT / "docs" / "art" / "retired-assets-v92.json"
CAP_BYTES = 400 * 1024 * 1024
TARGET_BYTES = 250 * 1024 * 1024


def _glob_to_re(pattern: str) -> re.Pattern[str]:
    out = []
    for ch in pattern:
        if ch == "*":
            out.append(".*")
        elif ch == "?":
            out.append(".")
        else:
            out.append(re.escape(ch))
    return re.compile("^" + "".join(out) + "$")


def _patterns_from_presets() -> list[str]:
    text = PRESETS.read_text(encoding="utf-8")
    found = re.findall(r'^exclude_filter="([^"]*)"', text, re.M)
    if len(found) < 2:
        raise SystemExit(f"expected 2 exclude_filter lines, found {len(found)}")
    patterns: list[str] = []
    for raw in found:
        for piece in raw.split(","):
            piece = piece.strip()
            if piece and piece not in patterns:
                patterns.append(piece)
    return patterns


def _retired_patterns() -> list[str]:
    if not RETIRED.is_file():
        return []
    data = json.loads(RETIRED.read_text(encoding="utf-8"))
    globs = data.get("exclude_globs", data if isinstance(data, list) else [])
    if not isinstance(globs, list):
        raise SystemExit("retired-assets-v92.json exclude_globs must be a list")
    return [str(item) for item in globs if str(item).strip()]


def _matches(rel: str, compiled: list[re.Pattern[str]]) -> bool:
    return any(pattern.match(rel) for pattern in compiled)


def _scan(compiled: list[re.Pattern[str]]) -> tuple[int, dict[str, int], int]:
    included = 0
    excluded = 0
    by_dir: dict[str, int] = {}
    for path in PROJECT.rglob("*"):
        if not path.is_file():
            continue
        if ".godot" in path.parts or path.suffix == ".import":
            continue
        rel = path.relative_to(PROJECT).as_posix()
        size = path.stat().st_size
        if _matches(rel, compiled):
            excluded += size
            continue
        included += size
        parts = rel.split("/")
        if parts[0] == "assets" and len(parts) >= 3:
            key = "/".join(parts[:3])
        else:
            key = parts[0]
        by_dir[key] = by_dir.get(key, 0) + size
    return included, by_dir, excluded


def main() -> int:
    patterns = _patterns_from_presets() + _retired_patterns()
    compiled = [_glob_to_re(pattern) for pattern in patterns]
    included, by_dir, excluded = _scan(compiled)
    data = json.loads(RATCHET.read_text(encoding="utf-8")) if RATCHET.is_file() else {}
    budget = int(data.get("export_budget_bytes", 0))
    print(f"EXPORT EXCLUDED {excluded}")
    for key, size in sorted(by_dir.items(), key=lambda item: (-item[1], item[0])):
        print(f"EXPORT DIR {key} {size}")
    print(f"EXPORT SIZE {included}")
    print(f"EXPORT BUDGET {budget}")
    print(f"EXPORT CAP {CAP_BYTES}")
    print(f"EXPORT TARGET {TARGET_BYTES}")
    if budget <= 0:
        print("EXPORT SIZE FAIL missing export_budget_bytes")
        return 1
    if included > budget:
        print(f"EXPORT SIZE FAIL {included} > {budget}")
        return 1
    if budget > CAP_BYTES:
        print(
            "EXPORT NOTE active budget is above the 400MiB cap; "
            "doll/hireuniq/backdrops are still referenced. Tighten after ART-02."
        )
    print("EXPORT SIZE PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
