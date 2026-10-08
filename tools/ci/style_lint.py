#!/usr/bin/env python3
"""Style ratchet: #c9a227, parchment, and hardcoded #RRGGBB may only go down.

Counts are per file under project/**/*.gd. ui_kit.gd / frost.gd may hold the
Frost palette, so their #RRGGBB literals are not counted. The UIKit compatibility
alias `const PARCHMENT` in ui_kit.gd is not counted. A file missing from the
baseline must be all zeros. --update rewrites tools/ci/ratchet.json only when
every count stays the same or drops.

On a GitHub pull request the ceiling is the count of each changed file at
git merge-base origin/<base> HEAD. Other files are not compared. Local runs
and a missing base use ratchet.json.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from git_base import changed_gd, file_at, pr_merge_base

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"
RATCHET = ROOT / "tools" / "ci" / "ratchet.json"
KEYS = ("gold", "parchment", "hex")

GOLD_RE = re.compile(r"#c9a227\b", re.IGNORECASE)
PARCHMENT_RE = re.compile(r"parchment", re.IGNORECASE)
HEX_RE = re.compile(r"#[0-9A-Fa-f]{6}(?![0-9A-Fa-f])")
ALIAS_RE = re.compile(r"^\s*const\s+PARCHMENT\b")
HEX_SKIP = {
    "project/scripts/ui/ui_kit.gd",
    "project/autoload/frost.gd",
}


def _scan_text(text: str, rel: str) -> dict[str, int]:
    gold = parchment = hex_count = 0
    skip_hex = rel in HEX_SKIP
    for line in text.splitlines():
        if rel == "project/scripts/ui/ui_kit.gd" and ALIAS_RE.match(line):
            if not skip_hex:
                hex_count += len(HEX_RE.findall(line))
            gold += len(GOLD_RE.findall(line))
            continue
        gold += len(GOLD_RE.findall(line))
        parchment += len(PARCHMENT_RE.findall(line))
        if not skip_hex:
            hex_count += len(HEX_RE.findall(line))
    return {"gold": gold, "parchment": parchment, "hex": hex_count}


def _scan_file(path: Path, rel: str) -> dict[str, int]:
    return _scan_text(path.read_text(encoding="utf-8", errors="replace"), rel)


def scan() -> dict[str, dict[str, int]]:
    found: dict[str, dict[str, int]] = {}
    for path in sorted(PROJECT.rglob("*.gd")):
        rel = path.relative_to(ROOT).as_posix()
        counts = _scan_file(path, rel)
        if any(counts.values()):
            found[rel] = {key: counts[key] for key in KEYS if counts[key]}
    return found


def _load_baseline() -> dict[str, dict[str, int]]:
    if not RATCHET.is_file():
        return {}
    data = json.loads(RATCHET.read_text(encoding="utf-8"))
    style = data.get("style", {})
    if not isinstance(style, dict):
        raise SystemExit("ratchet.json style must be an object")
    return style


def _totals(files: dict[str, dict[str, int]]) -> dict[str, int]:
    totals = {key: 0 for key in KEYS}
    for counts in files.values():
        for key in KEYS:
            totals[key] += int(counts.get(key, 0))
    return totals


def _increases(current: dict[str, dict[str, int]], baseline: dict[str, dict[str, int]]) -> list[str]:
    reasons: list[str] = []
    for path in sorted(set(current) | set(baseline)):
        cur = current.get(path, {})
        base = baseline.get(path, {})
        fresh = path not in baseline
        for key in KEYS:
            c = int(cur.get(key, 0))
            b = int(base.get(key, 0))
            if c > b:
                if fresh:
                    reasons.append(f"{path} new file {key}={c} (must be 0)")
                else:
                    reasons.append(f"{path} {key} {b} -> {c}")
    return reasons


def _write(current: dict[str, dict[str, int]]) -> None:
    data: dict = {}
    if RATCHET.is_file():
        data = json.loads(RATCHET.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            data = {}
    data["style"] = current
    RATCHET.parent.mkdir(parents=True, exist_ok=True)
    RATCHET.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _pr_reasons(current: dict[str, dict[str, int]], merge_base: str) -> tuple[list[str], int] | None:
    pairs = changed_gd(merge_base, ("project/",))
    if pairs is None:
        return None
    reasons: list[str] = []
    for head_path, base_path in pairs:
        cur = current.get(head_path, {})
        if base_path is None:
            base = {}
            fresh = True
        else:
            previous = file_at(merge_base, base_path)
            base = _scan_text(previous or "", base_path)
            fresh = False
        for key in KEYS:
            c = int(cur.get(key, 0))
            b = int(base.get(key, 0))
            if c > b:
                if fresh:
                    reasons.append(f"{head_path} new file {key}={c} (must be 0)")
                else:
                    reasons.append(f"{head_path} {key} {b} -> {c}")
    return reasons, len(pairs)


def main() -> int:
    parser = argparse.ArgumentParser(description="Frost style ratchet")
    parser.add_argument("--update", action="store_true", help="tighten the baseline to current counts")
    args = parser.parse_args()
    current = scan()
    baseline = _load_baseline()
    totals = _totals(current)
    merge_base = None if args.update else pr_merge_base()
    judged = _pr_reasons(current, merge_base) if merge_base is not None else None
    if judged is not None:
        reasons, checked = judged
        if reasons:
            print(f"STYLE LINT FAIL increases={len(reasons)}")
            for reason in reasons:
                print(f"FAIL {reason}")
            return 1
        print(
            "STYLE LINT PASS pr-diff "
            f"checked={checked} files={len(current)} gold={totals['gold']} "
            f"parchment={totals['parchment']} hex={totals['hex']}"
        )
        return 0
    reasons = _increases(current, baseline)
    if args.update:
        if reasons and baseline:
            print(f"STYLE LINT FAIL --update refused ({len(reasons)} increases)")
            for reason in reasons:
                print(f"FAIL {reason}")
            return 1
        _write(current)
        print(
            "STYLE LINT PASS updated "
            f"files={len(current)} gold={totals['gold']} parchment={totals['parchment']} hex={totals['hex']}"
        )
        return 0
    if not RATCHET.is_file():
        print("STYLE LINT FAIL missing tools/ci/ratchet.json (run with --update on a clean tree)")
        return 1
    if reasons:
        print(f"STYLE LINT FAIL increases={len(reasons)}")
        for reason in reasons:
            print(f"FAIL {reason}")
        return 1
    print(
        "STYLE LINT PASS "
        f"files={len(current)} gold={totals['gold']} parchment={totals['parchment']} hex={totals['hex']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
