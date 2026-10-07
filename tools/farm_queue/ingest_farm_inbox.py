#!/usr/bin/env python3
"""Map project/assets/art/farm_inbox/* into live UI/FX/portrait paths.
Prefer Qwen plates (qwen_*/ or *_qwen_*); fall back to SN. Run after CopyToBox.
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
    "ui_estates_banner": UI / "estates_banner.png",
    "ui_estate_focus_grain": UI / "estate_focus_grain.png",
    "ui_estate_focus_cash": UI / "estate_focus_cash.png",
    "ui_estate_focus_fortify": UI / "estate_focus_fortify.png",
    "ui_estate_focus_triptych": UI / "estates_backdrop.png"  # triptych wash,
    "ui_alliance_duty": UI / "alliance_duty_chip.png",
    "ui_convoy_grain": UI / "convoy_grain.png",
    "ui_convoy_iron": UI / "convoy_iron.png",
    "ui_convoy_spice": UI / "convoy_spice.png",
    "ui_hub_banner_strip": UI / "hub_banner_strip.png",
    "ui_lineage_banner": UI / "lineage_banner.png",
    "ui_marriage_banner": UI / "marriage_banner.png",
    "hub_monthly_settle": UI / "monthly_banner.png",
    "hub_panel_chrome": UI / "hub_panel_edge.png",
    "battle_backdrop_wash": UI / "battle_backdrop.png",
    "concept_hire_plate_m": POR / "hireuniq_farm_m.png",
    "concept_hire_plate_f": POR / "hireuniq_farm_f.png",
    "fx_zoc_pulse_sheet": FX / "zoc_pulse_sheet.png",
    "fx_lock_spark_sheet": FX / "lock_spark_sheet.png",
    "fx_hit_spark_sheet": FX / "hit_spark_sheet.png",
    "fx_dmg_pop_sheet": FX / "dmg_pop_sheet.png",
}

def _label_of(stem: str) -> str | None:
    s = stem
    # strip engine prefixes/suffixes
    s = re.sub(r"^(qwen_|sn_|sn_local_)", "", s)
    s = re.sub(r"_(qwen|sn|sn_local).*$", "", s)
    if s in MAP:
        return s
    for k in MAP:
        if s.startswith(k) or k in s:
            return k
    return None

def _prefer_rank(path: Path) -> int:
    n = path.name.lower()
    if "qwen" in n or path.parent.name == "qwen":
        return 0
    if "sn" in n:
        return 2
    return 1

def main() -> int:
    if not INBOX.exists():
        print("no inbox", INBOX); return 1
    files = list(INBOX.rglob("*.png")) + list(INBOX.rglob("*.webp"))
    if not files:
        print("inbox empty — drop farm plates then re-run"); return 2
    # prefer Qwen when both engines present for same label
    best: dict[str, Path] = {}
    for f in files:
        lab = _label_of(f.stem)
        if lab is None:
            print("skip unmapped", f.relative_to(INBOX)); continue
        cur = best.get(lab)
        if cur is None or _prefer_rank(f) < _prefer_rank(cur):
            best[lab] = f
    n = 0
    for lab, f in sorted(best.items()):
        dest = MAP[lab]
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, dest)
        print("INGEST", f.relative_to(INBOX), "->", dest.relative_to(ROOT))
        n += 1
        if lab.endswith("_sheet"):
            print("  NOTE: sheet kept whole; slice frames in Godot or extend this script")
    print(f"done {n} files (prefer Qwen). Re-import / run CI.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
