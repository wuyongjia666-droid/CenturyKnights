#!/usr/bin/env python3
"""Map project/assets/art/farm_inbox/* into live UI/FX/portrait paths.
Run after farm LAN is fixed and plates are copied into farm_inbox.
Naming: prefer shot id prefixes from shots_v721.json (ui_market_banner.png, etc.)
"""
from __future__ import annotations
import shutil, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INBOX = ROOT / "project/assets/art/farm_inbox"
UI = ROOT / "project/assets/art/ui"
FX = ROOT / "project/assets/art/fx"
POR = ROOT / "project/assets/art/portraits"

MAP = {
    "ui_market_banner": UI / "market_banner.png",
    "ui_caravan_banner": UI / "caravan_banner.png",
    "ui_works_banner": UI / "works_banner.png",
    "ui_estates_banner": UI / "hub_banner_strip.png",
    "ui_estate_focus_grain": UI / "estate_focus_grain.png",
    "ui_estate_focus_cash": UI / "estate_focus_cash.png",
    "ui_estate_focus_fortify": UI / "estate_focus_fortify.png",
    "ui_alliance_duty": UI / "alliance_duty_chip.png",
    "ui_convoy_grain": UI / "convoy_grain.png",
    "ui_convoy_iron": UI / "convoy_iron.png",
    "ui_convoy_spice": UI / "convoy_spice.png",
    "hub_monthly_settle": UI / "monthly_banner.png",
    "hub_panel_chrome": UI / "hub_panel_edge.png",
    "battle_backdrop_wash": UI / "battle_backdrop.png",
    "concept_hire_plate_m": POR / "hireuniq_farm_m.png",
    "concept_hire_plate_f": POR / "hireuniq_farm_f.png",
}

def main() -> int:
    if not INBOX.exists():
        print("no inbox", INBOX); return 1
    files = list(INBOX.glob("*.png")) + list(INBOX.glob("*.webp"))
    if not files:
        print("inbox empty — drop farm plates then re-run"); return 2
    n = 0
    for f in files:
        stem = f.stem
        # strip engine tags _qwen_ / _sn_
        key = re.sub(r"_(qwen|sn).*$", "", stem)
        key = key.replace("-", "_")
        dest = MAP.get(key)
        if dest is None:
            for k, d in MAP.items():
                if stem.startswith(k) or k in stem:
                    dest = d; key = k; break
        if dest is None:
            print("skip unmapped", f.name); continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, dest)
        print("INGEST", f.name, "->", dest.relative_to(ROOT))
        n += 1
        # FX sheets: optional split later
        if key == "fx_zoc_pulse_sheet":
            print("  NOTE: slice zoc_pulse_0..5 manually or extend this script")
        if key == "fx_lock_spark_sheet":
            print("  NOTE: slice lock frames manually or extend this script")
    print(f"done {n} files. Re-import in Godot / run CI.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
