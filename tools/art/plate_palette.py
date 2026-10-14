#!/usr/bin/env python3
"""Offline portrait-plate palette sampler (pawn-redesign-opus.md appendix C).

Writes project/data/plate_palettes.json keyed by plate stem.
Samples a subset when --limit is set; full bank is ~1595 stems.

  python3 tools/art/plate_palette.py [--limit N] [--out PATH]
"""
from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "project/assets/art/portraits/genome/bank"
DEFAULT_OUT = ROOT / "project/data/plate_palettes.json"

try:
    from PIL import Image
except ImportError:
    Image = None


def _lum(r, g, b):
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _looks_skin(r, g, b):
    mx, mn = max(r, g, b), min(r, g, b)
    chroma = mx - mn
    return r > 0.35 and g > 0.25 and b > 0.18 and r >= g and 0.04 < chroma < 0.35 and mx < 0.95


def _looks_bg(r, g, b):
    mx, mn = max(r, g, b), min(r, g, b)
    return (mx - mn) < 0.06 and mx > 0.55


def sample_plate(path: Path) -> dict:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()

    def band(x0, x1, y0, y1, pred, step=8):
        acc = [0.0, 0.0, 0.0]
        n = 0
        for y in range(y0, y1, max(1, (y1 - y0) // step or 1)):
            for x in range(x0, x1, max(1, (x1 - x0) // step or 1)):
                r, g, b, a = px[x, y]
                if a < 100:
                    continue
                rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
                if pred(rf, gf, bf):
                    acc[0] += rf
                    acc[1] += gf
                    acc[2] += bf
                    n += 1
        if n == 0:
            return None
        return [acc[0] / n, acc[1] / n, acc[2] / n]

    skin = band(int(w * 0.35), int(w * 0.65), int(h * 0.28), int(h * 0.48), _looks_skin)
    hair = band(
        int(w * 0.25),
        int(w * 0.75),
        int(h * 0.04),
        int(h * 0.22),
        lambda r, g, b: not _looks_skin(r, g, b) and not _looks_bg(r, g, b) and _lum(r, g, b) < 0.75,
    )
    coat = band(
        int(w * 0.28),
        int(w * 0.72),
        int(h * 0.55),
        int(h * 0.82),
        lambda r, g, b: not _looks_skin(r, g, b) and not _looks_bg(r, g, b),
    )

    def lift(rgb, k):
        if not rgb:
            return None
        # HSV value lift approximation on RGB
        return [min(1.0, c * k) for c in rgb]

    # Heuristic hair style from top silhouette mass
    style = "crop"
    top = band(int(w * 0.2), int(w * 0.8), int(h * 0.02), int(h * 0.18), lambda r, g, b: not _looks_bg(r, g, b), step=6)
    if top and _lum(*top) < 0.35:
        style = "long" if coat and _lum(*coat) < 0.4 else "swept"

    return {
        "hair": lift(hair, 1.18) or [0.25, 0.20, 0.18],
        "skin": lift(skin, 1.06) or [0.78, 0.62, 0.52],
        "coat": lift(coat, 1.15) or [0.55, 0.58, 0.62],
        "lining": lift([c * 0.55 for c in (coat or [0.3, 0.3, 0.3])], 1.0),
        "style": style,
        "source": path.name,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = ap.parse_args()
    if Image is None:
        print("plate_palette FAIL need Pillow")
        return 1
    if not BANK.is_dir():
        print(f"plate_palette FAIL missing bank {BANK}")
        return 1
    files = sorted(
        p
        for p in BANK.iterdir()
        if p.suffix.lower() in (".webp", ".png", ".jpg") and ".small." not in p.name and ".import" not in p.name
    )
    # Prefer medium plates without .face / tier suffixes when possible
    stems = {}
    for p in files:
        stem = p.stem
        # skip resolution tiers like name.medium
        if stem.endswith(".medium") or stem.endswith(".large") or stem.endswith(".small"):
            continue
        stems[stem] = p
    items = sorted(stems.items())
    if args.limit > 0:
        items = items[: args.limit]
    out = {"version": 1, "count": 0, "plates": {}}
    for stem, path in items:
        try:
            out["plates"][stem] = sample_plate(path)
        except Exception as e:
            out["plates"][stem] = {"error": str(e), "hair": [0.25, 0.2, 0.18], "skin": [0.78, 0.62, 0.52], "coat": [0.5, 0.5, 0.55], "style": "crop"}
    out["count"] = len(out["plates"])
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(out, indent=2), encoding="utf-8")
    print(f"PLATE PALETTE OK count={out['count']} -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
