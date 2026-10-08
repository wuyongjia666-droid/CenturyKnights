#!/usr/bin/env python3
"""v8.5: turn opaque v840 Qwen chrome plates into usable game chrome.

Source plates are fully opaque with baked faces/text/light fills. We:
  * knock out portrait windows (our live portraits show through)
  * dark-glass text panels (palette PANEL) so frost text reads
  * extract clean, text-free fill gradients for TextureProgressBar (hp / bloodline)
  * duotone estate focus cards into ink→frost tiles that sit in the dark UI
Outputs -> project/assets/art/ui/v85/
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
UI = ROOT / "project/assets/art/ui"
OUT = UI / "v85"
OUT.mkdir(parents=True, exist_ok=True)

BG = np.array([0.07, 0.08, 0.12]) * 255
PANEL = np.array([0.10, 0.12, 0.18]) * 255
FROST = np.array([0.62, 0.84, 0.96]) * 255


def load(n):
    return Image.open(UI / f"{n}.png").convert("RGBA")


def rr_mask(size, box, r, feather=1.2):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=r, fill=255)
    if feather:
        m = m.filter(ImageFilter.GaussianBlur(feather))
    return np.asarray(m).astype(float) / 255.0


def glass(arr, mask, keep=0.14, alpha=0.93, tint=PANEL):
    """Blend region toward dark panel glass, keeping a ghost of the plate texture."""
    rgb = arr[..., :3].astype(float)
    lum = rgb.mean(2, keepdims=True)
    tex = (lum - lum.mean()) * keep  # texture only, not brightness
    g = np.clip(tint + tex, 0, 255)
    m = mask[..., None]
    arr[..., :3] = (rgb * (1 - m) + g * m).astype(np.uint8)
    arr[..., 3] = (arr[..., 3] * (1 - mask) + 255 * alpha * mask).astype(np.uint8)
    return arr


def cut(arr, mask):
    arr[..., 3] = (arr[..., 3] * (1 - mask)).astype(np.uint8)
    return arr


def knock_matte(arr, thr=30):
    """Flood-fill near-black matte from the borders to transparent."""
    from collections import deque
    h, w = arr.shape[:2]
    dark = arr[..., :3].max(2) < thr
    seen = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if dark[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if dark[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and dark[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; q.append((ny, nx))
    m = Image.fromarray((seen * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    arr[..., 3] = (arr[..., 3] * (1 - np.asarray(m) / 255.0)).astype(np.uint8)
    return arr


def save(arr, name):
    Image.fromarray(arr).save(OUT / name)
    print("V85", name, arr.shape[1], arr.shape[0])


# ---- lineage card: crop to card, knock portrait window, dark-glass info area
im = load("lineage_card").crop((0, 22, 349, 461))
a = np.array(im)
sz = im.size
a = cut(a, rr_mask(sz, (16, 40, 336, 236), 12))
a = glass(a, rr_mask(sz, (15, 238, 335, 426), 10, 1.5), keep=0.04, alpha=0.95)
save(a, "lineage_card_frame.png")

# ---- unit card shell: knock portrait window; dark-glass stats panel + footer strip
im = load("unit_card_frame")
a = np.array(im)
sz = im.size
a = cut(a, rr_mask(sz, (12, 10, 92, 116), 4))
a = glass(a, rr_mask(sz, (96, 8, 306, 99), 4), keep=0.10, alpha=0.86)
a = glass(a, rr_mask(sz, (94, 100, 306, 118), 3), keep=0.04, alpha=0.95)
save(a, "unit_card_shell.png")

# ---- skill chip: crop to frame, glass the face
im = load("skill_chip").crop((12, 13, 86, 86))
a = np.array(im)
sz = im.size
a = glass(a, rr_mask(sz, (7, 9, 67, 65), 3), keep=0.10, alpha=0.95)
save(knock_matte(a), "skill_chip_frame.png")


def row_gradient(a, x0, x1, y0, y1, width=256):
    seg = a[y0:y1, x0:x1, :3].astype(float)
    col = np.median(seg, axis=1)  # per-row median kills baked glyphs
    g = np.repeat(col[:, None, :], width, axis=1)
    out = np.dstack([g, np.full(g.shape[:2], 255.0)]).astype(np.uint8)
    return out


# ---- hp bar kit: clean ally/enemy fills + frames with interior cleared
kit = np.array(load("hp_bar_kit"))
FY0, FY1 = 30, 42
for side, (fx0, fx1, cx0, cx1) in {"ally": (57, 252, 0, 300), "enemy": (365, 578, 310, 640)}.items():
    fill = row_gradient(kit, fx0 + 8, fx1 - 8, FY0 + 1, FY1 - 1)
    # add a soft top highlight so the fill has a glassy read
    hl = np.linspace(1.18, 0.92, fill.shape[0])[:, None, None]
    fill[..., :3] = np.clip(fill[..., :3] * hl, 0, 255).astype(np.uint8)
    save(fill, f"hp_fill_{side}.png")
    fr = kit[16:56, cx0:cx1].copy()
    m = np.zeros(fr.shape[:2])
    m[FY0 - 16:FY1 - 16, max(0, fx0 - cx0):fx1 - cx0] = 1.0
    fr = knock_matte(cut(fr, m))
    print("HPWIN", side, fx0 - cx0, FY0 - 16, fx1 - cx0, FY1 - 16)
    if side == "ally":  # one consistent frame for both teams; fill colour carries team
        save(fr, "hp_bar_frame.png")
under = np.zeros((FY1 - FY0 - 2, 256, 4), np.uint8)
under[..., :3] = (BG * 0.6).astype(np.uint8)
under[..., 3] = 230
save(under, "hp_bar_under.png")

# ---- bloodline strip: grayscale tintable fill + capped frame
bs = np.array(load("bloodline_strip"))
fill = row_gradient(bs, 40, 600, 10, 44)
lum = fill[..., :3].astype(float).mean(2, keepdims=True)
lum = (lum - lum.min()) / max(1.0, lum.max() - lum.min())
fill[..., :3] = np.clip(150 + lum * 105, 0, 255).astype(np.uint8)
save(fill, "bloodline_fill.png")
fr = bs.copy()
m = np.zeros(fr.shape[:2])
m[8:48, 21:619] = 1.0
save(knock_matte(cut(fr, m)), "bloodline_frame.png")
under = np.zeros((34, 256, 4), np.uint8)
under[..., :3] = (PANEL * 0.7).astype(np.uint8)
under[..., 3] = 235
save(under, "bloodline_under.png")

# ---- estate focus cards: ink->frost duotone interior, frame kept
boxes = {"grain": (0, 0, 400, 240), "cash": (12, 5, 393, 233), "fortify": (6, 3, 395, 233)}
for k, box in boxes.items():
    im = load(f"estate_focus_{k}").crop(box)
    a = np.array(im)
    sz = im.size
    w, h = sz
    inner = rr_mask(sz, (int(w * 0.05), int(h * 0.075), int(w * 0.95), int(h * 0.925)), 14, 3)
    rgb = a[..., :3].astype(float)
    L = rgb.mean(2) / 255.0
    lo, hi = np.percentile(L[inner > 0.5], [3, 99])
    Ln = np.clip((L - lo) / max(1e-3, hi - lo), 0, 1) ** 1.6
    duo = BG[None, None, :] * (1 - Ln[..., None] * 0.9) + FROST[None, None, :] * (Ln[..., None] * 0.9)
    # top-down ink vignette keeps the sky from glaring
    vy = np.linspace(0.55, 1.0, h)[:, None, None]
    duo = duo * vy + BG[None, None, :] * (1 - vy)
    m = inner[..., None]
    a[..., :3] = (rgb * (1 - m) + duo * m).astype(np.uint8)
    save(knock_matte(a), f"estate_tile_{k}.png")

# ---- dual portrait frame: knock both oval windows (leader + candidate show through)
im = load("dual_portrait_frame")
a = np.array(im)
sz = im.size
rgb = a[..., :3].astype(int)
bright = ((rgb.mean(2) > 175) & ((rgb.max(2) - rgb.min(2)) < 50)).astype(np.uint8) * 255
win = Image.new("L", sz, 0)
grow = Image.new("L", sz, 0)
for (x0, y0, x1, y1) in ((59, 45, 326, 279), (402, 33, 666, 285)):
    ImageDraw.Draw(win).ellipse((x0 + 6, y0 + 6, x1 - 6, y1 - 6), fill=255)
    ImageDraw.Draw(grow).ellipse((x0 - 10, y0 - 10, x1 + 10, y1 + 10), fill=255)
m = np.maximum(np.asarray(win), np.minimum(np.asarray(grow), bright))
m = np.asarray(Image.fromarray(m.astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))).astype(float) / 255.0
a = knock_matte(cut(a, m))
save(a, "dual_portrait_frame_cut.png")

# ---- panel chrome: half-scale so the 9-slice margins (24/20) contain the whole ice border
pc = Image.open(UI / "panel_chrome.png").convert("RGBA")
pc.resize((pc.width // 2, pc.height // 2), Image.LANCZOS).save(OUT / "panel_chrome_half.png")
print("V85 panel_chrome_half.png", pc.width // 2, pc.height // 2)

print("done")
