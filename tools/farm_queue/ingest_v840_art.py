#!/usr/bin/env python3
"""Ingest v84 marriage/lineage/estate/HUD/FX/geno plates."""
from __future__ import annotations
from pathlib import Path
from PIL import Image, ImageEnhance, ImageOps
import shutil

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "project/assets/art/farm_inbox/qwen_v840"
UI = ROOT / "project/assets/art/ui"
FX = ROOT / "project/assets/art/fx"
POR = ROOT / "project/assets/art/portraits"

MAP = {
    "v84_hub_rite": UI / "rite_backdrop.png",
    "v84_hub_marriage_stage": UI / "marriage_backdrop.png",
    "v84_hub_lineage_tree": UI / "lineage_backdrop.png",
    "v84_hub_estates_vista": UI / "estates_backdrop.png",
    "v84_ui_dual_portrait_frame": UI / "dual_portrait_frame.png",
    "v84_ui_lineage_card": UI / "lineage_card.png",
    "v84_ui_bloodline_strip": UI / "bloodline_strip.png",
    "v84_ui_marriage_banner": UI / "marriage_banner.png",
    "v84_ui_lineage_banner": UI / "lineage_banner.png",
    "v84_ui_estate_card_grain": UI / "estate_focus_grain.png",
    "v84_ui_estate_card_cash": UI / "estate_focus_cash.png",
    "v84_ui_estate_card_fort": UI / "estate_focus_fortify.png",
    "v84_ui_estate_focus_bar": UI / "estate_focus_bar.png",
    "v84_ui_battle_hud_dense": UI / "battle_hud_frame.png",
    "v84_ui_turn_banner_dense": UI / "turn_banner.png",
    "v84_ui_unit_card_frame": UI / "unit_card_frame.png",
    "v84_ui_skill_chip": UI / "skill_chip.png",
    "v84_ui_hp_bar_dense": UI / "hp_bar_kit.png",
    "v84_fx_hit_dense_sheet": FX / "hit_dense_sheet.png",
    "v84_fx_slash_dense_sheet": FX / "slash_dense_sheet.png",
    "v84_fx_heal_dense_sheet": FX / "heal_dense_sheet.png",
    "v84_fx_select_dense_sheet": FX / "select_dense_sheet.png",
    "v84_fx_marriage_seal_sheet": FX / "marriage_seal_sheet.png",
    "v84_fx_lineage_link_sheet": FX / "lineage_link_sheet.png",
}

def mild(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    rgb = ImageOps.autocontrast(im.convert("RGB"), cutoff=1)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.08)
    rgb = ImageEnhance.Color(rgb).enhance(1.04)
    out = rgb.convert("RGBA")
    return out

def main() -> int:
    if not SRC.exists():
        print("missing", SRC); return 1
    n = 0
    for lab, dst in MAP.items():
        s = SRC / f"{lab}.png"
        if not s.exists():
            print("MISS", lab); continue
        im = mild(Image.open(s))
        dst.parent.mkdir(parents=True, exist_ok=True)
        im.save(dst, "PNG")
        n += 1
        print("OK", lab, "->", dst.name, im.size)
    for s in sorted(SRC.glob("v84_geno_*.png")):
        im = mild(Image.open(s))
        dest = POR / f"{s.stem}.png"
        im.save(dest, "PNG")
        # also thumb for lists
        thumb = im.resize((220, 270), Image.Resampling.LANCZOS)
        # center crop if needed
        w, h = im.size
        scale = max(220 / w, 270 / h)
        nw, nh = int(w * scale), int(h * scale)
        r = im.resize((nw, nh), Image.Resampling.LANCZOS)
        left, top = (nw - 220) // 2, max(0, (nh - 270) // 4)
        thumb = r.crop((left, top, left + 220, top + 270))
        thumb.save(POR / f"thumb_{s.stem}.png", "PNG")
        n += 1
        print("GENO", s.stem)
    print("done", n)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
