#!/usr/bin/env python3
"""gdlint for files this branch changes, ignoring untouched legacy lines.

Compares HEAD to merge-base with origin/$GITHUB_BASE_REF (default main).
A pull request that does not touch any .gd file prints GDLINT PASS files=0.
Problems on lines the diff did not add are ignored, so old files stay
unforced. Parse errors in a changed file still fail.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROBLEM_RE = re.compile(r"^(?P<path>.+):(?P<line>\d+): Error: (?P<msg>.*)$")
HUNK_RE = re.compile(r"^@@ -\d+(?:,\d+)? \+(?P<start>\d+)(?:,(?P<count>\d+))? @@")


def _git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=ROOT,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=False,
    )


def _fail(message: str) -> int:
    print(message, file=sys.stderr)
    print("GDLINT FAIL")
    return 1


def _added_lines(diff_text: str) -> set[int]:
    added: set[int] = set()
    new_line = 0
    in_hunk = False
    for raw in diff_text.splitlines():
        hunk = HUNK_RE.match(raw)
        if hunk:
            new_line = int(hunk.group("start"))
            in_hunk = True
            continue
        if not in_hunk or raw.startswith("\\"):
            continue
        if raw.startswith("+"):
            added.add(new_line)
            new_line += 1
        elif raw.startswith("-"):
            continue
        else:
            new_line += 1
    return added


def _changed_files(merge_base: str) -> list[str]:
    diff = _git(
        "diff",
        "--name-only",
        "--diff-filter=ACMR",
        "--find-renames",
        merge_base,
        "HEAD",
        "--",
        "*.gd",
    )
    if diff.returncode != 0:
        raise RuntimeError(diff.stderr.strip() or "git diff failed")
    return [line for line in diff.stdout.splitlines() if line.endswith(".gd")]


def main() -> int:
    if shutil.which("gdlint") is None:
        if os.environ.get("GITHUB_ACTIONS"):
            return _fail("gdlint not installed")
        print("GDLINT PASS files=0")
        print("gdlint not installed; skipped outside GitHub Actions")
        return 0

    base_ref = os.environ.get("GITHUB_BASE_REF", "").strip() or "main"
    ref = f"origin/{base_ref}"
    if _git("rev-parse", "--verify", "--quiet", ref).returncode != 0:
        if os.environ.get("GITHUB_ACTIONS"):
            return _fail(f"no {ref}")
        print("GDLINT PASS files=0")
        print(f"no {ref}; skipped outside GitHub Actions")
        return 0

    mb = _git("merge-base", ref, "HEAD")
    if mb.returncode != 0 or not mb.stdout.strip():
        return _fail(f"no merge-base with {ref}")
    merge_base = mb.stdout.strip()

    try:
        files = _changed_files(merge_base)
    except RuntimeError as exc:
        return _fail(str(exc))
    if not files:
        print("GDLINT PASS files=0")
        return 0

    added: dict[str, set[int]] = {}
    for path in files:
        show = _git("diff", "-U0", "--find-renames", merge_base, "HEAD", "--", path)
        if show.returncode != 0:
            return _fail(show.stderr.strip() or f"git diff failed for {path}")
        added[path] = _added_lines(show.stdout)

    lint = subprocess.run(
        ["gdlint", *files],
        cwd=ROOT,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=False,
    )
    output = (lint.stdout or "") + (lint.stderr or "")
    problems = [PROBLEM_RE.match(line) for line in output.splitlines()]
    matched = [item for item in problems if item]
    parse_error = "Unexpected token" in output or "DedentError" in output
    if lint.returncode != 0 and not matched:
        sys.stderr.write(output)
        return _fail(f"gdlint failed on {len(files)} file(s)")
    if parse_error:
        sys.stderr.write(output)
        return _fail("gdlint parse error")

    blocking: list[str] = []
    legacy = 0
    for item in matched:
        path = item.group("path")
        line_no = int(item.group("line"))
        if line_no in added.get(path, set()):
            blocking.append(item.group(0))
        else:
            legacy += 1
    if blocking:
        for line in blocking:
            print(f"FAIL {line}")
        return _fail(f"increases={len(blocking)}")
    print(f"GDLINT PASS files={len(files)} legacy={legacy}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
