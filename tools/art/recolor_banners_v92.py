#!/usr/bin/env python3
"""Replace the #c9a227 banner set with the Frost crest palette.

Reads the six gold frames, retints warm cloth toward each frost hex, and writes
banner_<hex>_wN.png. Deletes banner_c9a227_*. The old hex maps to the nearest
new color in CIE76 Lab distance.

  python3 tools/art/recolor_banners_v92.py
  python3 tools/art/recolor_banners_v92.py --check
"""
from __future__ import annotations

import colorsys
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BANNERS = ROOT / "project" / "assets" / "art" / "banners"
sys.path.insert(0, str(ROOT / "tools" / "art"))

# Style-lock frost family. Hexes stay lowercase so filenames match unit_art.
PALETTE = [
    ("6ed4ff", (110, 212, 255), "主霜"),
    ("9be4ff", (155, 228, 255), "霜雾"),
    ("3aaddf", (58, 173, 223), "深霜"),
    ("5ee0b5", (94, 224, 181), "薄荷"),
    ("c9d3de", (201, 211, 222), "霜银"),
    ("2e6f8f", (46, 111, 143), "潮蓝"),
    ("d7f4ff", (215, 244, 255), "冰白"),
]
OLD = (0xC9, 0xA2, 0x27)
FRAMES = range(6)


def _lin(c: float) -> float:
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _lab(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
    r, g, b = (_lin(rgb[0]), _lin(rgb[1]), _lin(rgb[2]))
    x = r * 0.4124 + g * 0.3576 + b * 0.1805
    y = r * 0.2126 + g * 0.7152 + b * 0.0722
    z = r * 0.0193 + g * 0.1192 + b * 0.9505

    def f(t: float) -> float:
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116

    fx, fy, fz = f(x / 0.95047), f(y / 1.0), f(z / 1.08883)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def nearest_hex() -> str:
    gold = _lab(OLD)
    best, dist = PALETTE[0][0], 1e9
    for hexname, rgb, _name in PALETTE:
        lab = _lab(rgb)
        d = sum((a - b) ** 2 for a, b in zip(gold, lab)) ** 0.5
        if d < dist:
            best, dist = hexname, d
    return best


def migration() -> dict[str, str]:
    return {"c9a227": nearest_hex()}


def _retint(im, target: tuple[int, int, int]):
    tr, tg, tb = (c / 255 for c in target)
    th, ts, tv = colorsys.rgb_to_hsv(tr, tg, tb)
    cap = min(0.34, ts if ts > 0.08 else 0.22)
    out = im.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            hue = hh * 360
            if ss > 0.12 and 12 <= hue <= 80:
                use_s = cap if ss > 0.2 else ss
                nr, ng, nb = colorsys.hsv_to_rgb(th, use_s, vv * (0.92 + 0.08 * tv))
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return out


def build() -> None:
    from PIL import Image

    BANNERS.mkdir(parents=True, exist_ok=True)
    sources = []
    for frame in FRAMES:
        path = BANNERS / f"banner_c9a227_w{frame}.png"
        if not path.exists():
            raise SystemExit(f"missing gold source {path.name}; banners already migrated")
        sources.append(Image.open(path).convert("RGBA"))
    for hexname, rgb, _name in PALETTE:
        for frame, src in enumerate(sources):
            _retint(src, rgb).save(BANNERS / f"banner_{hexname}_w{frame}.png")
    for frame in FRAMES:
        for suffix in (".png", ".png.import"):
            old = BANNERS / f"banner_c9a227_w{frame}{suffix}"
            if old.exists():
                old.unlink()
    print(f"recolored frames={len(FRAMES)} colors={len(PALETTE)} migrate c9a227->{nearest_hex()}")


def check() -> int:
    import style_check_v87 as sc

    errors = []
    leftover = list(BANNERS.glob("*c9a227*"))
    if leftover:
        errors.append(f"leftover {[p.name for p in leftover]}")
    if migration()["c9a227"] != "c9d3de":
        errors.append(f"migration drifted {migration()}")
    for hexname, _rgb, _name in PALETTE:
        for frame in FRAMES:
            path = BANNERS / f"banner_{hexname}_w{frame}.png"
            if not path.exists():
                errors.append(f"missing {path.name}")
                continue
            m = sc.judge(str(path), "icon")
            if m["gold_ratio"] > 0.04 or not m["pass"]:
                errors.append(f"{path.name} gold={m['gold_ratio']:.3f} fails={m['fails']}")
    if errors:
        for err in errors:
            print("FAIL", err)
        return 1
    print(f"CREST CHECK PASS colors={len(PALETTE)} frames={len(list(FRAMES))} migrate=c9a227->{migration()['c9a227']}")
    return 0


def main() -> int:
    if "--check" in sys.argv:
        return check()
    build()
    map_path = ROOT / "docs" / "art" / "crest-migration-v92.json"
    map_path.write_text(json.dumps({
        "method": "CIE76 Lab",
        "from": "#c9a227",
        "to": "#" + nearest_hex(),
        "palette": [{"hex": "#" + h, "name": n} for h, _rgb, n in PALETTE],
    }, indent=2, ensure_ascii=False) + "\n")
    return check()


if __name__ == "__main__":
    sys.exit(main())
