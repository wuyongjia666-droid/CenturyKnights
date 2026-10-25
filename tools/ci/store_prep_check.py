#!/usr/bin/env python3
"""Store-engineering prep gate (no paid store submission).

Fails when required docs/scripts/budgets are missing or packaging dry-run fails.
Does not upload anything or spend money. Content-season novels are owned by
season knives — this gate only checks store artifacts + export wiring.
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
    "docs/store/play-listing-full.md",
    "docs/store/ms-store-listing-full.md",
    "docs/store/privacy-policy-draft.md",
    "docs/store/age-rating-draft.md",
]

REQUIRED_SCRIPTS = [
    "scripts/build_android.sh",
    "scripts/build_windows.sh",
    "tools/ci/export_size_report.py",
    "tools/ci/store_packaging_dry_check.py",
    "tools/ci/perf_budget.json",
    "tools/ci/ratchet.json",
    ".github/workflows/release.yml",
]

REQUIRED_PHRASES = {
    "docs/store/listing-copy-zh.md": ["短描述", "完整描述", "百年骑士"],
    "docs/store/export-paths.md": ["build_android.sh", "build_windows.sh", "release.yml"],
    "docs/store/crash-perf-gates.md": ["perf_budget.json", "mobile_gate"],
    "docs/store/package-budget.md": ["export_size_report.py", "export_base_budget_bytes"],
    "docs/store/play-listing-full.md": ["完整说明", "无内购", "不付费"],
    "docs/store/ms-store-listing-full.md": ["Partner Center", "买断", "不缴费"],
    "docs/store/privacy-policy-draft.md": ["不收集", "不出售", "崩溃"],
    "docs/store/age-rating-draft.md": ["12+", "内购", "暴力"],
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
        if path.stat().st_size < 600 and rel in (
            "docs/store/play-listing-full.md",
            "docs/store/ms-store-listing-full.md",
            "docs/store/privacy-policy-draft.md",
        ):
            fails.append(f"too thin {rel} ({path.stat().st_size} bytes)")
    for rel, phrases in REQUIRED_PHRASES.items():
        path = ROOT / rel
        if not path.is_file():
            continue
        body = path.read_text(encoding="utf-8")
        for phrase in phrases:
            if phrase not in body:
                fails.append(f"{rel} missing phrase {phrase!r}")

    report = ROOT / "tools/ci/export_size_report.py"
    try:
        proc = subprocess.run(
            [sys.executable, str(report)],
            cwd=str(ROOT),
            capture_output=True,
            text=True,
            timeout=120,
        )
        if proc.returncode not in (0, 1):
            fails.append(
                f"export_size_report exit {proc.returncode}: "
                f"{proc.stderr[-500:] or proc.stdout[-500:]}"
            )
    except Exception as exc:  # noqa: BLE001
        fails.append(f"export_size_report failed: {exc}")

    dry = ROOT / "tools/ci/store_packaging_dry_check.py"
    try:
        proc = subprocess.run(
            [sys.executable, str(dry)],
            cwd=str(ROOT),
            capture_output=True,
            text=True,
            timeout=60,
        )
        if proc.returncode != 0:
            fails.append(
                "store_packaging_dry_check failed:\n"
                + (proc.stdout or proc.stderr or "")[-800:]
            )
    except Exception as exc:  # noqa: BLE001
        fails.append(f"store_packaging_dry_check failed: {exc}")

    if fails:
        print("FAIL store_prep_check:")
        for line in fails:
            print(" -", line)
        return 1
    print("STORE PREP PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
