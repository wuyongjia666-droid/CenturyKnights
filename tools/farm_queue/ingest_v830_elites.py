#!/usr/bin/env python3
"""Stamp v83 elite plates into named boss/archer/thug enemy token paths (all frames)."""
from __future__ import annotations
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageOps, ImageFilter
import json, shutil

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "project/assets/art/farm_inbox/qwen_v830"
TOK = ROOT / "project/assets/art/tokens"
UI = ROOT / "project/assets/art/ui"
FX = ROOT / "project/assets/art/fx"
THEMES = json.loads((ROOT / "tools/farm_queue/shots_v830_themes.json").read_text())
CORAL = (240, 113, 135)
GOLD = (232, 180, 90)
SIZE = 128

def polish(im: Image.Image, rim=CORAL, size=SIZE) -> Image.Image:
    im = im.convert("RGBA")
    rgb = ImageOps.autocontrast(im.convert("RGB"), cutoff=2)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.45)
    rgb = ImageEnhance.Brightness(rgb).enhance(1.3)
    rgb = ImageEnhance.Sharpness(rgb).enhance(1.6)
    out = rgb.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([2, 2, size - 3, size - 3], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(0.4))
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg.paste(out, (0, 0))
    bg.putalpha(mask)
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    for i in range(5):
        col = GOLD if i == 0 else rim
        rd.ellipse([1 + i, 1 + i, size - 2 - i, size - 2 - i], outline=(*col, 245 - i * 30))
    return Image.alpha_composite(bg, ring)

def fan(cell: Image.Image, stem: str, frames: int = 4) -> None:
    """Write stem_f0..f{n-1}.png"""
    for f in range(frames):
        # tiny phase nudge so frames aren't byte-identical (optional)
        cell.save(TOK / f"{stem}_f{f}.png", "PNG")

def main() -> int:
    if not SRC.exists():
        print("missing", SRC); return 1
    n = 0
    for theme in THEMES:
        for role in ("boss", "archer", "thug"):
            src = SRC / f"v83_elite_{theme}_{role}.png"
            if not src.exists():
                print("MISS", src.name); continue
            rim = GOLD if role == "boss" else CORAL
            cell = polish(Image.open(src), rim)
            # canonical elite
            cell.save(TOK / f"v83_elite_{theme}_{role}.png", "PNG")
            # paths unit_art expects: {theme}_{role}_enemy_f%d
            fan(cell, f"{theme}_{role}_enemy")
            n += 1
            print("OK", theme, role)
        # paper uses thief not thug for one path
        if theme == "paper":
            src = SRC / "v83_elite_paper_thug.png"
            if src.exists():
                cell = polish(Image.open(src), CORAL)
                fan(cell, "paper_thief_enemy")
    # specials
    for lab, stems in [
        ("v83_elite_escort_raider.png", ["escort_raider_enemy"]),
        ("v83_elite_paper_thief.png", ["paper_thief_enemy"]),
        ("v83_elite_bandit_captain.png", ["bandit_enemy"]),
    ]:
        p = SRC / lab
        if not p.exists():
            continue
        cell = polish(Image.open(p), GOLD if "bandit" in lab or "raider" in lab else CORAL)
        cell.save(TOK / lab.replace(".png", "") + ".png" if False else TOK / p.stem.replace("v83_elite_", "v83_") + ".png", "PNG")
        # fix save
        cell.save(TOK / (p.stem + ".png"), "PNG")
        for stem in stems:
            fan(cell, stem)
        n += 1
        print("SPECIAL", lab)
    # UI / FX
    for src, dst in [
        ("v83_ui_confirm_burst.png", UI / "confirm_burst.png"),
        ("v83_ui_soft_deny.png", UI / "soft_deny.png"),
        ("v83_fx_boss_entrance_sheet.png", FX / "boss_entrance_sheet.png"),
        ("v83_fx_critical_crystal_sheet.png", FX / "critical_crystal_sheet.png"),
    ]:
        s = SRC / src
        if s.exists():
            shutil.copy2(s, dst); n += 1; print("ASSET", dst.name)
    print("done", n)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
