#!/usr/bin/env python3
"""Frost glyphs for all 223 items, and city-fallback plates with a node badge.

Re-run from the repo root. Writes SVG + PNG glyphs and cropped nation-plate
fallbacks. --check asserts style_check gold and parchment are 0.

  python3 tools/art/item_glyphs_v92.py
  python3 tools/art/item_glyphs_v92.py --check
"""
from __future__ import annotations

import json
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
Image = None
ImageDraw = None
ITEMS = json.loads((ROOT / "project/data/world_items_v87.json").read_text())["items"]
WORLD = json.loads((ROOT / "project/data/world_v87.json").read_text())
PASSED = {p.removeprefix("v87_city_") for p in json.loads((ROOT / "docs/art/review/atlas_v87_ingest.json").read_text())["passed"]}
GLYPH = ROOT / "project/assets/art/items/glyph"
CITIES = ROOT / "project/assets/art/atlas/cities"
ATLAS = ROOT / "project/assets/art/atlas"

BG = (22, 27, 36, 255)
INK = (10, 14, 20, 255)
FROST = (110, 212, 255, 255)
MINT = (94, 224, 181, 255)
SILVER = (201, 211, 222, 255)
WHITE = (244, 247, 251, 255)
SLATE = (42, 52, 66, 255)
RINGS = {1: SLATE, 2: SILVER, 3: FROST, 4: FROST, 5: MINT}

SHAPES = {
    "sword": "blade",
    "blade": "blade",
    "spear": "spear",
    "lance": "spear",
    "axe": "axe",
    "bow": "bow",
    "crossbow": "bow",
    "staff": "staff",
    "armor": "armor",
    "shield": "shield",
    "charm": "charm",
    "focus": "charm",
}


def _need_pil():
    global Image, ImageDraw
    if Image is None:
        from PIL import Image as image_mod
        from PIL import ImageDraw as draw_mod
        Image = image_mod
        ImageDraw = draw_mod


def _svg_header() -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">'
        '<rect width="128" height="128" fill="#161B24"/>'
    )


def _draw_shape(dr: ImageDraw.ImageDraw, kind: str, fill) -> str:
    """Return the matching SVG fragment. Coordinates stay inside the frost ring."""
    if kind == "blade":
        dr.polygon([(64, 22), (74, 78), (64, 86), (54, 78)], fill=fill)
        dr.rectangle([48, 86, 80, 92], fill=SILVER)
        return '<polygon points="64,22 74,78 64,86 54,78" fill="#6ED4FF"/><rect x="48" y="86" width="32" height="6" fill="#C9D3DE"/>'
    if kind == "spear":
        dr.polygon([(64, 18), (74, 48), (64, 44), (54, 48)], fill=fill)
        dr.rectangle([62, 44, 66, 104], fill=SILVER)
        return '<polygon points="64,18 74,48 64,44 54,48" fill="#6ED4FF"/><rect x="62" y="44" width="4" height="60" fill="#C9D3DE"/>'
    if kind == "axe":
        dr.polygon([(40, 36), (78, 28), (84, 58), (40, 64)], fill=fill)
        dr.rectangle([58, 58, 64, 108], fill=SILVER)
        return '<polygon points="40,36 78,28 84,58 40,64" fill="#6ED4FF"/><rect x="58" y="58" width="6" height="50" fill="#C9D3DE"/>'
    if kind == "bow":
        dr.arc([36, 24, 92, 104], 300, 60, fill=FROST, width=4)
        dr.line([(64, 28), (64, 100)], fill=SILVER, width=2)
        return '<path d="M46,30 Q96,64 46,98" fill="none" stroke="#6ED4FF" stroke-width="4"/><line x1="64" y1="28" x2="64" y2="100" stroke="#C9D3DE" stroke-width="2"/>'
    if kind == "staff":
        dr.rectangle([61, 36, 67, 108], fill=SILVER)
        dr.ellipse([52, 18, 76, 42], outline=FROST, width=3)
        return '<rect x="61" y="36" width="6" height="72" fill="#C9D3DE"/><circle cx="64" cy="30" r="12" fill="none" stroke="#6ED4FF" stroke-width="3"/>'
    if kind == "armor":
        dr.polygon([(40, 40), (88, 40), (96, 96), (32, 96)], fill=SLATE)
        dr.polygon([(56, 28), (72, 28), (76, 48), (52, 48)], fill=fill)
        return '<polygon points="40,40 88,40 96,96 32,96" fill="#2A3442"/><polygon points="56,28 72,28 76,48 52,48" fill="#6ED4FF"/>'
    if kind == "shield":
        dr.polygon([(40, 28), (88, 28), (88, 70), (64, 104), (40, 70)], fill=SLATE, outline=FROST)
        return '<polygon points="40,28 88,28 88,70 64,104 40,70" fill="#2A3442" stroke="#6ED4FF" stroke-width="3"/>'
    dr.ellipse([50, 36, 78, 64], outline=FROST, width=3)
    dr.ellipse([58, 70, 70, 82], fill=MINT)
    return '<circle cx="64" cy="50" r="14" fill="none" stroke="#6ED4FF" stroke-width="3"/><circle cx="64" cy="76" r="6" fill="#5EE0B5"/>'


def _glyph(item: dict) -> tuple[Image.Image, str]:
    tier = max(1, min(5, int(item.get("tier", 1))))
    ring = RINGS[tier]
    kind = SHAPES.get(str(item.get("type", "")), "charm")
    im = Image.new("RGBA", (128, 128), BG)
    dr = ImageDraw.Draw(im)
    dr.ellipse([8, 8, 120, 120], outline=ring, width=4)
    frag = _draw_shape(dr, kind, FROST)
    hexring = "#%02X%02X%02X" % ring[:3]
    svg = _svg_header() + f'<circle cx="64" cy="64" r="54" fill="none" stroke="{hexring}" stroke-width="4"/>' + frag + "</svg>"
    return im, svg


def _plate_for(nation: str) -> Path:
    if nation == "landbridge":
        return ATLAS / "v8_atlas_landbridge_inset.png"
    named = ATLAS / f"v8_atlas_nation_{nation}.png"
    if named.exists():
        return named
    return ATLAS / "v8_atlas_world.png"


def _badge(kind: str, dr: ImageDraw.ImageDraw, cx: int, cy: int) -> None:
    dr.ellipse([cx - 28, cy - 28, cx + 28, cy + 28], fill=(7, 8, 12, 210), outline=FROST, width=3)
    if kind == "capital":
        dr.polygon([(cx, cy - 16), (cx + 14, cy + 10), (cx - 14, cy + 10)], outline=WHITE)
    elif kind == "port":
        dr.arc([cx - 16, cy - 8, cx + 16, cy + 16], 200, 340, fill=FROST, width=3)
    elif kind in ("fortress", "castle"):
        dr.rectangle([cx - 12, cy - 8, cx + 12, cy + 14], outline=WHITE)
        dr.rectangle([cx - 4, cy - 16, cx + 4, cy - 8], outline=FROST)
    elif kind == "village":
        dr.ellipse([cx - 12, cy - 6, cx - 2, cy + 4], fill=MINT)
        dr.ellipse([cx + 2, cy - 6, cx + 12, cy + 4], fill=FROST)
    else:
        dr.rectangle([cx - 12, cy - 12, cx + 12, cy + 12], outline=FROST, width=2)


def _cool(im: Image.Image) -> Image.Image:
    """Thumbnail resampling can invent beige pixels. Grade the plate toward frost first."""
    import numpy as np

    arr = np.asarray(im.convert("RGBA")).astype(np.float32)
    rgb = arr[..., :3]
    rgb = rgb * 0.55 + np.array([18, 32, 48], dtype=np.float32)
    rgb[..., 0] = np.minimum(rgb[..., 0], rgb[..., 2] * 0.75)
    arr[..., :3] = np.clip(rgb, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def _fallback(node: dict) -> Image.Image:
    plate = Image.open(_plate_for(str(node["nation"]))).convert("RGBA")
    w, h = plate.size
    pos = node.get("pos", [0.5, 0.5])
    cx = float(pos[0]) * w
    cy = float(pos[1]) * h
    cw, ch = max(32, w // 3), max(32, h // 3)
    left = int(min(max(0, cx - cw / 2), w - cw))
    top = int(min(max(0, cy - ch / 2), h - ch))
    crop = plate.crop((left, top, left + int(cw), top + int(ch))).resize((640, 360), Image.Resampling.LANCZOS)
    crop = _cool(crop)
    dr = ImageDraw.Draw(crop)
    _badge(str(node.get("kind", "town")), dr, 320, 180)
    return crop


def _ratios(path: Path) -> tuple[float, float]:
    """gold / parchment ratios. Same hue gates as style_check, no Pillow."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"not a png {path.name}")
    pos = 8
    width = height = color_type = None
    idat = []
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        ctype = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            width, height, bit_depth, color_type = struct.unpack(">IIBB", chunk[:10])
            if bit_depth != 8 or color_type not in (2, 6):
                raise ValueError(f"unsupported png {path.name}")
        elif ctype == b"IDAT":
            idat.append(chunk)
        elif ctype == b"IEND":
            break
    raw = zlib.decompress(b"".join(idat))
    bpp = 4 if color_type == 6 else 3
    stride = width * bpp
    i = 0
    prev = bytearray(stride)
    gold = parch = n = 0
    for _y in range(height):
        filt = raw[i]
        i += 1
        row = bytearray(raw[i : i + stride])
        i += stride
        if filt == 1:
            for x in range(stride):
                left = row[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + left) & 255
        elif filt == 2:
            for x in range(stride):
                row[x] = (row[x] + prev[x]) & 255
        elif filt == 3:
            for x in range(stride):
                left = row[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + ((left + prev[x]) // 2)) & 255
        elif filt == 4:
            for x in range(stride):
                a = row[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                row[x] = (row[x] + pr) & 255
        elif filt != 0:
            raise ValueError(f"filter {filt} {path.name}")
        prev = row
        for x in range(0, stride, bpp):
            r, g, b = row[x] / 255.0, row[x + 1] / 255.0, row[x + 2] / 255.0
            alpha = row[x + 3] / 255.0 if bpp == 4 else 1.0
            if alpha < 0.5:
                continue
            n += 1
            mx, mn = max(r, g, b), min(r, g, b)
            delta = mx - mn + 1e-6
            if mx == r:
                hue = ((g - b) / delta) % 6
            elif mx == g:
                hue = (b - r) / delta + 2
            else:
                hue = (r - g) / delta + 4
            hue *= 60.0
            sat = (mx - mn) / (mx + 1e-6) if mx > 0 else 0.0
            if 32.0 < hue < 58.0 and sat > 0.42 and mx > 0.35:
                gold += 1
            if 20.0 < hue < 50.0 and 0.12 < sat < 0.40 and mx > 0.55:
                parch += 1
    if n == 0:
        return 1.0, 1.0
    return gold / n, parch / n


def build() -> None:
    _need_pil()
    GLYPH.mkdir(parents=True, exist_ok=True)
    CITIES.mkdir(parents=True, exist_ok=True)
    for item in ITEMS:
        im, svg = _glyph(item)
        stem = GLYPH / f"v92_glyph_{item['id']}"
        im.save(stem.with_suffix(".png"))
        stem.with_suffix(".svg").write_text(svg)
    n = 0
    for node in WORLD["nodes"]:
        if node["id"] in PASSED:
            continue
        _fallback(node).save(CITIES / f"v92_fallback_{node['id']}.png")
        n += 1
    print(f"glyphs={len(ITEMS)} fallbacks={n}")


def check() -> int:
    errors = []
    pngs = sorted(GLYPH.glob("v92_glyph_*.png"))
    if len(pngs) != 223 or len(list(GLYPH.glob("v92_glyph_*.svg"))) != 223:
        errors.append(f"glyph count png={len(pngs)}")
    ids = {i["id"] for i in ITEMS}
    have = {p.stem.removeprefix("v92_glyph_") for p in pngs}
    if have != ids:
        errors.append("glyph ids")
    fallbacks = []
    for node in WORLD["nodes"]:
        if node["id"] in PASSED:
            continue
        path = CITIES / f"v92_fallback_{node['id']}.png"
        if not path.exists():
            errors.append(f"missing fallback {node['id']}")
        else:
            fallbacks.append(path)
    if len(fallbacks) != 35:
        errors.append(f"fallbacks {len(fallbacks)}")
    for path in pngs + fallbacks:
        gold, parch = _ratios(path)
        if gold != 0.0 or parch != 0.0:
            errors.append(f"{path.name} gold={gold} parch={parch}")
            break
    if errors:
        for err in errors:
            print("FAIL", err)
        return 1
    print(f"GLYPH CHECK PASS glyphs=223 fallbacks=35 gold=0 parchment=0")
    return 0


def main() -> int:
    if "--check" in sys.argv:
        return check()
    build()
    return check()


if __name__ == "__main__":
    sys.exit(main())
