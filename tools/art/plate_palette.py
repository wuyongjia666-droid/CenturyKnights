#!/usr/bin/env python3
"""Offline portrait-plate palette extraction for board figures (pawn-redesign-opus §3.3 / 附录 C).

Writes:
  project/data/plate_palettes.json          # stem -> palette + annotations
  project/data/plate_palette_overrides.json # human override skeleton (created if missing)
  docs/art/review/plate_palette/sheet_NNNN.png  # review contact sheets every ~100 plates

Usage:
  python3 tools/art/plate_palette.py              # full bank run
  python3 tools/art/plate_palette.py --limit 20   # smoke
  python3 tools/art/plate_palette.py --stems a,b  # named stems
  python3 tools/art/plate_palette.py --self-test  # unit checks on synthetic + 1 real plate
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "project/assets/art/portraits/genome/bank"
OUT_PAL = ROOT / "project/data/plate_palettes.json"
OUT_OVR = ROOT / "project/data/plate_palette_overrides.json"
REVIEW = ROOT / "docs/art/review/plate_palette"
HAIR_STYLES = ("crop", "swept", "tied", "messy", "long", "pony", "bob", "crown")

# ── colour space ─────────────────────────────────────────────────────────────

def _srgb_to_linear(c: np.ndarray) -> np.ndarray:
    return np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)


def _rgb_to_xyz(rgb: np.ndarray) -> np.ndarray:
    m = np.array(
        [
            [0.4124564, 0.3575761, 0.1804375],
            [0.2126729, 0.7151522, 0.0721750],
            [0.0193339, 0.1191920, 0.9503041],
        ],
        dtype=np.float64,
    )
    return _srgb_to_linear(rgb) @ m.T


def _xyz_to_lab(xyz: np.ndarray) -> np.ndarray:
    # D65 white
    w = np.array([0.95047, 1.0, 1.08883], dtype=np.float64)
    t = xyz / w
    d = 6.0 / 29.0
    f = np.where(t > d**3, np.cbrt(t), t / (3 * d * d) + 4.0 / 29.0)
    L = 116.0 * f[..., 1] - 16.0
    a = 500.0 * (f[..., 0] - f[..., 1])
    b = 200.0 * (f[..., 1] - f[..., 2])
    return np.stack([L, a, b], axis=-1)


def rgb_to_lab(rgb: np.ndarray) -> np.ndarray:
    return _xyz_to_lab(_rgb_to_xyz(np.clip(rgb, 0.0, 1.0)))


def lab_chroma(lab: np.ndarray) -> np.ndarray:
    return np.sqrt(lab[..., 1] ** 2 + lab[..., 2] ** 2)


def lab_hue_deg(lab: np.ndarray) -> np.ndarray:
    return (np.degrees(np.arctan2(lab[..., 2], lab[..., 1])) + 360.0) % 360.0


def rgb_to_hsv(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    mask = d > 1e-8
    r_eq = mask & (mx == r)
    g_eq = mask & (mx == g) & ~r_eq
    b_eq = mask & ~(r_eq | g_eq) & (mx == b)
    h[r_eq] = ((g[r_eq] - b[r_eq]) / d[r_eq]) % 6.0
    h[g_eq] = (b[g_eq] - r[g_eq]) / d[g_eq] + 2.0
    h[b_eq] = (r[b_eq] - g[b_eq]) / d[b_eq] + 4.0
    h = h * 60.0
    s = np.where(mx > 1e-8, d / (mx + 1e-12), 0.0)
    return np.stack([h, s, mx], axis=-1)


def hsv_to_rgb(hsv: np.ndarray) -> np.ndarray:
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    c = v * s
    x = c * (1.0 - np.abs((h / 60.0) % 2.0 - 1.0))
    m = v - c
    z = np.zeros_like(h)
    rgb = np.zeros(hsv.shape, dtype=np.float64)
    h60 = (h / 60.0).astype(np.int32) % 6
    conds = [
        (h60 == 0, (c, x, z)),
        (h60 == 1, (x, c, z)),
        (h60 == 2, (z, c, x)),
        (h60 == 3, (z, x, c)),
        (h60 == 4, (x, z, c)),
        (h60 == 5, (c, z, x)),
    ]
    for msk, (rr, gg, bb) in conds:
        rgb[msk, 0] = rr[msk]
        rgb[msk, 1] = gg[msk]
        rgb[msk, 2] = bb[msk]
    return rgb + m[..., None]


def lift_hsv_v(rgb: np.ndarray, factor: float) -> np.ndarray:
    hsv = rgb_to_hsv(rgb.reshape(1, 3)).reshape(3)
    hsv[2] = min(1.0, float(hsv[2]) * factor)
    return hsv_to_rgb(hsv.reshape(1, 3)).reshape(3)


def rgb_to_hex(rgb: np.ndarray) -> str:
    x = np.clip(np.round(np.asarray(rgb) * 255.0), 0, 255).astype(int)
    return "#{:02X}{:02X}{:02X}".format(int(x[0]), int(x[1]), int(x[2]))


def hex_to_rgb(hx: str) -> np.ndarray:
    hx = hx.strip().lstrip("#")
    return np.array([int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16)], dtype=np.float64) / 255.0


def median_rgb(rgb: np.ndarray, mask: np.ndarray) -> np.ndarray | None:
    pts = rgb[mask]
    if pts.size == 0:
        return None
    return np.median(pts, axis=0)


def percentile_band_median(rgb: np.ndarray, mask: np.ndarray, lab_L: np.ndarray, lo: float, hi: float) -> np.ndarray | None:
    pts = rgb[mask]
    Ls = lab_L[mask]
    if pts.size == 0:
        return None
    plo, phi = np.percentile(Ls, [lo * 100.0, hi * 100.0])
    keep = (Ls >= plo) & (Ls <= phi)
    if not np.any(keep):
        return np.median(pts, axis=0)
    return np.median(pts[keep], axis=0)


# ── k-means++ in Lab ─────────────────────────────────────────────────────────

def kmeans(points: np.ndarray, k: int, seed: int = 0, iters: int = 24) -> tuple[np.ndarray, np.ndarray]:
    """Return (labels, centres). points: (N, D)."""
    rng = np.random.default_rng(seed)
    n = points.shape[0]
    if n == 0:
        return np.zeros(0, dtype=np.int32), np.zeros((k, points.shape[1]))
    k = min(k, n)
    centres = np.empty((k, points.shape[1]), dtype=np.float64)
    centres[0] = points[rng.integers(0, n)]
    closest = np.full(n, np.inf)
    for i in range(1, k):
        d = ((points - centres[i - 1]) ** 2).sum(axis=1)
        closest = np.minimum(closest, d)
        total = float(closest.sum())
        if total <= 1e-12:
            centres[i] = points[rng.integers(0, n)]
            continue
        w = closest / total
        w = np.maximum(w, 0.0)
        w = w / w.sum()
        centres[i] = points[rng.choice(n, p=w)]
    labels = np.zeros(n, dtype=np.int32)
    for _ in range(iters):
        d2 = ((points[:, None, :] - centres[None, :, :]) ** 2).sum(axis=2)
        labels = d2.argmin(axis=1).astype(np.int32)
        new = centres.copy()
        for i in range(k):
            m = labels == i
            if np.any(m):
                new[i] = points[m].mean(axis=0)
            else:
                new[i] = points[rng.integers(0, n)]
        if np.allclose(new, centres, atol=1e-4):
            centres = new
            break
        centres = new
    return labels, centres


# ── segmentation (附录 C) ────────────────────────────────────────────────────

def _box_blur(mask: np.ndarray, k: int) -> np.ndarray:
    """Mean filter via integral image; mask float."""
    if k <= 1:
        return mask
    pad = k // 2
    a = np.pad(mask.astype(np.float64), pad, mode="edge")
    ii = np.pad(a, ((1, 0), (1, 0)), mode="constant").cumsum(0).cumsum(1)
    h, w = mask.shape
    out = (
        ii[k : h + k, k : w + k]
        - ii[0:h, k : w + k]
        - ii[k : h + k, 0:w]
        + ii[0:h, 0:w]
    ) / float(k * k)
    return out


def segment(rgb: np.ndarray) -> dict:
    """Return masks and face box. rgb: HxWx3 float 0..1."""
    h, w = rgb.shape[:2]
    lab = rgb_to_lab(rgb)
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    chroma = lab_chroma(lab)
    hue = lab_hue_deg(lab)

    # Background: per-row median of left/right 10px columns (vertical soft gradient).
    edge = 10 if w >= 40 else max(2, w // 8)
    left = rgb[:, :edge]
    right = rgb[:, -edge:]
    bg_row = np.median(np.concatenate([left, right], axis=1), axis=1)  # H,3
    bg = np.broadcast_to(bg_row[:, None, :], rgb.shape)
    bg_lab = rgb_to_lab(bg)
    dist = np.sqrt(((lab - bg_lab) ** 2).sum(axis=-1))
    fg_raw = dist > 7.0
    fg = _box_blur(fg_raw.astype(np.float64), 5) > 0.5

    # Skin candidates: Lab hue 25–80, chroma 10–45, L 35–92, upper 62%.
    skin_cand = (
        fg
        & (hue >= 25.0)
        & (hue <= 80.0)
        & (chroma >= 10.0)
        & (chroma <= 45.0)
        & (L >= 35.0)
        & (L <= 92.0)
        & (np.arange(h)[:, None] < int(h * 0.62))
    )
    skin = _box_blur(skin_cand.astype(np.float64), 13) > 0.55

    # Face: skin in upper 55%, within ±22% width of centre.
    cx0 = int(w * 0.28)
    cx1 = int(w * 0.72)
    face_skin = skin & (np.arange(h)[:, None] < int(h * 0.55)) & (np.arange(w)[None, :] >= cx0) & (
        np.arange(w)[None, :] < cx1
    )
    ys, xs = np.where(face_skin)
    if ys.size < 20:
        # Fallback: use skin cand bbox in upper half.
        ys, xs = np.where(skin_cand & (np.arange(h)[:, None] < int(h * 0.55)))
    if ys.size < 8:
        face_box = (int(w * 0.32), int(h * 0.08), int(w * 0.68), int(h * 0.48))
    else:
        y_lo, y_hi = np.percentile(ys, [2, 98])
        x_lo, x_hi = np.percentile(xs, [3, 97])
        face_box = (int(x_lo), int(y_lo), int(x_hi), int(y_hi))

    fx0, fy0, fx1, fy1 = face_box
    face_h = max(1, fy1 - fy0)
    face_w = max(1, fx1 - fx0)

    # Skin colour: mid 25–75% of face height; drop L lowest 25% and highest 15%.
    mid_y0 = fy0 + int(face_h * 0.25)
    mid_y1 = fy0 + int(face_h * 0.75)
    face_mid = np.zeros((h, w), dtype=bool)
    face_mid[mid_y0:mid_y1, fx0:fx1] = True
    face_mid &= skin
    if not np.any(face_mid):
        face_mid = face_skin if np.any(face_skin) else skin_cand
    skin_rgb = percentile_band_median(rgb, face_mid, L, 0.25, 0.85)

    # Hair: head box = face box expanded up 55% face_h, ±45% face_w; non-skin FG;
    # exclude near-skin-L with chroma>10.
    head_y0 = max(0, fy0 - int(face_h * 0.55))
    head_y1 = fy1
    head_x0 = max(0, fx0 - int(face_w * 0.45))
    head_x1 = min(w, fx1 + int(face_w * 0.45))
    head = np.zeros((h, w), dtype=bool)
    head[head_y0:head_y1, head_x0:head_x1] = True
    hair = head & fg & ~skin
    if skin_rgb is not None:
        skin_L = float(rgb_to_lab(skin_rgb.reshape(1, 1, 3)).reshape(-1)[0])
        near_skin = (np.abs(L - skin_L) < 8.0) & (chroma > 10.0)
        hair &= ~near_skin
    hair_rgb = percentile_band_median(rgb, hair, L, 0.20, 0.75)

    # Clothing: below chin (face bottom + 6% face_h), non-skin FG.
    chin_y = min(h - 1, fy1 + int(face_h * 0.06))
    cloth = fg & ~skin & (np.arange(h)[:, None] >= chin_y)
    # Also exclude hair region above chin that spilled.
    cloth &= ~hair

    return {
        "fg": fg,
        "skin": skin,
        "hair": hair,
        "cloth": cloth,
        "face_box": face_box,
        "chin_y": chin_y,
        "lab": lab,
        "L": L,
        "chroma": chroma,
        "hue": hue,
        "skin_rgb": skin_rgb,
        "hair_rgb": hair_rgb,
    }


def assign_cloth_roles(rgb: np.ndarray, seg: dict, seed: int = 0) -> dict:
    cloth = seg["cloth"]
    lab = seg["lab"]
    L = seg["L"]
    chroma = seg["chroma"]
    hue = seg["hue"]
    ys, xs = np.where(cloth)
    out = {
        "coat": None,
        "coat_dark": None,
        "light": None,
        "apron": None,
        "sash": None,
        "metal": None,
        "clusters": [],
    }
    if ys.size < 30:
        return out

    # Deterministic subsample up to 6000 pixels (stride), so re-runs match.
    if ys.size > 6000:
        step = max(1, ys.size // 6000)
        # Offset by seed so different stems don't share the exact same lattice.
        off = int(seed) % step
        ys, xs = ys[off::step][:6000], xs[off::step][:6000]
    pts_lab = lab[ys, xs]
    pts_rgb = rgb[ys, xs]
    labels, centres = kmeans(pts_lab, 5, seed=seed)
    # Cluster stats.
    clusters = []
    for i in range(centres.shape[0]):
        m = labels == i
        if not np.any(m):
            continue
        ratio = float(m.mean())
        med = np.median(pts_rgb[m], axis=0)
        cL = float(centres[i, 0])
        cC = float(math.sqrt(centres[i, 1] ** 2 + centres[i, 2] ** 2))
        cH = float((math.degrees(math.atan2(centres[i, 2], centres[i, 1])) + 360.0) % 360.0)
        clusters.append({"i": i, "ratio": ratio, "rgb": med, "L": cL, "C": cC, "H": cH})
    clusters.sort(key=lambda c: -c["ratio"])
    out["clusters"] = [
        {"ratio": round(c["ratio"], 4), "hex": rgb_to_hex(c["rgb"]), "L": round(c["L"], 1)}
        for c in clusters
    ]

    significant = [c for c in clusters if c["ratio"] > 0.04]
    if significant:
        out["coat"] = max(significant, key=lambda c: c["ratio"])["rgb"]
        out["coat_dark"] = min(significant, key=lambda c: c["L"])["rgb"]
        out["light"] = max(significant, key=lambda c: c["L"])["rgb"]
        # Apron / vest: second-largest mid-L cluster if distinct from coat.
        if len(significant) >= 2:
            coat_i = max(significant, key=lambda c: c["ratio"])["i"]
            rest = [c for c in significant if c["i"] != coat_i]
            if rest:
                # Prefer mid-dark non-darkest as apron candidate.
                darkest_i = min(significant, key=lambda c: c["L"])["i"]
                apron_cands = [c for c in rest if c["i"] != darkest_i] or rest
                out["apron"] = apron_cands[0]["rgb"]

        # Scarf prior among clusters: C>9, hue 200–330, ratio<35%, highest C.
        scarf_cands = [c for c in significant if c["C"] > 9 and 200 <= c["H"] <= 330 and c["ratio"] < 0.35]
        if scarf_cands:
            out["sash"] = max(scarf_cands, key=lambda c: c["C"])["rgb"]

    # Purple sash pixels: Lab hue 288–340, C>13, L>22; if >2% of cloth, median of L≥40th.
    purple = cloth & (hue >= 288.0) & (hue <= 340.0) & (chroma > 13.0) & (L > 22.0)
    if purple.mean() > 0.02 and cloth.mean() > 0:
        # Relative to cloth area.
        if purple.sum() / max(1, cloth.sum()) > 0.02:
            Ls = L[purple]
            thr = np.percentile(Ls, 40)
            keep = purple & (L >= thr)
            med = median_rgb(rgb, keep)
            if med is not None:
                out["sash"] = med

    # Frost-silver metal: L>82, C<7, >1% of cloth.
    metal = cloth & (L > 82.0) & (chroma < 7.0)
    if cloth.sum() > 0 and metal.sum() / cloth.sum() > 0.01:
        out["metal"] = median_rgb(rgb, metal)

    return out


def guess_hair_style(seg: dict, stem: str) -> tuple[str, float]:
    """Heuristic 8-way hair style guess; low confidence → needs_review.

    Features from hair mask vs face box (附录 C 标注). Always mark needs_review when
    confidence < 0.55 so sheets drive human hair-style sign-off.
    """
    hair = seg["hair"]
    face = seg["face_box"]
    fx0, fy0, fx1, fy1 = face
    face_h = max(1, fy1 - fy0)
    face_w = max(1, fx1 - fx0)
    face_cx = 0.5 * (fx0 + fx1)
    h, w = hair.shape
    ys, xs = np.where(hair)
    if ys.size < 40:
        return "crop", 0.2

    top = int(ys.min())
    bot = int(ys.max())
    left = int(xs.min())
    right = int(xs.max())
    hair_h = bot - top + 1
    hair_w = right - left + 1
    chin = seg["chin_y"]
    below_chin = float((ys > chin).sum()) / ys.size
    below_mid = float((ys > (fy0 + fy1) // 2).sum()) / ys.size
    above_brow = float((ys < fy0 + int(face_h * 0.15)).sum()) / ys.size
    side_extra = max(0, fx0 - left) + max(0, right - fx1)
    side_ratio = side_extra / float(face_w)
    top_rise = max(0, fy0 - top) / float(face_h)
    aspect = hair_h / float(max(1, hair_w))
    # Left/right hanging imbalance (pony often one-sided).
    left_mass = float((xs < face_cx).sum()) / ys.size
    right_mass = 1.0 - left_mass
    imbalance = abs(left_mass - right_mass)
    # Volume in cheek bands (bob/long/messy).
    cheek_y0, cheek_y1 = fy0 + int(face_h * 0.35), fy1 + int(face_h * 0.25)
    cheek = hair[cheek_y0:cheek_y1, :]
    cheek_frac = float(cheek.mean()) if cheek.size else 0.0
    # Crown / bun: dense blob above face top, narrow width.
    bun_band = hair[max(0, top) : max(1, fy0), max(0, fx0 - face_w // 6) : min(w, fx1 + face_w // 6)]
    bun_frac = float(bun_band.mean()) if bun_band.size else 0.0
    bun_narrow = hair_w < face_w * 1.35

    score = {s: 0.05 for s in HAIR_STYLES}

    # long: substantial hair below chin + wide sides
    if below_chin > 0.22:
        score["long"] += 1.2 + 2.0 * min(1.0, below_chin)
    if side_ratio > 0.4 and below_chin > 0.15:
        score["long"] += 1.5

    # bob: cheek volume, moderate below-chin, not too tall top
    if 0.08 < below_chin < 0.28 and cheek_frac > 0.08 and top_rise < 0.7:
        score["bob"] += 2.2
    if side_ratio > 0.25 and below_mid > 0.35 and below_chin < 0.3:
        score["bob"] += 1.0

    # pony: top mass + hanging + imbalance
    if top_rise > 0.45 and below_chin > 0.12 and imbalance > 0.12:
        score["pony"] += 2.5
    if bun_frac > 0.12 and below_chin > 0.1 and imbalance > 0.08:
        score["pony"] += 1.5

    # crown / tied: tall top knot, little side hang
    if top_rise > 0.55 and bun_frac > 0.15 and below_chin < 0.14 and bun_narrow:
        score["crown"] += 2.8
    if top_rise > 0.4 and below_chin < 0.12 and side_ratio < 0.4:
        score["tied"] += 2.0
        score["crown"] += 0.8

    # crop: little hang, little side, short top rise
    if below_chin < 0.07 and side_ratio < 0.4 and top_rise < 0.5:
        score["crop"] += 2.4
    if below_chin < 0.05 and cheek_frac < 0.05:
        score["crop"] += 1.2

    # swept: asymmetric top / moderate side, little chin hang
    if imbalance > 0.1 and below_chin < 0.12 and top_rise > 0.2:
        score["swept"] += 2.2
    if side_ratio > 0.15 and below_chin < 0.14 and above_brow > 0.35:
        score["swept"] += 1.2

    # messy: medium everywhere, no strong bun
    if 0.06 < below_chin < 0.2 and side_ratio > 0.2 and bun_frac < 0.12:
        score["messy"] += 2.0
    if cheek_frac > 0.1 and top_rise < 0.55 and imbalance < 0.18:
        score["messy"] += 0.8

    best = max(score, key=score.get)
    vals = sorted(score.values(), reverse=True)
    gap = vals[0] - vals[1]
    conf = 0.28 + min(0.45, vals[0] * 0.12) + min(0.2, gap * 0.15)
    conf = float(min(0.88, conf))
    # Force review when runner-up is close or geometry is ambiguous.
    if gap < 0.6 or vals[0] < 1.8:
        conf = min(conf, 0.48)
    return best, conf


def guess_collar_etc(seg: dict, roles: dict) -> dict:
    """Rough clothing annotations; marked needs_review when weak."""
    cloth = seg["cloth"]
    skin = seg["skin"]
    fx0, fy0, fx1, fy1 = seg["face_box"]
    face_h = max(1, fy1 - fy0)
    h, w = cloth.shape
    neck_y0 = fy1
    neck_y1 = min(h, fy1 + int(face_h * 0.35))
    neck = cloth[neck_y0:neck_y1, fx0:fx1]
    skin_neck = skin[neck_y0:neck_y1, fx0:fx1]
    collar = "open"
    if neck.size > 0:
        cloth_r = float(neck.mean())
        skin_r = float(skin_neck.mean()) if skin_neck.size else 0.0
        if cloth_r > 0.45 and skin_r < 0.12:
            collar = "high"
        elif cloth_r > 0.25:
            collar = "stand"
        else:
            collar = "open"
    scarf = roles.get("sash") is not None
    apron = roles.get("apron") is not None and roles.get("coat") is not None
    # Shoulder pads: bright/metal or dark blobs at shoulder height left/right.
    sh_y0 = fy1
    sh_y1 = min(h, fy1 + int(face_h * 0.55))
    left_band = cloth[sh_y0:sh_y1, max(0, fx0 - int((fx1 - fx0) * 0.55)) : fx0]
    right_band = cloth[sh_y0:sh_y1, fx1 : min(w, fx1 + int((fx1 - fx0) * 0.55))]
    pauldron = "none"
    L = seg["L"]
    left_dark = False
    right_dark = False
    if left_band.size:
        ys, xs = np.where(left_band)
        if ys.size:
            # Map back — approximate using relative.
            left_dark = True  # presence of cloth at shoulder
    if right_band.size and right_band.mean() > 0.15:
        right_dark = True
    if left_band.size and left_band.mean() > 0.2 and right_band.size and right_band.mean() > 0.2:
        # Both shoulders covered heavily → possible pauldrons if metal or dark.
        metal = roles.get("metal") is not None
        if metal:
            pauldron = "both"
    hem = "mid"
    # Hem length proxy: how far cloth extends down image.
    ys, _ = np.where(cloth)
    if ys.size:
        bot = int(ys.max()) / float(h)
        if bot > 0.92:
            hem = "long"
        elif bot < 0.78:
            hem = "short"
        else:
            hem = "mid"
    return {
        "collar": collar,
        "apron": bool(apron and scarf is not None),
        "straps": False,
        "scarf": bool(scarf),
        "pauldron": pauldron,
        "hem": hem,
    }


def restore_base(rgb: np.ndarray | None, kind: str) -> np.ndarray | None:
    if rgb is None:
        return None
    factors = {"hair": 1.18, "skin": 1.06, "cloth": 1.15, "sash": 1.25}
    return lift_hsv_v(np.asarray(rgb, dtype=np.float64), factors[kind])


def extract_one(path: Path, stem: str) -> dict:
    im = Image.open(path).convert("RGB")
    # Work at half-res for speed; colours stay stable.
    tw, th = im.size
    work = im
    if tw > 400:
        work = im.resize((tw // 2, th // 2), Image.BILINEAR)
    rgb = np.asarray(work).astype(np.float64) / 255.0
    seg = segment(rgb)
    roles = assign_cloth_roles(rgb, seg, seed=int(hashlib.md5(stem.encode()).hexdigest()[:8], 16))
    style, conf = guess_hair_style(seg, stem)
    ann = guess_collar_etc(seg, roles)

    hair = restore_base(seg["hair_rgb"], "hair")
    skin = restore_base(seg["skin_rgb"], "skin")
    coat = restore_base(roles["coat"], "cloth")
    coat_dark = restore_base(roles["coat_dark"], "cloth")
    apron = restore_base(roles["apron"], "cloth")
    sash = restore_base(roles["sash"], "sash")
    metal = roles["metal"]  # already highlight; keep as sampled mid

    # Defaults when segmentation failed.
    if hair is None:
        hair = np.array([0.25, 0.20, 0.18])
    if skin is None:
        skin = np.array([0.78, 0.62, 0.52])
    if coat is None:
        coat = np.array([0.55, 0.58, 0.62])
    if coat_dark is None:
        coat_dark = np.array([0.18, 0.16, 0.18])

    needs = conf < 0.55 or seg["hair_rgb"] is None or roles["coat"] is None
    return {
        "hair": rgb_to_hex(hair),
        "skin": rgb_to_hex(skin),
        "coat": rgb_to_hex(coat),
        "coat_dark": rgb_to_hex(coat_dark),
        "apron": rgb_to_hex(apron) if apron is not None else None,
        "sash": rgb_to_hex(sash) if sash is not None else None,
        "metal": rgb_to_hex(metal) if metal is not None else "#C9D3DE",
        "style": style,
        "style_confidence": round(conf, 3),
        "collar": ann["collar"],
        "apron_present": bool(ann["apron"]),
        "straps": bool(ann["straps"]),
        "scarf": bool(ann["scarf"]),
        "pauldron": ann["pauldron"],
        "hem": ann["hem"],
        "needs_review": needs,
    }


# ── review sheets ────────────────────────────────────────────────────────────

def _font(size: int = 14):
    for name in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    ):
        if os.path.isfile(name):
            return ImageFont.truetype(name, size)
    return ImageFont.load_default()


def make_sheet(items: list[tuple[str, Path, dict]], out_path: Path, title: str) -> None:
    """items: (stem, image_path, palette_dict)."""
    cols = 5
    cell_w, cell_h = 180, 260
    rows = (len(items) + cols - 1) // cols
    canvas = Image.new("RGB", (cols * cell_w + 20, rows * cell_h + 40), (16, 22, 32))
    draw = ImageDraw.Draw(canvas)
    font = _font(12)
    font_sm = _font(10)
    draw.text((10, 8), title, fill=(244, 247, 251), font=font)
    for i, (stem, path, pal) in enumerate(items):
        r, c = divmod(i, cols)
        x0 = 10 + c * cell_w
        y0 = 32 + r * cell_h
        try:
            im = Image.open(path).convert("RGB")
            im.thumbnail((110, 146), Image.BILINEAR)
        except OSError:
            im = Image.new("RGB", (140, 186), (40, 40, 40))
        canvas.paste(im, (x0, y0))
        sw = 28
        keys = ["hair", "skin", "coat", "coat_dark", "sash", "metal"]
        for j, k in enumerate(keys):
            hx = pal.get(k) or "#333333"
            try:
                rgb = tuple(int(hex_to_rgb(hx)[t] * 255) for t in range(3))
            except Exception:
                rgb = (50, 50, 50)
            bx = x0 + 150
            by = y0 + j * (sw + 4)
            draw.rectangle([bx, by, bx + sw, by + sw], fill=rgb)
            draw.text((bx + sw + 4, by + 6), f"{k}", fill=(180, 190, 200), font=font_sm)
        mark = "!" if pal.get("needs_review") else " "
        draw.text(
            (x0, y0 + 190),
            f"{mark}{stem[:28]}\n{pal.get('style','?')} ({pal.get('style_confidence',0):.2f})",
            fill=(255, 200, 120) if pal.get("needs_review") else (200, 210, 220),
            font=font_sm,
        )
    out_path = out_path.with_suffix(".jpg")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path, quality=72, optimize=True)


# ── bank listing ─────────────────────────────────────────────────────────────

def list_stems(bank: Path) -> list[str]:
    stems = set()
    for p in bank.iterdir():
        name = p.name
        if name.endswith(".import") or name.endswith(".remap"):
            continue
        if name.endswith(".medium.webp") or name.endswith(".small.webp"):
            continue
        if name.endswith(".webp"):
            stems.add(name[: -len(".webp")])
        elif name.endswith(".png"):
            stems.add(name[: -len(".png")])
    return sorted(stems)


def plate_path(bank: Path, stem: str) -> Path | None:
    for ext in (".webp", ".png"):
        p = bank / f"{stem}{ext}"
        if p.is_file():
            return p
    return None


def apply_overrides(palettes: dict, overrides: dict) -> dict:
    for stem, ovr in overrides.items():
        if stem.startswith("_"):
            continue
        if stem not in palettes or not isinstance(ovr, dict):
            continue
        row = dict(palettes[stem])
        for k, v in ovr.items():
            if k.startswith("_"):
                continue
            row[k] = v
        row["needs_review"] = bool(row.get("needs_review", False)) and not ovr.get("reviewed", False)
        if ovr.get("reviewed"):
            row["needs_review"] = False
            row["style_confidence"] = max(float(row.get("style_confidence", 0.0)), 0.9)
        palettes[stem] = row
    return palettes


def ensure_overrides(path: Path) -> dict:
    if path.is_file():
        return json.loads(path.read_text(encoding="utf-8"))
    skeleton = {
        "_doc": "Human overrides for plate_palettes.json (pawn-redesign-opus §3.3). Key = plate stem. Set reviewed=true after hair-style sign-off.",
        "_example": {
            "style": "swept",
            "hair": "#5D4A49",
            "skin": "#C4A28A",
            "coat": "#8A93A0",
            "reviewed": True,
            "note": "manual hair style correction",
        },
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(skeleton, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return skeleton


# ── self-test ────────────────────────────────────────────────────────────────

def self_test() -> int:
    # Synthetic: skin-toned oval + dark hair cap + grey coat on gradient bg.
    h, w = 256, 192
    rgb = np.zeros((h, w, 3), dtype=np.float64)
    # vertical bg gradient
    for y in range(h):
        v = 0.75 - 0.15 * y / h
        rgb[y, :] = (v, v + 0.02, v + 0.04)
    yy, xx = np.mgrid[0:h, 0:w]
    # face
    face = ((xx - 96) ** 2 / 35**2 + (yy - 90) ** 2 / 45**2) < 1.0
    rgb[face] = (0.78, 0.62, 0.52)
    # hair
    hair = ((xx - 96) ** 2 / 50**2 + (yy - 55) ** 2 / 40**2) < 1.0
    hair &= yy < 95
    rgb[hair] = (0.22, 0.18, 0.16)
    # coat
    coat = (yy > 140) & (xx > 40) & (xx < 152) & ~face
    rgb[coat] = (0.55, 0.58, 0.65)
    Image.fromarray((rgb * 255).astype(np.uint8)).save("/tmp/ck_plate_synth.png")
    # Run through extract via temp save path trick — call segment directly.
    seg = segment(rgb)
    assert seg["skin_rgb"] is not None, "skin missing"
    assert seg["hair_rgb"] is not None, "hair missing"
    roles = assign_cloth_roles(rgb, seg, seed=1)
    assert roles["coat"] is not None, "coat missing"
    skin_hex = rgb_to_hex(restore_base(seg["skin_rgb"], "skin"))
    hair_hex = rgb_to_hex(restore_base(seg["hair_rgb"], "hair"))
    print(f"SELF-TEST synth skin={skin_hex} hair={hair_hex} coat={rgb_to_hex(restore_base(roles['coat'],'cloth'))}")
    # One real plate if available.
    stems = list_stems(BANK)
    if stems:
        p = plate_path(BANK, stems[0])
        row = extract_one(p, stems[0])
        for k in ("hair", "skin", "coat", "coat_dark", "style"):
            assert row.get(k), f"missing {k}"
        print(f"SELF-TEST real {stems[0]} -> {row['hair']}/{row['skin']}/{row['coat']} style={row['style']}")
        # Re-run for reproducibility.
        row2 = extract_one(p, stems[0])
        assert row2["hair"] == row["hair"] and row2["skin"] == row["skin"] and row2["coat"] == row["coat"]
        print("SELF-TEST PASS reproducible")
    else:
        print("SELF-TEST PASS synth-only (no bank plates)")
    return 0


# ── main ─────────────────────────────────────────────────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bank", type=Path, default=BANK)
    ap.add_argument("--out", type=Path, default=OUT_PAL)
    ap.add_argument("--overrides", type=Path, default=OUT_OVR)
    ap.add_argument("--review-dir", type=Path, default=REVIEW)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--stems", type=str, default="")
    ap.add_argument("--sheet-every", type=int, default=100)
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--resume", action="store_true", help="merge into existing plate_palettes.json")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    if not args.bank.is_dir():
        print(f"FAIL bank missing: {args.bank}", file=sys.stderr)
        return 1

    stems = list_stems(args.bank)
    available = len(stems)
    if args.stems:
        want = [s.strip() for s in args.stems.split(",") if s.strip()]
        stems = [s for s in want if s in set(stems)]
        missing = [s for s in want if s not in set(list_stems(args.bank))]
        if missing:
            print(f"WARN missing stems: {missing}")
    if args.limit > 0:
        stems = stems[: args.limit]

    overrides = ensure_overrides(args.overrides)
    palettes: dict = {}
    if args.resume and args.out.is_file():
        palettes = json.loads(args.out.read_text(encoding="utf-8"))
        if isinstance(palettes.get("plates"), dict):
            palettes = palettes["plates"]

    t0 = time.time()
    sheet_buf: list[tuple[str, Path, dict]] = []
    sheet_idx = 0
    done = 0
    failed: list[str] = []
    for stem in stems:
        path = plate_path(args.bank, stem)
        if path is None:
            failed.append(stem)
            continue
        try:
            row = extract_one(path, stem)
        except Exception as e:  # noqa: BLE001 — keep batch going
            failed.append(f"{stem}:{e}")
            continue
        palettes[stem] = row
        done += 1
        sheet_buf.append((stem, path, row))
        if len(sheet_buf) >= args.sheet_every:
            sheet_idx += 1
            make_sheet(
                sheet_buf,
                args.review_dir / f"sheet_{sheet_idx:04d}.jpg",
                f"plate_palette review {sheet_idx} ({(sheet_idx-1)*args.sheet_every+1}–{done})",
            )
            sheet_buf = []
        if done % 50 == 0:
            elapsed = time.time() - t0
            rate = done / max(1e-6, elapsed)
            print(f"... {done}/{len(stems)} ({rate:.1f}/s)", flush=True)

    if sheet_buf:
        sheet_idx += 1
        make_sheet(
            sheet_buf,
            args.review_dir / f"sheet_{sheet_idx:04d}.jpg",
            f"plate_palette review {sheet_idx} (final {done})",
        )

    palettes = apply_overrides(palettes, overrides)
    needs = sum(1 for v in palettes.values() if isinstance(v, dict) and v.get("needs_review"))
    payload = {
        "version": 1,
        "source": "tools/art/plate_palette.py",
        "spec": "docs/design/pawn-redesign-opus.md §3.3 / 附录 C",
        "bank": str(args.bank.relative_to(ROOT)),
        "plate_count_available": available,
        "plate_count_extracted": len(palettes),
        "needs_review": needs,
        "target_count": 1595,
        "coverage_gap": max(0, 1595 - available),
        "failed": failed[:50],
        "failed_count": len(failed),
        "plates": palettes,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    # Sidecar stem->row flat file size note for runtime (same file; CKBoardFigure reads plates key).
    print(
        f"PLATE PALETTE PASS extracted={len(palettes)} available={available} "
        f"target=1595 gap={payload['coverage_gap']} needs_review={needs} "
        f"sheets={sheet_idx} failed={len(failed)} out={args.out}"
    )
    return 0 if len(palettes) > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
