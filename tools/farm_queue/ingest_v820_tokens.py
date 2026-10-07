#!/usr/bin/env python3
"""Ingest v82 job/enemy tokens + UI/FX; polish rims; fan-out hire aliases."""
from __future__ import annotations
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageOps, ImageFilter
import shutil

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "project/assets/art/farm_inbox/qwen_v820"
TOK = ROOT / "project/assets/art/tokens"
UI = ROOT / "project/assets/art/ui"
FX = ROOT / "project/assets/art/fx"
SIZE = 128

ROLE_OF = {
    "squire": "cavalry", "light_cavalry": "cavalry",
    "light_inf": "skirmisher", "heavy_inf": "tank", "warrior": "tank",
    "hunter": "ranger", "archer": "ranger",
    "apprentice": "mage", "priest": "mage",
}
MINT = (94, 212, 173)
FROST = (142, 200, 240)
CORAL = (240, 113, 135)

def polish(im: Image.Image, rim, size=SIZE) -> Image.Image:
    im = im.convert("RGBA")
    rgb = ImageOps.autocontrast(im.convert("RGB"), cutoff=2)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.42)
    rgb = ImageEnhance.Brightness(rgb).enhance(1.28)
    rgb = ImageEnhance.Sharpness(rgb).enhance(1.55)
    out = rgb.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([2, 2, size - 3, size - 3], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(0.45))
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg.paste(out, (0, 0))
    bg.putalpha(mask)
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    for i in range(4):
        rd.ellipse([1 + i, 1 + i, size - 2 - i, size - 2 - i], outline=(*rim, 240 - i * 28))
    return Image.alpha_composite(bg, ring)

def main() -> int:
    if not SRC.exists():
        print("missing", SRC); return 1
    n = 0
    for p in sorted(SRC.glob("v82_job_*.png")):
        # v82_job_{job}_{ally|enemy}
        parts = p.stem.split("_")
        # v82 job JOB ... side
        side = parts[-1]
        job = "_".join(parts[2:-1])
        rim = CORAL if side == "enemy" else (FROST if job in ("apprentice", "priest") else MINT)
        cell = polish(Image.open(p), rim)
        dest = TOK / f"v8_job_{job}_{side}.png"
        cell.save(dest, "PNG")
        n += 1
        print("JOB", dest.name)
        role = ROLE_OF.get(job, "skirmisher")
        if side == "ally":
            cell.save(TOK / f"v8_role_{role}.png", "PNG")
            for team in ("player", "ally"):
                for f in range(4):
                    cell.save(TOK / f"hire_{role}_{team}_f{f}.png", "PNG")
                    cell.save(TOK / f"hire_{job}_{team}_f{f}.png", "PNG")
        else:
            for f in range(4):
                cell.save(TOK / f"hire_{role}_enemy_f{f}.png", "PNG")
                cell.save(TOK / f"hire_{job}_enemy_f{f}.png", "PNG")
    for p in sorted(SRC.glob("v82_enemy_*.png")):
        cell = polish(Image.open(p), CORAL)
        dest = TOK / f"{p.stem}.png"
        cell.save(dest, "PNG")
        n += 1
        print("ENE", dest.name)
        if "boss" in p.stem:
            for f in range(4):
                cell.save(TOK / f"bandit_enemy_f{f}.png", "PNG")
    for src, dst in [
        ("v82_ui_focus_ring.png", UI / "focus_ring.png"),
        ("v82_ui_nav_selected.png", UI / "hub_nav_selected.png"),
        ("v82_fx_select_pulse_sheet.png", FX / "select_pulse_sheet.png"),
        ("v82_fx_heal_priest_sheet.png", FX / "heal_priest_sheet.png"),
    ]:
        s = SRC / src
        if s.exists():
            shutil.copy2(s, dst)
            n += 1
            print("UI/FX", dst.name)
    print("done", n)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
