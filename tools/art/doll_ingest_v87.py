#!/usr/bin/env python3
"""Ingest farmed doll edits into assets/art/doll/<bl>_<g>/{base,hair_*,brow_*,...}.png
  doll_ingest_v87.py <edits_dir> <bases_dir> <out_root>
edits_dir files: 8322__doll_<bl>_<g>_<part>__*.png  (or doll_<bl>_<g>_<part>.png)
bases_dir files: 8322__face_<bl>_<g>*.png (prefer *_r2*) or ck87_base_<bl>_<g>.png
Uses doll_extract_v87 part modes: hair/brow=neutral, iris_mask=mask, elder/young=copy as full bases, else color.
"""
import os, sys, glob, re, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from doll_extract_v87 import part as extract
from PIL import Image

BLOODS = ["common_ash", "river_ward", "ember_noble", "frost_crown"]
HAIR = {"m": ["crop", "swept", "tied", "messy"], "f": ["long", "pony", "bob", "crown"]}
BROW = ["thick", "straight", "arch", "soft"]
MARKS = ["ears_crest", "mark_crown_rime", "mark_ember_sigil", "scar_cheek_l", "scar_brow_r", "scar_chin", "iris_mask", "elder", "young"]

def find_base(bases, bl, g):
    pats = [f"*face_{bl}_{g}_r2*", f"*face_{bl}_{g}__*", f"*face_{bl}_{g}.*", f"ck87_base_{bl}_{g}*"]
    for pat in pats:
        hits = sorted(glob.glob(os.path.join(bases, pat)))
        if hits: return hits[0]
    return None

def find_edit(edits, key):
    hits = sorted(glob.glob(os.path.join(edits, f"*doll_{key}__*"))) + sorted(glob.glob(os.path.join(edits, f"*doll_{key}.*")))
    return hits[0] if hits else None

def save_base(src, dst, size=384):
    im = Image.open(src).convert("RGBA")
    im = im.resize((size, size), Image.LANCZOS)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst)

def main():
    edits, bases, out = sys.argv[1:4]
    n = 0
    for bl in BLOODS:
        for g in ("m", "f"):
            bp = find_base(bases, bl, g)
            if not bp:
                print("SKIP no base", bl, g); continue
            d = os.path.join(out, f"{bl}_{g}")
            os.makedirs(d, exist_ok=True)
            save_base(bp, os.path.join(d, "base.png")); n += 1
            for hid in HAIR[g]:
                ep = find_edit(edits, f"{bl}_{g}_hair_{hid}")
                if ep:
                    extract(bp, ep, os.path.join(d, f"hair_{hid}.png"), mode="neutral", thr=12, grow=1, feather=2); n += 1
            for bid in BROW:
                ep = find_edit(edits, f"{bl}_{g}_brow_{bid}")
                if ep:
                    extract(bp, ep, os.path.join(d, f"brow_{bid}.png"), mode="neutral", thr=10, grow=1, feather=1); n += 1
            for mid in MARKS:
                ep = find_edit(edits, f"{bl}_{g}_{mid}")
                if not ep: continue
                dst = os.path.join(d, f"{mid}.png")
                if mid in ("elder", "young"):
                    save_base(ep, dst); n += 1
                elif mid == "iris_mask":
                    extract(bp, ep, dst, mode="mask", thr=14, grow=1, feather=1); n += 1
                else:
                    extract(bp, ep, dst, mode="color", thr=14, grow=2, feather=2); n += 1
    # outfits + honors sit under out/outfit and out/honor (shared)
    od = os.path.join(out, "outfit"); os.makedirs(od, exist_ok=True)
    hd = os.path.join(out, "honor"); os.makedirs(hd, exist_ok=True)
    # outfits were edited from common_ash base
    for g in ("m", "f"):
        bp = find_base(bases, "common_ash", g) or find_base(bases, "common_ash", g)
        if not bp: continue
        for ep in glob.glob(os.path.join(edits, f"*doll_outfit_*_t1_{g}*")):
            job = re.search(r"doll_outfit_([a-z_]+)_t1_", os.path.basename(ep))
            if not job: continue
            extract(bp, ep, os.path.join(od, f"{job.group(1)}_t1_{g}.png"), mode="color", thr=16, grow=2, feather=2,
                    region=(0.0, 0.45, 1.0, 1.0)); n += 1
        for ep in glob.glob(os.path.join(edits, f"*doll_honor_*_{g}*")):
            hid = re.search(r"doll_(honor_[a-z_]+)_", os.path.basename(ep))
            if not hid: continue
            extract(bp, ep, os.path.join(hd, f"{hid.group(1)}_{g}.png"), mode="color", thr=14, grow=1, feather=1); n += 1
    print("ingested", n, "parts into", out)

if __name__ == "__main__":
    main()
