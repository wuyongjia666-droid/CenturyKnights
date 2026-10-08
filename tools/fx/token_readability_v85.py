#!/usr/bin/env python3
"""v8.5 token readability pass: silhouette-on-clean-field.

v8.2/v8.3 job tokens are dark figures inside bright crystal swirls -> noise at 48px.
Per token: segment the dark figure, replace the swirl with a calm ink->team radial
field (keeping ~18% swirl texture), lift the figure slightly, add a team rim-light
around the silhouette, zoom 1.22x, re-rim. Originals backed up to tokens/_src_v82/.
"""
from pathlib import Path
import shutil
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
TOK = ROOT / "project/assets/art/tokens"
SRC = TOK / "_src_v82"
SRC.mkdir(exist_ok=True)
(SRC / ".gdignore").write_text("")
TEAM = {"ally": np.array([0.40, 0.95, 0.80]), "enemy": np.array([1.00, 0.45, 0.42])}
INK = np.array([0.06, 0.07, 0.11])


def center_components(mask: np.ndarray, seed_r: float = 0.30, min_frac: float = 0.004) -> np.ndarray:
    """Keep connected components of mask that touch the central seed disc (pure-numpy BFS on 128px)."""
    from collections import deque
    h, w = mask.shape
    sm = np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).resize((128, 128), Image.NEAREST)) > 127
    lab = np.zeros((128, 128), np.int32)
    yy, xx = np.mgrid[0:128, 0:128]
    rr = np.sqrt((xx - 63.5) ** 2 + (yy - 63.5) ** 2) / 64
    keep = np.zeros((128, 128), bool)
    cur = 0
    for y in range(128):
        for x in range(128):
            if sm[y, x] and lab[y, x] == 0:
                cur += 1
                q = deque([(y, x)]); lab[y, x] = cur; pts = []
                touches = False
                while q:
                    cy, cx = q.popleft(); pts.append((cy, cx))
                    if rr[cy, cx] < seed_r:
                        touches = True
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < 128 and 0 <= nx < 128 and sm[ny, nx] and lab[ny, nx] == 0:
                            lab[ny, nx] = cur; q.append((ny, nx))
                if touches and len(pts) >= min_frac * 128 * 128:
                    for cy, cx in pts:
                        keep[cy, cx] = True
    return np.asarray(Image.fromarray(keep.astype(np.uint8) * 255).resize((w, h), Image.BILINEAR)) > 127


def fallback(path: Path, team: str, zoom: float = 1.38) -> Image.Image:
    """Segmentation failed (small/bright figure): zoom + damp the swirl highlights + re-rim."""
    im = Image.open(path).convert("RGBA")
    S = im.width
    W = S * 2
    big = im.resize((W, W), Image.LANCZOS)
    cw = int(W / zoom); o = (W - cw) // 2
    big = big.crop((o, o, o + cw, o + cw)).resize((W, W), Image.LANCZOS)
    a = np.asarray(big).astype(np.float32) / 255.0
    rgb = a[..., :3]
    L = rgb @ np.array([0.299, 0.587, 0.114])
    yy, xx = np.mgrid[0:W, 0:W]
    c = (W - 1) / 2
    r = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / (W / 2)
    tc = TEAM[team]
    damp = np.clip((r - 0.30) / 0.45, 0, 1)[..., None]  # keep centre, damp outer swirl
    muted = INK[None, None, :] + tc[None, None, :] * (0.10 + 0.25 * L[..., None])
    out = rgb * (1 - damp * 0.85) + muted * damp * 0.85
    alpha = np.clip((0.97 - r) * W / 3.0, 0, 1)
    ring = np.exp(-((r - 0.925) / 0.022) ** 2)
    out = out * (1 - ring[..., None]) + (tc * 0.9 + 0.1)[None, None, :] * ring[..., None]
    res = np.dstack([np.clip(out, 0, 1), alpha])
    return Image.fromarray((res * 255).astype(np.uint8), "RGBA").resize((S, S), Image.LANCZOS)


def process(path: Path, team: str, zoom: float = 1.22, fig_r: float = 0.86, bright_fig: bool = False) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    S = im.width
    big = im.resize((S * 2, S * 2), Image.LANCZOS)
    W = big.width
    c = (W - 1) / 2
    # zoom crop
    cw = int(W / zoom)
    o = (W - cw) // 2
    big = big.crop((o, o, o + cw, o + cw)).resize((W, W), Image.LANCZOS)
    a = np.asarray(big).astype(np.float32) / 255.0
    rgb = a[..., :3]
    L = rgb @ np.array([0.299, 0.587, 0.114])
    yy, xx = np.mgrid[0:W, 0:W]
    r = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / (W / 2)
    inner = r < 0.86
    figzone = r < fig_r
    # figure = dark & low-ish saturation pixels, cleaned
    sat = rgb.max(2) - rgb.min(2)
    fig = ((L > 0.55) & figzone) if bright_fig else ((L < 0.30) & figzone)
    fig = center_components(fig)
    frac = fig.sum() / max(1, inner.sum())
    if frac < (0.03 if bright_fig else 0.07) or frac > 0.60:
        print("  fallback", path.name, round(float(frac), 3))
        return fallback(path, team)
    fm = Image.fromarray(fig.astype(np.uint8) * 255).filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    fmask = np.asarray(fm.filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255.0
    # rim light: dilated ring outside the silhouette
    dil = np.asarray(fm.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(3))).astype(np.float32) / 255.0
    rim = np.clip(dil - fmask, 0, 1)
    tc = TEAM[team]
    # calm field: ink centre -> team tint edge + faint swirl texture
    field = INK[None, None, :] + tc[None, None, :] * (0.30 + 0.30 * (1 - r[..., None]))
    field = field + (L[..., None] - L.mean()) * 0.10 * tc[None, None, :]
    # figure: keep original but lift shadows so it's not a black hole
    figc = np.clip(rgb * 0.85 + 0.10 + tc[None, None, :] * 0.06, 0, 1)
    if bright_fig:  # bright figure -> ink silhouette (roster consistency) with faint inner detail
        figc = np.clip(INK[None, None, :] + (rgb - 0.6) * 0.12, 0, 1)
    out = field * (1 - fmask[..., None]) + figc * fmask[..., None]
    out = out + rim[..., None] * tc[None, None, :] * 0.95
    out = np.clip(out, 0, 1)
    # circular alpha + crisp team rim
    alpha = np.clip((0.97 - r) * W / 3.0, 0, 1)
    ring = np.exp(-((r - 0.925) / 0.022) ** 2)
    out = out * (1 - ring[..., None]) + (tc * 0.9 + 0.1)[None, None, :] * ring[..., None]
    res = np.dstack([out, alpha])
    return Image.fromarray((res * 255).astype(np.uint8), "RGBA").resize((S, S), Image.LANCZOS)


def main():
    n = 0
    for p in sorted(TOK.glob("v8_job_*_*.png")):
        team = "enemy" if p.stem.endswith("_enemy") else "ally"
        bk = SRC / p.name
        if not bk.exists():
            shutil.copy2(p, bk)
        # ring-framed small figures: tighter figure zone + stronger zoom
        if "light_inf" in p.stem:
            process(bk, team, zoom=2.3, fig_r=0.62, bright_fig=True).save(p)
        elif "apprentice" in p.stem:
            process(bk, team, zoom=1.6, fig_r=0.50, bright_fig=True).save(p)
        else:
            process(bk, team).save(p)
        n += 1
    print("TOKENS", n)


if __name__ == "__main__":
    main()
