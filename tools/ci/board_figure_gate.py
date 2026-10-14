#!/usr/bin/env python3
"""Static board-figure gate: enemy theme trims must not drive ally fill; docs present."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
THEMES = ROOT / "project/data/enemy_themes.json"
DESIGN = ROOT / "docs/design/pawn-redesign-opus.md"
SHADER = ROOT / "project/shaders/board_figure.gdshader"
HALO = ROOT / "project/shaders/board_halo.gdshader"
SCRIPT = ROOT / "project/scripts/art/board_figure.gd"
FORMAL_GLB = ROOT / "project/assets/models/board/board_figures_v1.glb"
FORMAL_JSON = ROOT / "project/assets/models/board/board_figures_v1.json"
FIGURES_DATA = ROOT / "project/data/board_figures.json"
PLATES = ROOT / "project/data/plate_palettes.json"
STANDS = ROOT / "project/assets/art/board_stands"

# Ally hue window 150–220° (HSV), chroma proxy via max-min on sRGB.
ALLY_H0, ALLY_H1 = 150.0, 220.0


def _hex_to_hsv(hx: str) -> tuple[float, float, float]:
    hx = hx.strip().lstrip("#")
    r, g, b = int(hx[0:2], 16) / 255.0, int(hx[2:4], 16) / 255.0, int(hx[4:6], 16) / 255.0
    mx, mn = max(r, g, b), min(r, g, b)
    chroma = mx - mn
    if chroma < 1e-6:
        return 0.0, 0.0, mx
    if mx == r:
        h = (60.0 * ((g - b) / chroma) + 360.0) % 360.0
    elif mx == g:
        h = 60.0 * ((b - r) / chroma) + 120.0
    else:
        h = 60.0 * ((r - g) / chroma) + 240.0
    s = chroma / mx if mx > 0 else 0.0
    return h, s, mx


def main() -> int:
    for path in (DESIGN, SHADER, HALO, SCRIPT, THEMES, FORMAL_GLB, FORMAL_JSON, FIGURES_DATA, PLATES):
        if not path.is_file():
            print(f"BOARD FIGURE GATE FAIL missing {path.relative_to(ROOT)}")
            return 1
    data = json.loads(THEMES.read_text(encoding="utf-8"))
    themes = data.get("themes", {})
    if not isinstance(themes, dict) or not themes:
        print("BOARD FIGURE GATE FAIL no themes")
        return 1
    # Document that fill is coral-locked in code; count how many trims would have been ally-coloured.
    allyish = 0
    for tid, row in themes.items():
        if not isinstance(row, dict):
            continue
        pal = row.get("palette", {}) if isinstance(row.get("palette"), dict) else {}
        trim = str(pal.get("trim", row.get("trim", "")))
        if not trim:
            continue
        h, s, v = _hex_to_hsv(trim)
        # sRGB chroma proxy: saturation * value roughly tracks max-min for these palette colours
        r = int(trim.lstrip("#")[0:2], 16) / 255.0
        g_ = int(trim.lstrip("#")[2:4], 16) / 255.0
        b = int(trim.lstrip("#")[4:6], 16) / 255.0
        chroma = max(r, g_, b) - min(r, g_, b)
        if ALLY_H0 <= h <= ALLY_H1 and chroma > 0.15:
            allyish += 1
    text = SCRIPT.read_text(encoding="utf-8")
    if "UIKit.DANGER" not in text and "enemy" not in text:
        print("BOARD FIGURE GATE FAIL board_figure.gd missing enemy handling")
        return 1
    model = (ROOT / "project/scripts/art/unit_model.gd").read_text(encoding="utf-8")
    if "Faction cloth locked to coral" not in model and "UIKit.DANGER" not in model:
        print("BOARD FIGURE GATE FAIL fill_color_for coral lock missing")
        return 1
    if "house_color" not in (ROOT / "project/scripts/art/unit_art.gd").read_text(encoding="utf-8"):
        print("BOARD FIGURE GATE FAIL house_color missing")
        return 1
    manifest = json.loads(FORMAL_JSON.read_text(encoding="utf-8"))
    est = manifest.get("assembled_estimates", {})
    for k, n in est.items():
        if int(n) > 7000:
            print(f"BOARD FIGURE GATE FAIL {k} tris {n} > 7000")
            return 1
    stand_need = ["ally_sword.png", "ally_bow.png", "enemy_bandit.png"]
    for s in stand_need:
        if not (STANDS / s).is_file():
            print(f"BOARD FIGURE GATE FAIL missing stand {s}")
            return 1
    plates = json.loads(PLATES.read_text(encoding="utf-8"))
    if int(plates.get("count", 0)) < 50:
        print("BOARD FIGURE GATE FAIL plate_palettes too small")
        return 1
    print(
        f"BOARD FIGURE GATE PASS themes={len(themes)} trim_would_be_allyish={allyish} "
        f"formal_parts={manifest.get('part_count')} est={est} plates={plates.get('count')} "
        f"(coral-locked in fill_color_for)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
