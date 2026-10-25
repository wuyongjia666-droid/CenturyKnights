#!/usr/bin/env python3
"""Store verification-record gate (privacy / age / export / data-safety / support). Does not touch novel floors."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

RECORDS = {
    "docs/store/privacy-verification-record.md": {
        "min_bytes": 1600,
        "phrases": ["不收集", "不出售", "验证记录", "崩溃"],
    },
    "docs/store/age-rating-verification-record.md": {
        "min_bytes": 1400,
        "phrases": ["12+", "内购", "暴力", "验证记录"],
    },
    "docs/store/export-paths-verification-record.md": {
        "min_bytes": 1600,
        "phrases": ["build_android.sh", "build_windows.sh", "release.yml", "验证记录"],
    },
    "docs/store/data-safety-verification-record.md": {
        "min_bytes": 1600,
        "phrases": ["不收集", "数据安全", "不出售", "验证记录"],
    },
    "docs/store/support-contact-verification-record.md": {
        "min_bytes": 1600,
        "phrases": ["支持", "联系", "不付费", "验证记录"],
    },
}


def main() -> int:
    fails: list[str] = []
    for rel, spec in RECORDS.items():
        path = ROOT / rel
        if not path.is_file():
            fails.append(f"missing {rel}")
            continue
        size = path.stat().st_size
        if size < spec["min_bytes"]:
            fails.append(f"too thin {rel} ({size} < {spec['min_bytes']})")
        body = path.read_text(encoding="utf-8")
        for phrase in spec["phrases"]:
            if phrase not in body:
                fails.append(f"{rel} missing phrase {phrase!r}")
    if fails:
        print("FAIL store_verify_records_check:")
        for line in fails:
            print(" -", line)
        return 1
    print("STORE VERIFY RECORDS PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
