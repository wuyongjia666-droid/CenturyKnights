#!/usr/bin/env python3
"""Estimate Godot export size from export_presets.cfg exclude filters.

Reports Windows and Android separately (their exclude_filter lines differ).
Sums source bytes under project/ (not .godot, not *.import). A file is excluded
when any pattern for that platform matches its relative path. Godot's String.match
treats '*' as any run of characters, including slashes.

Fails when either platform total is above tools/ci/ratchet.json export_budget_bytes
(derived: export_base_budget_bytes + plates * export_bank_bytes_per_plate).

Also fails when Android ships genome bank master or small tiers (medium-only contract).

The hard CAP (400 MiB) is reported as EXPORT CAP_STATUS; Android OVER is advisory
until user-approved levers in docs/art/export-cap-400.md land. Android is the
packing target. Shipping photographs are WebP quality 92. The gene-portrait bank
ships large+medium+small on Windows; Android packs medium only.
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
BANK_PREFIX = "assets/art/portraits/genome/bank/"
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


def _preset_filters() -> dict[str, list[str]]:
    text = PRESETS.read_text(encoding="utf-8")
    # Split on preset headers so each exclude_filter stays with its platform.
    blocks = re.split(r"(?=^\[preset\.\d+\]\s*$)", text, flags=re.M)
    out: dict[str, list[str]] = {}
    for block in blocks:
        m_plat = re.search(r'^platform="([^"]*)"', block, re.M)
        m_ex = re.search(r'^exclude_filter="([^"]*)"', block, re.M)
        if not m_plat or not m_ex:
            continue
        patterns = [p.strip() for p in m_ex.group(1).split(",") if p.strip()]
        out[m_plat.group(1)] = patterns
    if "Windows Desktop" not in out or "Android" not in out:
        raise SystemExit(f"expected Windows Desktop + Android presets, found {sorted(out)}")
    return out


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


def _scan(compiled: list[re.Pattern[str]]) -> tuple[int, dict[str, int], int, dict[str, int], dict[str, int]]:
    included = 0
    excluded = 0
    by_dir: dict[str, int] = {}
    plates: dict[str, int] = {}
    bank_tiers: dict[str, int] = {"master": 0, "medium": 0, "small": 0, "other": 0}
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
        if rel.startswith(BANK_PREFIX):
            name = Path(rel).name
            stem = name.split(".", 1)[0]
            plates[stem] = plates.get(stem, 0) + size
            if ".medium." in name:
                bank_tiers["medium"] += size
            elif ".small." in name:
                bank_tiers["small"] += size
            elif re.search(r"_[0-9a-f]{16}\.webp$", name):
                bank_tiers["master"] += size
            else:
                bank_tiers["other"] += size
        parts = rel.split("/")
        if parts[0] == "assets" and len(parts) >= 3:
            key = "/".join(parts[:3])
        else:
            key = parts[0]
        by_dir[key] = by_dir.get(key, 0) + size
    return included, by_dir, excluded, plates, bank_tiers


def _report_platform(label: str, patterns: list[str], retired: list[str], data: dict) -> int:
    compiled = [_glob_to_re(p) for p in patterns + retired]
    included, by_dir, excluded, plates, bank_tiers = _scan(compiled)
    base = int(data.get("export_base_budget_bytes", 0))
    per_plate = int(data.get("export_bank_bytes_per_plate", 0))
    plate_max = int(data.get("export_bank_plate_max_bytes", 0))
    bank_bytes = sum(plates.values())
    budget = base + per_plate * len(plates)
    print(f"EXPORT PLATFORM {label}")
    print(f"EXPORT EXCLUDED {excluded}")
    for key, size in sorted(by_dir.items(), key=lambda item: (-item[1], item[0]))[:25]:
        print(f"EXPORT DIR {key} {size}")
    print(
        "EXPORT BANK_TIERS "
        f"master={bank_tiers['master']} medium={bank_tiers['medium']} "
        f"small={bank_tiers['small']} other={bank_tiers['other']}"
    )
    print(f"EXPORT SIZE {included}")
    print(f"EXPORT BANK plates={len(plates)} bytes={bank_bytes} per_plate={per_plate} plate_max={plate_max}")
    print(f"EXPORT NONBANK {included - bank_bytes} base={base}")
    print(f"EXPORT BUDGET {budget}")
    print(f"EXPORT CAP {CAP_BYTES}")
    print(f"EXPORT TARGET {TARGET_BYTES}")
    cap_status = "UNDER" if included <= CAP_BYTES else "OVER"
    print(f"EXPORT CAP_STATUS {label} {cap_status} {included}")
    rc = 0
    if base <= 0 or per_plate <= 0 or plate_max <= 0:
        print(
            "EXPORT SIZE FAIL ratchet.json needs export_base_budget_bytes, "
            "export_bank_bytes_per_plate, export_bank_plate_max_bytes"
        )
        return 1
    fat = sorted((size, stem) for stem, size in plates.items() if size > plate_max)
    if fat:
        print(
            f"EXPORT SIZE FAIL {len(fat)} bank plates over {plate_max} bytes, "
            f"largest {fat[-1][1]} {fat[-1][0]}"
        )
        return 1
    if included > budget:
        print(f"EXPORT SIZE FAIL {included} > {budget}")
        return 1
    if label == "Android":
        medium_only = (
            bank_tiers["master"] == 0
            and bank_tiers["small"] == 0
            and bank_tiers["medium"] > 0
        )
        flag = 1 if medium_only else 0
        print(f"EXPORT ANDROID_BANK_CONTRACT medium_only={flag}")
        if not medium_only:
            print(
                "EXPORT SIZE FAIL Android bank must be medium-only "
                f"(master={bank_tiers['master']} small={bank_tiers['small']} "
                f"medium={bank_tiers['medium']})"
            )
            rc = 1
        if included > CAP_BYTES:
            print(
                "EXPORT NOTE Android source estimate is above the 400MiB hard cap; "
                "see docs/art/export-cap-400.md for measured APK breakdown and next levers."
            )
    elif budget > CAP_BYTES and label == "Windows Desktop":
        print(
            "EXPORT NOTE Windows active budget is above the 400MiB cap "
            "(ships large bank masters); Android is the packing target."
        )
    return rc


def main() -> int:
    filters = _preset_filters()
    retired = _retired_patterns()
    data = json.loads(RATCHET.read_text(encoding="utf-8")) if RATCHET.is_file() else {}
    rc = 0
    for label in ("Windows Desktop", "Android"):
        rc |= _report_platform(label, filters[label], retired, data)
        print("")
    if rc == 0:
        print("EXPORT SIZE PASS")
    return rc


if __name__ == "__main__":
    sys.exit(main())
