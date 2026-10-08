#!/usr/bin/env python3
"""Paper-doll part extraction by edit-diff (style-lock v8.7, docs/art/character-system-v87.md section 2).
A part = (Qwen reference edit of a base) minus (the base). Because the edit re-renders the same canvas/anchor,
the cut-out aligns with the base and every other part generated from it.

  doll_extract_v87.py part  base.png edit.png out.png [--mode color|neutral|mask] [--thr 14] [--grow 2] [--feather 2]
                            [--region x0,y0,x1,y1 (fractions)] [--keep N largest components]
  mode color   : RGBA = edit colours, alpha = diff mask (marks, scars, outfits, honours)
  mode neutral : RGB = luminance of the edit (for hair/brows -> recoloured at runtime by gradient map)
  mode mask    : white RGB, alpha = mask (iris mask from the 'pure green irises' edit)
"""
import sys
import numpy as np
import cv2
from PIL import Image

def lab(img):
    return cv2.cvtColor(img, cv2.COLOR_RGB2LAB).astype(np.float32)

def align(base, edit):
    """sub-pixel translation alignment (ECC) - Qwen edits can drift by a few pixels"""
    g0 = cv2.cvtColor(base, cv2.COLOR_RGB2GRAY).astype(np.float32) / 255
    g1 = cv2.cvtColor(edit, cv2.COLOR_RGB2GRAY).astype(np.float32) / 255
    warp = np.eye(2, 3, dtype=np.float32)
    try:
        _, warp = cv2.findTransformECC(g0, g1, warp, cv2.MOTION_TRANSLATION, (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 60, 1e-5), None, 5)
        edit = cv2.warpAffine(edit, warp, (edit.shape[1], edit.shape[0]), flags=cv2.INTER_LINEAR + cv2.WARP_INVERSE_MAP, borderMode=cv2.BORDER_REPLICATE)
    except cv2.error:
        pass
    return edit, warp

def part(base_p, edit_p, out_p, mode="color", thr=14.0, grow=2, feather=2.0, region=None, keep=0):
    base = np.array(Image.open(base_p).convert("RGB"))
    edit = np.array(Image.open(edit_p).convert("RGB").resize((base.shape[1], base.shape[0]), Image.LANCZOS))
    edit, warp = align(base, edit)
    if mode == "mask":
        hsv = cv2.cvtColor(edit, cv2.COLOR_RGB2HSV)
        m = ((hsv[..., 0] > 40) & (hsv[..., 0] < 85) & (hsv[..., 1] > 120) & (hsv[..., 2] > 80)).astype(np.uint8)
    else:
        d = np.linalg.norm(lab(edit) - lab(base), axis=-1)
        d = cv2.GaussianBlur(d, (0, 0), 1.2)
        m = (d > thr).astype(np.uint8)
    if region:
        h, w = m.shape; x0, y0, x1, y1 = region
        rm = np.zeros_like(m); rm[int(y0 * h):int(y1 * h), int(x0 * w):int(x1 * w)] = 1; m &= rm
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    n, lbl, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    areas = stats[1:, cv2.CC_STAT_AREA]
    if n > 1:
        order = np.argsort(-areas)
        keep_ids = set((order[:keep] + 1).tolist()) if keep else set((np.where(areas >= max(60, 0.002 * m.size * (0.02 if mode == "mask" else 1)))[0] + 1).tolist())
        m = np.isin(lbl, list(keep_ids)).astype(np.uint8)
    # fill holes (hair interiors that match the base by chance)
    inv = 1 - m; n2, l2, s2, _ = cv2.connectedComponentsWithStats(inv, 4)
    for i in range(1, n2):
        x, y, w_, h_, a = s2[i]
        if a < 0.01 * m.size and x > 0 and y > 0 and x + w_ < m.shape[1] and y + h_ < m.shape[0]:
            m[l2 == i] = 1
    if grow:
        m = cv2.dilate(m, np.ones((grow * 2 + 1, grow * 2 + 1), np.uint8))
    a = cv2.GaussianBlur(m.astype(np.float32), (0, 0), feather) if feather else m.astype(np.float32)
    a = np.clip(a * 1.15, 0, 1)
    if mode == "neutral":
        l = cv2.cvtColor(edit, cv2.COLOR_RGB2GRAY)
        rgb = np.stack([l, l, l], -1)
    elif mode == "mask":
        rgb = np.full_like(edit, 255)
    else:
        rgb = edit
    out = np.dstack([rgb, (a * 255).astype(np.uint8)])
    Image.fromarray(out, "RGBA").save(out_p)
    cov = float(a.mean())
    print("part %-40s mode %-7s coverage %.3f shift (%.1f,%.1f)" % (out_p.split("/")[-1], mode, cov, warp[0, 2], warp[1, 2]))
    return cov

if __name__ == "__main__":
    args = sys.argv[1:]
    if not args or args[0] != "part":
        print(__doc__); sys.exit(1)
    pos, kw = [], {}
    it = iter(args[1:])
    for x in it:
        if x.startswith("--"):
            v = next(it); k = x[2:]
            kw[k] = (tuple(float(t) for t in v.split(",")) if k == "region" else (int(v) if k in ("grow", "keep") else (float(v) if k in ("thr", "feather") else v)))
        else:
            pos.append(x)
    part(*pos, **kw)
