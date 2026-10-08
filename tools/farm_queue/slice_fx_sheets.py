#!/usr/bin/env python3
"""Slice farm FX horizontal sheets into per-frame *_0..5 PNGs with plate keying."""
from __future__ import annotations
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FX = ROOT / "project/assets/art/fx"

SHEETS = [
    ("lineage_link_sheet.png", "lineage_link", 6),
    ("marriage_seal_sheet.png", "marriage_seal", 6),
    ("select_dense_sheet.png", "select_dense", 6),
    ("heal_dense_sheet.png", "heal_dense", 6),
    ("slash_dense_sheet.png", "slash_dense", 6),
    ("hit_dense_sheet.png", "hit_dense", 6),
    ("critical_crystal_sheet.png", "critical_crystal", 6),
    ("boss_entrance_sheet.png", "boss_entrance", 6),
    ("heal_priest_sheet.png", "heal_priest", 6),
    ("select_pulse_sheet.png", "select_pulse", 6),
    ("guard_ring_sheet.png", "guard_ring", 6),
    ("dust_ash_sheet.png", "dust_ash", 6),
    ("crit_seal_sheet.png", "crit_seal", 6),
    ("heal_mint_sheet.png", "heal_mint", 6),
    ("slash_ink_sheet.png", "slash_ink", 6),
    ("hit_crystal_sheet.png", "hit_crystal", 6),
    ("guard_break_sheet.png", "guard_break", 6),
    ("crit_ring_sheet.png", "crit_ring", 6),
    ("hit_spark_sheet.png", "hit_spark", 6),
    ("dmg_pop_sheet.png", "dmg_pop", 6),
    ("lock_spark_sheet.png", "lock", 6),
    ("zoc_pulse_sheet.png", "zoc_pulse", 6),
    ("slash_sheet.png", "slash", 6),
    ("crit_sheet.png", "crit", 6),
    ("heal_sheet.png", "heal", 6),
    ("unlock_sheet.png", "unlock", 6),
    ("shield_sheet.png", "shield", 6),
    ("spark_sheet.png", "spark", 6),
    ("crit_bloom_sheet.png", "crit", 6),
    ("move_dust_sheet.png", "move_dust", 6),
    ("turn_flash_sheet.png", "turn_flash", 6),
    ("blood_splash_sheet.png", "crit", 6),
    ("block_parry_sheet.png", "shield", 6),
    ("levelup_sheet.png", "unlock", 6),
    ("heal_aura_sheet.png", "heal", 6),
    ("miss_whoosh_sheet.png", "spark", 6),
    ("step_dust_sheet.png", "move_dust", 6),
]

def key_plate(cell: Image.Image, black_thr: int = 32, white_thr: int = 235) -> Image.Image:
    cell = cell.convert("RGBA")
    px = cell.load()
    for y in range(cell.height):
        for x in range(cell.width):
            r, g, b, a = px[x, y]
            mx, mn = max(r, g, b), min(r, g, b)
            sat = mx - mn
            if r >= white_thr and g >= white_thr and b >= white_thr:
                px[x, y] = (r, g, b, 0)
            elif mx <= black_thr and sat < 18:
                px[x, y] = (r, g, b, 0)
            elif mx <= 55 and sat < 12:
                px[x, y] = (r, g, b, 0)
    return cell

def slice_one(sheet: Path, prefix: str, n: int) -> int:
    if not sheet.exists():
        print("skip missing", sheet.name); return 0
    im = Image.open(sheet).convert("RGBA")
    w, h = im.size
    fw = max(1, w // n)
    for i in range(n):
        cell = key_plate(im.crop((i * fw, 0, (i + 1) * fw, h)))
        out = FX / f"{prefix}_{i}.png"
        cell.save(out, "PNG")
        print("SLICE", out.name, cell.size)
    return n

def main() -> int:
    FX.mkdir(parents=True, exist_ok=True)
    total = 0
    for name, prefix, n in SHEETS:
        total += slice_one(FX / name, prefix, n)
    print(f"done frames_written_groups={total}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
