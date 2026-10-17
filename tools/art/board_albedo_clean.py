#!/usr/bin/env python3
"""Board-figure albedo clean (#310 P1).

The v87 baked atlases have (a) pure-black padding between UV islands and
(b) a flat "unfilled" key colour inside islands (blue #2C3C5A on cast/outfit,
brick #683028 on enemy). Sampled with mipmaps on a 60-px board figure both
bleed into hard dark/blue blotches and jagged seams.

Output <stem>__albedo_board.png:
  * unfilled key pixels -> neutral mid grey (alpha=0 marks "plain cloth" for the
    shader so it takes the portrait coat colour with lighting only);
  * black padding dilated from nearest island texel (no black bleed in mips).
"""
import sys, glob, os
import numpy as np
from PIL import Image
from scipy import ndimage

KEYS = [(44, 60, 90), (104, 50, 40)]

def clean(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.int32)
    pad = a.max(axis=2) < 14
    key = np.zeros(pad.shape, bool)
    for k in KEYS:
        key |= (np.abs(a - np.array(k)).sum(axis=2) < 34)
    out = a.copy().astype(np.float32)
    alpha = np.full(pad.shape, 255, np.uint8)
    out[key] = 128.0
    alpha[key] = 0
    # dilate: copy nearest non-pad texel into padding
    idx = ndimage.distance_transform_edt(pad, return_distances=False, return_indices=True)
    out = out[idx[0], idx[1]]
    alpha = alpha[idx[0], idx[1]]
    img = np.dstack([np.clip(out, 0, 255).astype(np.uint8), alpha])
    dst = path.replace("__albedo_v87.jpg", "__albedo_board.png")
    Image.fromarray(img, "RGBA").save(dst, optimize=True)
    print(dst, f"key={key.mean():.2f} pad={pad.mean():.2f}")

if __name__ == "__main__":
    pats = sys.argv[1:] or ["project/assets/models/units/cast_*__albedo_v87.jpg",
        "project/assets/models/units/enemy_*__albedo_v87.jpg",
        "project/assets/models/units/outfit_*__albedo_v87.jpg"]
    for p in pats:
        for f in sorted(glob.glob(p)):
            clean(f)
