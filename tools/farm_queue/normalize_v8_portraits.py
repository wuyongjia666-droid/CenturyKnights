#!/usr/bin/env python3
"""Face-normalize v8 hero/bust plates to roster thumbs 220x270 (eyes upper third)."""
from __future__ import annotations
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
POR = ROOT / "project/assets/art/portraits"
TARGET = (220, 270)

def fit_bust(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    # bias crop toward upper face
    w, h = im.size
    # take central 70% width, top 75% height then scale
    cw, ch = int(w * 0.72), int(h * 0.78)
    left = (w - cw) // 2
    top = int(h * 0.06)
    im = im.crop((left, top, left + cw, min(top + ch, h)))
    tw, th = TARGET
    scale = max(tw / im.width, th / im.height)
    nw, nh = int(im.width * scale + 0.5), int(im.height * scale + 0.5)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left, top = (nw - tw) // 2, max(0, (nh - th) // 3)  # favor top
    if top + th > nh:
        top = nh - th
    return im.crop((left, top, left + tw, top + th))

def main():
    n = 0
    for p in sorted(POR.glob("v8_bust_*.png")) + sorted(POR.glob("v8_hero_*.png")):
        thumb = POR / f"thumb_{p.stem}.png"
        fit_bust(Image.open(p)).save(thumb, "PNG")
        n += 1
        print("THUMB", thumb.name)
    # stamp first 48 busts into hireuniq 0.. with copies for coverage refresh from high busts
    busts = sorted(POR.glob("v8_bust_*.png"))
    copies = 6
    for i, bp in enumerate(busts):
        cell = fit_bust(Image.open(bp))
        for c in range(copies):
            slot = i + c * max(len(busts), 1)
            if slot >= 768:
                continue
            cell.save(POR / f"hireuniq_{slot:03d}.png", "PNG")
            print(f"STAMP {slot:03d} <- {bp.stem}")
    print("done thumbs", n, "busts", len(busts))

if __name__ == "__main__":
    main()
