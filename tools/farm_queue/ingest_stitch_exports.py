#!/usr/bin/env python3
"""Integrate Google Stitch HTML/PNG exports into v8 UI skeletons folder + optional Godot refs."""
from __future__ import annotations
import json, re, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "project/assets/art/stitch_exports"
OUT = ROOT / "docs/art/stitch_skeletons_v8"
MANIFEST = ROOT / "tools/farm_queue/stitch_export_manifest.json"

# Expected screen basenames from live Stitch project
EXPECT = ["castle_hub", "battle_hud", "menu", "atlas", "tavern", "roster", "deploy"]

def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    SRC.mkdir(parents=True, exist_ok=True)
    landed = []
    for p in sorted(SRC.rglob("*")):
        if p.suffix.lower() not in {".html", ".png", ".jpg", ".webp", ".svg", ".css", ".json"}:
            continue
        dest = OUT / p.name
        shutil.copy2(p, dest)
        landed.append(str(dest.relative_to(ROOT)))
        print("STITCH", p.name, "->", dest.relative_to(ROOT))
    # also accept zip
    for z in SRC.glob("*.zip"):
        import zipfile
        with zipfile.ZipFile(z) as zf:
            zf.extractall(OUT / z.stem)
        landed.append(str((OUT / z.stem).relative_to(ROOT)))
        print("STITCH ZIP", z.name)
    missing = [e for e in EXPECT if not any(e in Path(x).stem for x in landed)]
    MANIFEST.write_text(json.dumps({"landed": landed, "missing": missing}, indent=2) + "\n")
    print("landed", len(landed), "missing", missing)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
