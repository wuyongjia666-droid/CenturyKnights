#!/usr/bin/env python3
"""Stamp portrait_farm_* plates into hireuniq_NNN open-address slots (5 copies → up to 240)."""
from __future__ import annotations
import json, re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
POR = ROOT / "project/assets/art/portraits"
INBOX = ROOT / "project/assets/art/farm_inbox"
TARGET = (220, 270)
META_PATH = ROOT / "tools/farm_queue/shots_v727_face_meta.json"
OUT_JSON = ROOT / "tools/farm_queue/farm_face_slots.json"
UNIT = ROOT / "project/scripts/art/unit_art.gd"
COPIES = 5
MAX_PLATES = 48

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
    for batch in ["qwen_v727", "qwen_v726", "qwen_v725", "qwen"]:
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
    plates = collect_plates()[:MAX_PLATES]
    if not plates:
        print("no plates"); return 1
    slot_map = {}
    slots_m, slots_f = [], []
    for i, (lab, path, g, tag) in enumerate(plates):
        cell = fit(Image.open(path))
        canon = POR / f"{lab}.png"
        if not canon.exists():
            Image.open(path).convert("RGBA").save(canon)
        for c in range(COPIES):
            slot = i + c * MAX_PLATES
            if slot >= 768:
                continue
            (POR / f"hireuniq_{slot:03d}.png").write_bytes(b"")  # touch
            cell.save(POR / f"hireuniq_{slot:03d}.png", "PNG")
            slot_map[slot] = {"label": lab, "gender": g, "tag": tag}
            (slots_f if g == "f" else slots_m).append(slot)
            print(f"STAMP {slot:03d} <- {lab}")
    # keep prior high farm slots 750-766
    for slot in range(750, 767):
        p = POR / f"hireuniq_{slot:03d}.png"
        if p.exists() and p.stat().st_size >= 80000 and slot not in slot_map:
            g = "f" if slot in (752, 755, 761, 763) else "m"
            slot_map[slot] = {"label": f"legacy_{slot}", "gender": g, "tag": "legacy"}
            (slots_f if g == "f" else slots_m).append(slot)
    slots_m = sorted(set(slots_m)); slots_f = sorted(set(slots_f))
    OUT_JSON.write_text(json.dumps({
        "count": len(slot_map), "slots_m": slots_m, "slots_f": slots_f,
        "slot_map": {str(k): v for k, v in sorted(slot_map.items())},
    }, indent=2) + "\n")
    print(f"coverage {len(slot_map)}/768 m={len(slots_m)} f={len(slots_f)}")
    text = UNIT.read_text()
    def fmt(arr):
        return "[" + ", ".join(str(x) for x in arr) + "]"
    text2, n1 = re.subn(r"const FARM_FACE_SLOTS_M := \[[^\]]*\]", f"const FARM_FACE_SLOTS_M := {fmt(slots_m)}", text, count=1)
    text2, n2 = re.subn(r"const FARM_FACE_SLOTS_F := \[[^\]]*\]", f"const FARM_FACE_SLOTS_F := {fmt(slots_f)}", text2, count=1)
    if n1 and n2:
        UNIT.write_text(text2); print("patched unit_art.gd")
    else:
        print("WARN patch", n1, n2)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
