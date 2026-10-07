#!/usr/bin/env python3
"""Stamp all portrait_farm_* into hireuniq_NNN (COPIES bands) → 500+ coverage.
Also writes per-tag slot lists into farm_face_slots.json and unit_art.gd.
"""
from __future__ import annotations
import json, re
from pathlib import Path
from collections import defaultdict
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
POR = ROOT / "project/assets/art/portraits"
INBOX = ROOT / "project/assets/art/farm_inbox"
TARGET = (220, 270)
META_PATH = ROOT / "tools/farm_queue/shots_v727_face_meta.json"  # merged meta
OUT_JSON = ROOT / "tools/farm_queue/farm_face_slots.json"
UNIT = ROOT / "project/scripts/art/unit_art.gd"
COPIES = 6
TARGET_SLOTS = 528  # 88*6

def fit(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    tw, th = TARGET
    scale = max(tw / im.width, th / im.height)
    nw, nh = int(im.width * scale + 0.5), int(im.height * scale + 0.5)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left, top = (nw - tw) // 2, (nh - th) // 2
    return im.crop((left, top, left + tw, top + th))

def collect_plates():
    meta = {}
    if META_PATH.exists():
        for row in json.loads(META_PATH.read_text()):
            meta[row["label"]] = row
    found = []
    for batch in ["qwen_v728", "qwen_v727", "qwen_v726", "qwen"]:
        d = INBOX / batch
        if not d.exists():
            continue
        for p in sorted(d.glob("portrait_farm_*.png")):
            m = meta.get(p.stem, {})
            g = m.get("gender") or ("f" if "_f_" in p.stem else "m")
            tag = m.get("tag") or p.stem.split("_")[-1]
            found.append((p.stem, p, g, tag))
    seen = set(); out = []
    for row in found:
        if row[0] in seen:
            continue
        seen.add(row[0]); out.append(row)
    return out

def main() -> int:
    plates = collect_plates()
    if not plates:
        print("no plates"); return 1
    n = len(plates)
    copies = COPIES
    # ensure we reach TARGET_SLOTS if possible
    while n * copies < min(TARGET_SLOTS, 768) and copies < 12:
        copies += 1
    print(f"plates={n} copies={copies} → {n*copies} slots")
    slot_map = {}
    slots_m, slots_f = [], []
    by_tag = defaultdict(list)
    for i, (lab, path, g, tag) in enumerate(plates):
        cell = fit(Image.open(path))
        canon = POR / f"{lab}.png"
        if not canon.exists():
            Image.open(path).convert("RGBA").save(canon)
        for c in range(copies):
            slot = i + c * n
            if slot >= 768:
                continue
            cell.save(POR / f"hireuniq_{slot:03d}.png", "PNG")
            slot_map[slot] = {"label": lab, "gender": g, "tag": tag}
            (slots_f if g == "f" else slots_m).append(slot)
            by_tag[tag].append(slot)
    # keep high legacy dense slots 750-766 if not overwritten
    for slot in range(750, 767):
        p = POR / f"hireuniq_{slot:03d}.png"
        if p.exists() and p.stat().st_size >= 70000 and slot not in slot_map:
            g = "f" if slot in (752, 755, 761, 763) else "m"
            slot_map[slot] = {"label": f"legacy_{slot}", "gender": g, "tag": "legacy"}
            (slots_f if g == "f" else slots_m).append(slot)
            by_tag["legacy"].append(slot)
    slots_m = sorted(set(slots_m)); slots_f = sorted(set(slots_f))
    by_tag_out = {k: sorted(set(v)) for k, v in sorted(by_tag.items())}
    OUT_JSON.write_text(json.dumps({
        "count": len(slot_map),
        "slots_m": slots_m,
        "slots_f": slots_f,
        "by_tag": by_tag_out,
        "slot_map": {str(k): v for k, v in sorted(slot_map.items())},
    }, indent=2) + "\n")
    print(f"coverage {len(slot_map)}/768 m={len(slots_m)} f={len(slots_f)} tags={len(by_tag_out)}")

    # patch unit_art.gd
    text = UNIT.read_text()
    def fmt(arr):
        return "[" + ", ".join(str(x) for x in arr) + "]"
    text2, n1 = re.subn(r"const FARM_FACE_SLOTS_M := \[[^\]]*\]", f"const FARM_FACE_SLOTS_M := {fmt(slots_m)}", text, count=1)
    text2, n2 = re.subn(r"const FARM_FACE_SLOTS_F := \[[^\]]*\]", f"const FARM_FACE_SLOTS_F := {fmt(slots_f)}", text2, count=1)
    # Build / replace FARM_FACE_BY_TAG dictionary const
    # GDScript 4: const DICT := { "a": [1,2], ... }
    tag_lines = []
    for tag, slots in by_tag_out.items():
        if tag == "legacy":
            continue
        tag_lines.append(f'\t"{tag}": {fmt(slots)},')
    tag_block = "const FARM_FACE_BY_TAG := {\n" + "\n".join(tag_lines) + "\n}\n"
    if "const FARM_FACE_BY_TAG" in text2:
        text2 = re.sub(r"const FARM_FACE_BY_TAG := \{[\s\S]*?\n\}\n", tag_block, text2, count=1)
    else:
        text2 = text2.replace(
            "const FARM_FACE_SLOTS_F :=",
            tag_block + "const FARM_FACE_SLOTS_F :=",
            1,
        )
        # oops - that puts BY_TAG before F_SLOTS definition unfinished. Fix: insert after F slots line
        text2 = UNIT.read_text()
        text2, n1 = re.subn(r"const FARM_FACE_SLOTS_M := \[[^\]]*\]", f"const FARM_FACE_SLOTS_M := {fmt(slots_m)}", text2, count=1)
        text2, n2 = re.subn(r"const FARM_FACE_SLOTS_F := \[[^\]]*\]", f"const FARM_FACE_SLOTS_F := {fmt(slots_f)}", text2, count=1)
        if "const FARM_FACE_BY_TAG" in text2:
            text2 = re.sub(r"const FARM_FACE_BY_TAG := \{[\s\S]*?\n\}\n", tag_block, text2, count=1)
        else:
            text2 = re.sub(
                r"(const FARM_FACE_SLOTS_F := \[[^\]]*\]\n)",
                r"\1" + tag_block,
                text2,
                count=1,
            )
    UNIT.write_text(text2)
    print("patched unit_art.gd", "n1", n1, "n2", n2)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
