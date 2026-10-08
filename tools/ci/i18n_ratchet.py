#!/usr/bin/env python3
"""i18n ratchet: hardcoded CJK string literals may only go down.

Counts string literals that contain a CJK unified ideograph under
project/scripts and project/autoload. Literals lexically inside Locale.t(...)
or tr(...) are ignored. tests/ and data/ are not scanned. A file missing from
the baseline must be zero. --update rewrites the i18n section of
tools/ci/ratchet.json only when every count stays the same or drops.

On a GitHub pull request the ceiling is the count of each changed file at
git merge-base origin/<base> HEAD. Other files are not compared, so a later
merge on main does not fail this PR. Local runs and a missing base use
ratchet.json.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from git_base import changed_gd, file_at, pr_merge_base

ROOT = Path(__file__).resolve().parents[2]
RATCHET = ROOT / "tools" / "ci" / "ratchet.json"
SCAN_ROOTS = (ROOT / "project" / "scripts", ROOT / "project" / "autoload")
CJK_RE = re.compile(r"[\u4e00-\u9fff]")
CALL_RE = re.compile(r"Locale\s*\.\s*t\s*\(|(?<![A-Za-z0-9_.])tr\s*\(")


def _skip_string(text: str, i: int) -> int:
    if text.startswith(('"""', "'''"), i):
        quote = text[i : i + 3]
        j = i + 3
        while j < len(text):
            if text.startswith("\\", j):
                j += 2
                continue
            if text.startswith(quote, j):
                return j + 3
            j += 1
        return len(text)
    quote = text[i]
    j = i + 1
    while j < len(text):
        if text[j] == "\\":
            j += 2
            continue
        if text[j] == quote:
            return j + 1
        if text[j] == "\n":
            return j
        j += 1
    return len(text)


def _string_at(text: str, i: int) -> int:
    if text.startswith(('"""', "'''", '"', "'"), i):
        return i
    return -1


def _exempt_spans(text: str) -> list[tuple[int, int]]:
    spans: list[tuple[int, int]] = []
    i = 0
    n = len(text)
    while i < n:
        if text[i] == "#":
            nl = text.find("\n", i)
            i = n if nl < 0 else nl + 1
            continue
        start = _string_at(text, i)
        if start >= 0:
            i = _skip_string(text, start)
            continue
        match = CALL_RE.match(text, i)
        if not match:
            i += 1
            continue
        j = match.end() - 1
        depth = 0
        k = j
        while k < n:
            if text[k] == "#":
                nl = text.find("\n", k)
                k = n if nl < 0 else nl + 1
                continue
            string_at = _string_at(text, k)
            if string_at >= 0:
                k = _skip_string(text, string_at)
                continue
            if text[k] == "(":
                depth += 1
            elif text[k] == ")":
                depth -= 1
                if depth == 0:
                    k += 1
                    break
            k += 1
        spans.append((match.start(), k))
        i = k
    return spans


def _inside(spans: list[tuple[int, int]], pos: int) -> bool:
    return any(start <= pos < end for start, end in spans)


def _literals(text: str) -> list[tuple[int, str]]:
    found: list[tuple[int, str]] = []
    i = 0
    n = len(text)
    while i < n:
        if text[i] == "#":
            nl = text.find("\n", i)
            i = n if nl < 0 else nl + 1
            continue
        start = _string_at(text, i)
        if start >= 0:
            body_end = _skip_string(text, start)
            found.append((start, text[start:body_end]))
            i = body_end
            continue
        i += 1
    return found


def count_text(text: str) -> int:
    spans = _exempt_spans(text)
    total = 0
    for pos, literal in _literals(text):
        if _inside(spans, pos):
            continue
        if CJK_RE.search(literal):
            total += 1
    return total


def count_file(path: Path) -> int:
    return count_text(path.read_text(encoding="utf-8", errors="replace"))


def scan() -> dict[str, int]:
    found: dict[str, int] = {}
    for root in SCAN_ROOTS:
        if not root.is_dir():
            continue
        for path in sorted(root.rglob("*.gd")):
            count = count_file(path)
            if count:
                rel = path.relative_to(ROOT).as_posix()
                found[rel] = count
    return found


def _load() -> tuple[dict, dict[str, int]]:
    if not RATCHET.is_file():
        return {}, {}
    data = json.loads(RATCHET.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit("ratchet.json must be an object")
    i18n = data.get("i18n", {})
    if not isinstance(i18n, dict):
        raise SystemExit("ratchet.json i18n must be an object")
    return data, {str(k): int(v) for k, v in i18n.items()}


def _increases(current: dict[str, int], baseline: dict[str, int]) -> list[str]:
    reasons: list[str] = []
    for path in sorted(set(current) | set(baseline)):
        c = int(current.get(path, 0))
        b = int(baseline.get(path, 0))
        if c > b:
            if path not in baseline:
                reasons.append(f"{path} new file literals={c} (must be 0)")
            else:
                reasons.append(f"{path} literals {b} -> {c}")
    return reasons


def _pr_reasons(current: dict[str, int], merge_base: str) -> tuple[list[str], int] | None:
    pairs = changed_gd(merge_base, ("project/scripts/", "project/autoload/"))
    if pairs is None:
        return None
    reasons: list[str] = []
    for head_path, base_path in pairs:
        current_count = int(current.get(head_path, 0))
        if base_path is None:
            if current_count > 0:
                reasons.append(f"{head_path} new file literals={current_count} (must be 0)")
            continue
        previous = file_at(merge_base, base_path)
        base_count = count_text(previous or "")
        if current_count > base_count:
            reasons.append(f"{head_path} literals {base_count} -> {current_count}")
    return reasons, len(pairs)


def main() -> int:
    parser = argparse.ArgumentParser(description="CJK literal ratchet")
    parser.add_argument("--update", action="store_true", help="tighten the i18n baseline")
    args = parser.parse_args()
    current = scan()
    data, baseline = _load()
    total = sum(current.values())
    merge_base = None if args.update else pr_merge_base()
    judged = _pr_reasons(current, merge_base) if merge_base is not None else None
    if judged is not None:
        reasons, checked = judged
        if reasons:
            print(f"I18N RATCHET FAIL increases={len(reasons)}")
            for reason in reasons:
                print(f"FAIL {reason}")
            return 1
        print(f"I18N RATCHET PASS pr-diff checked={checked} files={len(current)} literals={total}")
        return 0
    reasons = _increases(current, baseline)
    if args.update:
        if reasons and baseline:
            print(f"I18N RATCHET FAIL --update refused ({len(reasons)} increases)")
            for reason in reasons:
                print(f"FAIL {reason}")
            return 1
        data["i18n"] = current
        RATCHET.parent.mkdir(parents=True, exist_ok=True)
        RATCHET.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"I18N RATCHET PASS updated files={len(current)} literals={total}")
        return 0
    if "i18n" not in data:
        print("I18N RATCHET FAIL missing i18n baseline (run with --update on a clean tree)")
        return 1
    if reasons:
        print(f"I18N RATCHET FAIL increases={len(reasons)}")
        for reason in reasons:
            print(f"FAIL {reason}")
        return 1
    print(f"I18N RATCHET PASS files={len(current)} literals={total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
