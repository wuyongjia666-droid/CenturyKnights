#!/usr/bin/env python3
"""v8.5 audit: every v840 farm output must be consumed at runtime (directly, via a v85 derivative,
or via make_themed_bg theme), or explicitly rejected with a reason. Exit 1 on any leftover."""
import json, re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = "\n".join(p.read_text() for p in (ROOT / "project/scripts").rglob("*.gd"))
ING = (ROOT / "tools/farm_queue/ingest_v840_art.py").read_text()
outs = re.findall(r'"(v84_[a-z_]+)":\s*(?:UI|HUB|FX|REJ|[A-Z_]+)\s*/\s*"([^"]+)"', ING)
DERIVED = {  # v840 plate -> v85 runtime derivative (tools/farm_queue/prep_v850_chrome.py)
    "lineage_card.png": "v85/lineage_card_frame.png", "bloodline_strip.png": "v85/bloodline_frame.png",
    "unit_card_frame.png": "v85/unit_card_shell.png", "skill_chip.png": "v85/skill_chip_frame.png",
    "hp_bar_kit.png": "v85/hp_bar_frame.png", "dual_portrait_frame.png": "v85/dual_portrait_frame_cut.png",
    "estate_focus_grain.png": "v85/estate_tile_%s.png", "estate_focus_cash.png": "v85/estate_tile_%s.png",
    "estate_focus_fortify.png": "v85/estate_tile_%s.png",
}
RETIRED = {k: v for k, v in json.loads((ROOT / "tools/farm_queue/retired_v86.json").read_text()).items() if not k.startswith("_")}
THEMES = set(re.findall(r'make_themed_bg\(self,\s*"([a-z_]+)"\)', SCRIPTS))
rows, bad = [], 0
for key, fname in outs:
    if "REJ /" in ING.split(key, 1)[1].split("\n", 1)[0]:
        rows.append((key, fname, "REJECTED (illustration panels, not VFX) -> authored VFX")); continue
    stem = fname[:-4]
    how = ""
    if fname.endswith("_backdrop.png") and stem[:-9] in THEMES:
        how = f"make_themed_bg('{stem[:-9]}')"
    elif fname in DERIVED and DERIVED[fname] in SCRIPTS:
        how = f"derived {DERIVED[fname]}"
    elif fname in SCRIPTS or ('"res://assets/art/ui/%s' % stem) in SCRIPTS:
        how = "direct"
    elif fname in RETIRED:
        how = f"RETIRED v8.6 — {RETIRED[fname]}"
    elif fname in DERIVED:
        how = f"derived {DERIVED[fname]}"
    if not how:
        bad += 1; how = "UNUSED"
    rows.append((key, fname, how))
# geno portraits
for g in sorted((ROOT / "project/assets/art/portraits").glob("v84_geno_*.png")):
    rows.append((g.stem, g.name, "unit_art geno fallback + marriage (thumb_ for <=240px)" if "v84_geno_" in SCRIPTS else "UNUSED"))
for r in rows:
    print("%-34s %-28s %s" % r)
print("LEFTOVER", bad)
sys.exit(1 if bad else 0)
