#!/usr/bin/env python3
"""Store-engineering prep gate (no paid store submission).

Fails when required docs/scripts/budgets are missing or export_size_report
cannot import. Does not upload anything or spend money.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_DOCS = [
    "docs/store/README.md",
    "docs/store/export-paths.md",
    "docs/store/listing-copy-zh.md",
    "docs/store/crash-perf-gates.md",
    "docs/store/package-budget.md",
    "docs/store/CHECKLIST.md",
]

REQUIRED_SCRIPTS = [
    "scripts/build_android.sh",
    "scripts/build_windows.sh",
    "tools/ci/export_size_report.py",
    "tools/ci/perf_budget.json",
    "tools/ci/ratchet.json",
    ".github/workflows/release.yml",
]

REQUIRED_PHRASES = {
    "docs/store/listing-copy-zh.md": ["短描述", "完整描述", "百年骑士"],
    "docs/store/export-paths.md": ["build_android.sh", "build_windows.sh", "release.yml"],
    "docs/store/crash-perf-gates.md": ["perf_budget.json", "mobile_gate"],
    "docs/store/package-budget.md": ["export_size_report.py", "export_base_budget_bytes"],
}


def main() -> int:
    fails: list[str] = []
    for rel in REQUIRED_DOCS + REQUIRED_SCRIPTS:
        path = ROOT / rel
        if not path.is_file():
            fails.append(f"missing {rel}")
            continue
        if path.stat().st_size < 200 and rel.startswith("docs/store/"):
            fails.append(f"too thin {rel} ({path.stat().st_size} bytes)")
    for rel, phrases in REQUIRED_PHRASES.items():
        path = ROOT / rel
        if not path.is_file():
            continue
        body = path.read_text(encoding="utf-8")
        for phrase in phrases:
            if phrase not in body:
                fails.append(f"{rel} missing phrase {phrase!r}")
    # export_size_report must at least parse presets (may fail budget on huge trees;
    # we still require the script to start and find presets).
    report = ROOT / "tools/ci/export_size_report.py"
    try:
        # Dry: import-level check by running with a quick syntax/load — full report OK.
        proc = subprocess.run(
            [sys.executable, str(report)],
            cwd=str(ROOT),
            capture_output=True,
            text=True,
            timeout=120,
        )
        # Exit 0 = under budget; exit 1 = over budget but script works; other = broken.
        if proc.returncode not in (0, 1):
            fails.append(
                f"export_size_report exit {proc.returncode}: {proc.stderr[-500:] or proc.stdout[-500:]}"
            )
    except Exception as exc:  # noqa: BLE001
        fails.append(f"export_size_report failed: {exc}")

    # Season 02/03 scaffold presence (store track owns multi-season index).
    idx = ROOT / "project/data/content_seasons/index.json"
    if idx.is_file():
        import json

        data = json.loads(idx.read_text(encoding="utf-8"))
        seasons = data.get("seasons", [])
        for sid in ("season_02", "season_03"):
            if sid not in seasons:
                fails.append(f"index.json missing {sid}")
            sp = ROOT / f"project/data/content_seasons/{sid}.json"
            if not sp.is_file():
                fails.append(f"missing {sp.relative_to(ROOT)}")
            novel = ROOT / f"docs/content-seasons/{sid.replace('_', '-')}/NOVEL.md"
            if not novel.is_file():
                fails.append(f"missing {novel.relative_to(ROOT)}")
            elif novel.stat().st_size < 1500:
                fails.append(f"NOVEL too thin {novel.relative_to(ROOT)} ({novel.stat().st_size} bytes)")
    else:
        fails.append("missing content_seasons/index.json")

    if fails:
        print("FAIL store_prep_check:")
        for line in fails:
            print(" -", line)
        return 1
    print("STORE PREP PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
