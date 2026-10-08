#!/usr/bin/env python3
"""Merge-base helper for ratchet checks on GitHub pull requests.

On pull_request, callers compare only files this PR changes against the
count at `git merge-base origin/<base> HEAD`. Local runs, pushes to main,
and a missing base return None so the caller keeps using ratchet.json.
"""
from __future__ import annotations

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


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


def pr_merge_base() -> str | None:
    event = os.environ.get("GITHUB_EVENT_NAME", "")
    base_ref = os.environ.get("GITHUB_BASE_REF", "").strip()
    if event != "pull_request" and not base_ref:
        return None
    if not base_ref:
        base_ref = "main"
    ref = f"origin/{base_ref}"
    if _git("rev-parse", "--verify", "--quiet", ref).returncode != 0:
        if _git("rev-parse", "--verify", "--quiet", base_ref).returncode != 0:
            print(f"RATCHET NOTE no {ref}; using ratchet.json")
            return None
        ref = base_ref
    found = _git("merge-base", ref, "HEAD")
    sha = found.stdout.strip()
    if found.returncode != 0 or not sha:
        print("RATCHET NOTE merge-base failed; using ratchet.json")
        return None
    return sha


def changed_gd(merge_base: str, prefixes: tuple[str, ...]) -> list[tuple[str, str | None]] | None:
    """Return (head path, base path) for changed *.gd files.

    base path is None when the head path is new. Renames keep the old path
    so the ceiling follows the file. Copies are new files.
    """
    diff = _git(
        "diff",
        "--name-status",
        "--find-renames",
        "--diff-filter=ACMRT",
        merge_base,
        "HEAD",
    )
    if diff.returncode != 0:
        print("RATCHET NOTE git diff failed; using ratchet.json")
        return None
    pairs: list[tuple[str, str | None]] = []
    for line in diff.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        status = parts[0]
        if status.startswith("R") and len(parts) >= 3:
            old, new = parts[1], parts[2]
            if _wanted(new, prefixes):
                pairs.append((new, old if _wanted(old, prefixes) else None))
            continue
        path = parts[-1]
        if not _wanted(path, prefixes):
            continue
        if status == "A" or status.startswith("C"):
            pairs.append((path, None))
        else:
            pairs.append((path, path))
    return pairs


def file_at(merge_base: str, path: str) -> str | None:
    show = _git("show", f"{merge_base}:{path}")
    if show.returncode != 0:
        return None
    return show.stdout


def _wanted(path: str, prefixes: tuple[str, ...]) -> bool:
    return path.endswith(".gd") and path.startswith(prefixes)
