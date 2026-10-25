#!/usr/bin/env python3
"""Store-engineering prep gate (no paid store submission).

Fails when required docs/scripts/budgets are missing, listing drafts are thin,
season 02/03/04 novels fall below mid-length (≥12000 汉字 / 对标季1), or packaging
dry-run fails. Does not upload anything or spend money. Do not weaken the novel floor.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

MIN_NOVEL_HANZI = 12000  # 中篇级，对标季1；禁止削弱
MIN_LISTING_BYTES = {
    "docs/store/play-listing-full.md": 4500,
    "docs/store/ms-store-listing-full.md": 3500,
    "docs/store/listing-copy-zh.md": 2800,
    "docs/store/privacy-policy-draft.md": 2800,
    "docs/store/age-rating-draft.md": 1600,
    "docs/store/screenshots-checklist.md": 1400,
    "docs/store/data-safety-draft.md": 1400,
    "docs/store/support-contact-draft.md": 1200,
    "docs/store/listing-copy-en.md": 1400,
}


def _hanzi_count(s: str) -> int:
    return sum(1 for c in s if 0x4E00 <= ord(c) <= 0x9FFF)


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
    "docs/store/screenshots-checklist.md",
    "docs/store/data-safety-draft.md",
    "docs/store/support-contact-draft.md",
    "docs/store/listing-copy-en.md",
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
    "docs/store/screenshots-checklist.md": ["1080", "横屏", "五张", "不付费"],
    "docs/store/data-safety-draft.md": ["不收集", "数据安全", "崩溃", "不出售"],
    "docs/store/support-contact-draft.md": ["支持", "联系", "不付费", "单机"],
    "docs/store/listing-copy-en.md": ["Short description", "Full description", "Century Knights", "no IAP"],
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
        floor = MIN_LISTING_BYTES.get(rel)
        if floor is not None and path.stat().st_size < floor:
            fails.append(f"too thin {rel} ({path.stat().st_size} bytes < {floor})")
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

    # Season 02..06 scaffold presence (store track owns multi-season index).
    idx = ROOT / "project/data/content_seasons/index.json"
    if idx.is_file():
        import json

        data = json.loads(idx.read_text(encoding="utf-8"))
        seasons = data.get("seasons", [])
        for sid in ("season_02", "season_03", "season_04", "season_05", "season_06"):
            if sid not in seasons:
                fails.append(f"index.json missing {sid}")
            sp = ROOT / f"project/data/content_seasons/{sid}.json"
            if not sp.is_file():
                fails.append(f"missing {sp.relative_to(ROOT)}")
                continue
            novel = ROOT / f"docs/content-seasons/{sid.replace('_', '-')}/NOVEL.md"
            if not novel.is_file():
                fails.append(f"missing {novel.relative_to(ROOT)}")
                continue
            body = novel.read_text(encoding="utf-8")
            hz = _hanzi_count(body)
            # 中篇硬闸：季#2..#6 一律 ≥ MIN_NOVEL_HANZI；禁止按 playable 推迟/削弱
            if hz < MIN_NOVEL_HANZI:
                fails.append(
                    f"NOVEL too thin {novel.relative_to(ROOT)} "
                    f"({hz} hanzi < {MIN_NOVEL_HANZI}; 对标季1中篇)"
                )
    else:
        fails.append("missing content_seasons/index.json")

    # Nested packaging dry-run (scripts/presets/workflows/listing full drafts).
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
